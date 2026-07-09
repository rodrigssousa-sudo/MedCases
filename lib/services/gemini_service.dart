import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// Import condicional: ls_web.dart (Web, usa dart:js) ou ls_stub.dart (iOS/Android, no-op).
// Isola completamente dart:js do compilador nativo — resolve o erro
// "Undefined name 'context'" no Xcode / Android toolchain.
import 'ls_stub.dart'
    if (dart.library.js) 'ls_web.dart';

// Google Sign-In — usado APENAS no Android (não no web)
import 'package:google_sign_in/google_sign_in.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GEMINI SERVICE — Autenticação por API Key
//
// Arquitetura (Session 4 — 2025):
//   Google Login = identidade apenas (scope 'email') — sem verificação restrita
//   Gemini API calls = API Key do projeto (salva no Firestore config/app_settings)
//
// O scope 'generative-language.retriever' era RESTRITO — exigia verificação
// formal do Google e bloqueava todos os usuários não-Test com 403 access_denied.
// Solução: remover o scope restrito. O Gemini é chamado via API Key, não OAuth.
//
// Web:     GSI redirect flow (Safari-safe) salva apenas email
// Android: google_sign_in salva apenas email
// API Key: estática — carregada do Firestore via AppProvider.setGeminiApiKey()
// ─────────────────────────────────────────────────────────────────────────────

class GeminiResult {
  final String text;
  final bool isError;
  final String? errorCode;
  const GeminiResult({required this.text, this.isError = false, this.errorCode});
  factory GeminiResult.error(String msg, String code) =>
      GeminiResult(text: msg, isError: true, errorCode: code);
}

// ─────────────────────────────────────────────────────────────────────────────
// Filtra blocos internos que o Gemini 2.5 Flash pode vazar na resposta:
//   • Blocos ```tool_code ... ``` (chamadas de ferramentas internas)
//   • Blocos ```thinking ... ``` ou <thinking>...</thinking>
//   • Blocos de raciocínio sem marcador — linhas em inglês inseridas antes
//     da resposta real (padrão: "I will...", "Let's...", "The user...",
//     "Given the prompt...", "I need to...", "I should...", "thought:", etc.)
// ─────────────────────────────────────────────────────────────────────────────
String _cleanInternalBlocks(String raw) {
  var text = raw;

  // 1. Remove blocos de código interno com marcadores (tool_code, thinking, thought)
  text = text.replaceAll(
    RegExp(r'```(?:tool_code|thinking|thought|python|json)[\s\S]*?```',
        multiLine: true),
    '',
  );

  // 1b. Build 98: Remove blocos tool_code SEM backticks (plain-text leak do Gemini 2.5 Flash).
  //     O modelo às vezes emite a chamada de grounding como texto puro começando com
  //     "tool_code\nprint(google_search.search(...))" sem nenhuma formatação de código.
  //     Esta regex captura todo o bloco desde "tool_code" até o fim do parágrafo.
  text = text.replaceAll(
    RegExp(r'tool_code\s*\n[\s\S]*?(?=\n\n|\Z)', multiLine: true),
    '',
  );
  // Remove linhas isoladas que contenham padrões de chamada de ferramentas
  text = text.split('\n').where((line) {
    final lower = line.toLowerCase().trim();
    if (lower.startsWith('tool_code')) return false;
    if (lower.startsWith('print(google_search')) return false;
    if (lower.startsWith('print(perplexity')) return false;
    if (lower.startsWith('google_search.search')) return false;
    if (lower.contains('queries=[')) return false;
    if (lower.startsWith('search_query')) return false;
    return true;
  }).join('\n');

  // 2. Remove blocos <thinking>...</thinking> do Gemini
  text = text.replaceAll(
    RegExp(r'<thinking>[\s\S]*?</thinking>', multiLine: true),
    '',
  );

  // 3. Detecta e remove parágrafos de raciocínio em inglês que precedem a resposta.
  //    Estratégia: divide em parágrafos e descarta os que são reconhecidamente
  //    texto interno (em inglês, iniciando com padrões de "cadeia de pensamento").
  final paragraphs = text.split(RegExp(r'\n\n+'));
  final cleanParagraphs = paragraphs.where((para) {
    final trimmed = para.trim();
    if (trimmed.isEmpty) return false;

    // Padrões de raciocínio interno em inglês — descarta o parágrafo inteiro
    const internalPrefixes = [
      'I will ', 'I\'ll ', 'I need to ', 'I should ', 'I have ',
      'I am going', 'I must ', 'I want to ',
      'Let me ', 'Let\'s ', "Let's ",
      'The user ', 'The prompt ', 'The question ',
      'Given the ', 'Given that ', 'Given this ',
      'Based on ', 'Since the ',
      'First, I ', 'Now, I ', 'Next, I ', 'Then, I ',
      'For each ', 'For the ',
      'My goal ', 'My approach ', 'My plan ',
      'This is a ', 'This requires ',
      'It seems ', 'It looks ',
      'thought:', 'Thought:', 'THOUGHT:',
      'Note:', 'NOTE:',
      // Padrões de chamadas de ferramentas vazadas sem backticks
      'tool_code', 'Tool_code', 'TOOL_CODE',
      'perplexity_search', 'google_search(',
      'search_query', 'queries=[',
      'print(perplexity', 'print(google',
    ];

    for (final prefix in internalPrefixes) {
      if (trimmed.startsWith(prefix) || trimmed.startsWith(prefix.toLowerCase())) {
        return false;
      }
    }

    // Descarta parágrafo que é quase só inglês e não contém termos médicos
    // Heurística: >70% de palavras "comuns em inglês" sem palavras em pt/es
    final englishOnlyWords = RegExp(
      r'\b(the|and|or|but|with|from|that|this|will|have|been|they|their|there|when|where|what|which|would|could|should|about|after|before|also|some|each|into|than|then|more|over|only|both|other|these|those|through|during|including|without|however|therefore|furthermore|additionally|specifically|importantly|regarding|concerning|considering|following|based|approach|provide|ensure|include|address|mention|structure|discuss|explain|describe|break|detail|start|begin|continue|finish|complete|conclude|summarize|note|remember|understand|know|think|feel|believe|assume|suppose|consider|determine|decide|choose|select|use|make|take|give|get|go|come|see|look|try|need|want|ask|tell|say|speak|write|read|find|show|help|work|create|build|develop|implement|design|plan|organize|arrange|prepare|manage|handle|process|analyze|evaluate|assess|review|check|test|verify|confirm|ensure|guarantee|promise|achieve|accomplish|complete|finish|succeed|fail|error|issue|problem|solution|answer|response|reply|result|output|input|data|information|content|text|message|question|request|prompt)\b',
      caseSensitive: false,
    );
    final wordCount = trimmed.split(RegExp(r'\s+')).length;
    if (wordCount > 4) {
      final englishMatches = englishOnlyWords.allMatches(trimmed).length;
      final ratio = englishMatches / wordCount;
      // Se >55% das palavras são "inglês genérico" e parágrafo não tem números/doses
      final hasMedicalNumbers = RegExp(r'\d+\s*(?:mg|mcg|µg|mL|g|UI|h|min|kg|%)')
          .hasMatch(trimmed);
      final hasMedicalTerms = RegExp(
        r'\b(?:dosis|dosis|dose|mg|mcg|EV|VO|SC|IM|paciente|patient|tratamiento|tratamento|'
        r'fármaco|medicamento|droga|protocolo|urgencia|urgência|clínico|clínica|'
        r'diagnóstico|diagnose|síntoma|sintoma|signo|señal)\b',
        caseSensitive: false,
      ).hasMatch(trimmed);
      if (ratio > 0.55 && !hasMedicalNumbers && !hasMedicalTerms) {
        return false;
      }
    }

    return true;
  }).toList();

  // Se o filtro removeu tudo, retorna o texto original (melhor ter conteúdo que nada)
  if (cleanParagraphs.isEmpty) return raw.trim();

  return cleanParagraphs.join('\n\n').trim();
}

// ─────────────────────────────────────────────────────────────────────────────
// _isTruncated — detecta se uma resposta clínica foi cortada no meio da frase.
//
// Heurísticas (qualquer uma basta):
//   1. Termina sem pontuação final (. ! ? : — após trim)
//   2. Última palavra tem < 3 chars (fragmento cortado: "ot", "tr", "de")
//   3. Termina com vírgula, reticências truncadas ou abre parêntese sem fechar
//   4. Termina com conjunção/preposição (indica continuação esperada)
// ─────────────────────────────────────────────────────────────────────────────
bool _isTruncated(String text) {
  if (text.isEmpty) return false;
  final trimmed = text.trimRight();
  if (trimmed.isEmpty) return false;

  final lastChar = trimmed[trimmed.length - 1];

  // 1. Sem pontuação final — frase aberta
  const validEndings = {'.', '!', '?', ':', ';', ')', ']', '*', '…', '—'};
  if (!validEndings.contains(lastChar)) {
    // 2. Última "palavra" é um fragmento muito curto (< 3 chars)
    final words = trimmed.split(RegExp(r'\s+'));
    final lastWord = words.last;
    if (lastWord.length < 3) return true;

    // 3. Termina com conjunção/preposição/artigo — indica continuação esperada
    // PT-BR + ES — sem duplicatas para evitar equal_elements_in_const_set
    const openWords = {
      // português
      'e', 'o', 'a', 'os', 'as', 'de', 'do', 'da', 'em', 'no', 'na',
      'por', 'para', 'com', 'sem', 'se', 'que', 'ou', 'mas', 'como',
      // espanhol (apenas os que não existem em PT acima)
      'y', 'el', 'la', 'los', 'las', 'del', 'en', 'con', 'sin', 'pero', 'si',
    };
    if (openWords.contains(lastWord.toLowerCase())) return true;

    // 4. Termina com vírgula = item de lista cortado
    if (lastChar == ',') return true;

    // 5. Resposta clinicamente incompleta — termina sem pontuação E
    //    tem mais de 100 chars (não é um bullet curto proposital)
    if (trimmed.length > 100) return true;
  }

  // 6. Abre parêntese sem fechar
  final opens = trimmed.split('(').length - 1;
  final closes = trimmed.split(')').length - 1;
  if (opens > closes) return true;

  return false;
}


// BUILD 294: Discriminador de origem da chave Gemini API.
// SecurityWipe APENAS pode limpar: oauth, admin, cache, user.
// NUNCA deve limpar: appConfig — essa chave pertence ao sistema.
enum GeminiKeySource {
  none,       // nenhuma chave carregada
  appConfig,  // app_config/global.apiKey — chave do sistema, compartilhada
  oauth,      // OAuth Google redirect — chave pessoal do usuário autenticado
  admin,      // definida manualmente por admin/master via painel
  user,       // chave BYOA individual do usuário
  cache,      // restaurada de SharedPreferences/localStorage (origem desconhecida)
}

class GeminiService {
  // BUILD 334: corrigido gemini-2.5-flash-lite → gemini-2.5-flash (modelo canônico da API).
  // gemini-2.5-flash-lite retornava 404 em streamGenerateContent — modelo não existe na v1beta.
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  // ── Client IDs Google OAuth ────────────────────────────────────────────────
  //
  // BUILD 283: CORREÇÃO CRÍTICA DE AUTH ANDROID
  //
  // PROBLEMA: serverClientId no GoogleSignIn estava configurado com o Android
  // Client ID (tipo "Android" no GCP Console). Isso causa falha de autenticação
  // porque:
  //   • O Android Client ID é um identificador de APP — não é um token audience.
  //   • google_sign_in usa serverClientId para solicitar um "server auth code"
  //     que pode ser trocado por tokens por um backend.
  //   • Quando serverClientId = Android Client ID, o Google Sign-In não consegue
  //     gerar o auth code correto → PlatformException("sign_in_failed") ou
  //     token com audience errada → Firebase rejeita com INVALID_CREDENTIAL.
  //
  // SOLUÇÃO: serverClientId deve ser o Web Client ID (tipo "Web application"),
  // que é o OAuth 2.0 client do projeto Firebase para apps web/mobile.
  // Este é o mesmo client ID usado no index.html para o Google Sign-In GSI.
  //
  // COMO OBTER o Web Client ID:
  //   1. Firebase Console → Projeto → Authentication → Sign-in method → Google
  //   2. "Web SDK configuration" → Web client ID (termina em .apps.googleusercontent.com)
  //   OU:
  //   1. GCP Console → APIs & Services → Credentials
  //   2. Procure "Web client (auto created by Google Service)" — tipo "Web application"
  //
  // NOTA: Se o app NÃO precisa validar tokens no servidor (caso do MedCases —
  // apenas salva email para referência), serverClientId pode ser OMITIDO.
  // Omitir é mais seguro e evita erros de configuração cross-platform.
  // Se Google Sign-In com Firebase Auth for necessário no futuro, adicione
  // o Web Client ID (não o Android).
  //
  // O Android Client ID abaixo é mantido APENAS como referência de documentação:
  // 1076800980330-0dhh85qno3uelf1tq55oan6kcgpk319p.apps.googleusercontent.com
  // (tipo Android — SHA-1: configurar no Firebase Console para cada keystore)

  // ── API Key estática (carregada do Firestore pelo AppProvider) ────────────
  static String _geminiApiKey = '';
  static const _keyGak = 'medcases_gak'; // localStorage key para persistência entre reloads

  // BUILD 294: Discriminador de origem da chave Gemini.
  // CRÍTICO: SecurityWipe só pode apagar chaves de origem oauth/admin/cache.
  // Chaves de origem appConfig (app_config/global) pertencem ao sistema e
  // NUNCA devem ser apagadas pelo SecurityWipe — são necessárias para todos
  // os usuários aprovados enviarem mensagens à IA.
  //
  // Sequência de boot regular (usuário não-privilegiado):
  //   1. _loadAiKeyFromFirestore() → loadGeminiApiKey() → source = appConfig
  //   2. checkGeminiSession() → SecurityWipe → clearOAuthKey() → NÃO apaga
  //   3. AI funciona normalmente
  //
  // Sequência após OAuth admin:
  //   1. JS salva chave OAuth em medcases_gak → source = oauth
  //   2. Logout → clearOAuthKey() → apaga corretamente
  //   3. Próximo login regular: _loadAiKeyFromFirestore() → source = appConfig
  static GeminiKeySource _keySource = GeminiKeySource.none;

  /// Retorna a origem da chave Gemini atualmente carregada.
  static GeminiKeySource get keySource => _keySource;

  /// Setter chamado pelo AppProvider após carregar a chave do Firestore.
  /// Automaticamente persiste no localStorage para sobreviver reloads do service worker.
  static void setGeminiApiKey(String key, {GeminiKeySource source = GeminiKeySource.appConfig}) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;
    _geminiApiKey = trimmed;
    _keySource    = source;
    // Persiste via dart:js (mcLsSet) E via SharedPreferences (dupla garantia)
    if (kIsWeb) _webSet(_keyGak, trimmed);
    // SharedPreferences em background — não bloqueia, garante persistência
    SharedPreferences.getInstance().then((p) {
      p.setString(_keyGak, trimmed);
    }).catchError((_) {});
    debugPrint('[GeminiService] API Key definida (source=${source.name}) e cacheada ✓');
  }

  /// Restaura a API Key do SharedPreferences/localStorage sem precisar do Firestore.
  /// Chamar em main() antes do runApp — garante que a key está disponível
  /// imediatamente, mesmo quando o Firestore falha por reload do service worker.
  /// Usa SharedPreferences como primário (Flutter Web usa localStorage nativamente,
  /// sem dart:js — imune ao SES lockdown e CSP). dart:js como fallback secundário.
  static Future<void> initFromStorage() async {
    if (_geminiApiKey.isNotEmpty) return; // já carregada
    try {
      // Primário: SharedPreferences (Flutter Web → localStorage via dart:html interno)
      final prefs = await SharedPreferences.getInstance();
      final fromPrefs = prefs.getString(_keyGak) ?? '';
      if (fromPrefs.isNotEmpty) {
        _geminiApiKey = fromPrefs;
        _keySource    = GeminiKeySource.cache;
        debugPrint('[GeminiService] API Key restaurada do SharedPreferences no boot ✓');
        return;
      }
    } catch (_) {}
    // Secundário: dart:js → mcLsGet (se disponível no window)
    if (kIsWeb) {
      final cached = _webGet(_keyGak);
      if (cached != null && cached.isNotEmpty) {
        _geminiApiKey = cached;
        _keySource    = GeminiKeySource.cache;
        debugPrint('[GeminiService] API Key restaurada via mcLsGet no boot ✓');
      }
    }
  }

  /// Versão síncrona legada — mantida para compatibilidade, usa apenas dart:js.
  static void initFromLocalStorage() {
    if (!kIsWeb) return;
    if (_geminiApiKey.isNotEmpty) return;
    final cached = _webGet(_keyGak);
    if (cached != null && cached.isNotEmpty) {
      _geminiApiKey = cached;
      debugPrint('[GeminiService] API Key restaurada do localStorage (sync) ✓');
    }
  }

  /// BUILD 277 / BUILD 294: Wipes the in-memory cached API key without
  /// touching Firestore. Full wipe — use only on logout or admin reset.
  static void clearCachedApiKey() {
    _geminiApiKey = '';
    _keySource    = GeminiKeySource.none;
    debugPrint('[GeminiService] clearCachedApiKey() — in-memory key wiped (full)');
  }

  /// BUILD 294: SecurityWipe-safe clear — only clears OAuth/admin/cache keys.
  /// NEVER clears appConfig keys (from app_config/global) — those are system
  /// keys needed by ALL approved users for IA to function.
  ///
  /// Returns true if a key was actually cleared, false if it was skipped.
  static bool clearOAuthCachedApiKey() {
    if (_keySource == GeminiKeySource.appConfig) {
      debugPrint('[BUILD294][SecurityWipe] skipped reason=app_config_key '
          'source=${_keySource.name}');
      return false;
    }
    final hadKey = _geminiApiKey.isNotEmpty;
    _geminiApiKey = '';
    _keySource    = GeminiKeySource.none;
    if (hadKey) {
      debugPrint('[BUILD294][SecurityWipe] wiped_oauth_only '
          'source was=${_keySource == GeminiKeySource.none ? "cleared" : _keySource.name}');
    }
    return hadKey;
  }

  /// Verifica se a API Key foi carregada (sem expor a chave em si).
  static bool get hasApiKey => _geminiApiKey.isNotEmpty;

  /// Expõe a chave para serviços internos que fazem chamadas diretas
  /// (ex: LabParserService — que precisa enviar imagem/PDF inline).
  /// NÃO use fora do escopo interno do app.
  static String get apiKeyForLab => _geminiApiKey;

  // Chaves de storage
  static const _keyEmail = 'gemini_google_email';
  // _keyToken mantido para limpeza de localStorage legado (não mais usado para auth)
  static const _keyToken = 'gemini_access_token';

  // ── Android: google_sign_in ───────────────────────────────────────────────
  // BUILD 283: serverClientId REMOVIDO.
  // O MedCases usa Google Sign-In apenas para capturar o email do usuário —
  // não há troca de auth code com backend (a API Key vem do Firestore, não de OAuth).
  // Manter serverClientId com o Android Client ID causava:
  //   PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10)
  //   → ApiException code 10 = DEVELOPER_ERROR = serverClientId inválido para esta plataforma
  // Sem serverClientId, o Google Sign-In opera no modo "email only" — sem auth code,
  // sem token server-side — que é exatamente o que precisamos.
  static final _googleSignIn = GoogleSignIn(
    scopes: ['email'],  // Apenas email — sem scope restrito
    // serverClientId omitido intencionalmente — ver documentação acima.
    // Adicionar serverClientId com o Web Client ID apenas se for necessário
    // validar ID tokens em um backend próprio no futuro.
  );

  // ══════════════════════════════════════════════════════════════════════════
  // STORAGE — localStorage (web) / SharedPreferences (Android)
  // ══════════════════════════════════════════════════════════════════════════

  // localStorage via import condicional (ls_web.dart no Web, ls_stub.dart no nativo).
  // As funções webLsGet / webLsSet / webLsRemove são no-op no iOS/Android —
  // o canal real nessas plataformas é SharedPreferences (já tratado acima).

  static void _webSet(String key, String value) => webLsSet(key, value);

  static String? _webGet(String key) => webLsGet(key);

  static void _webRemove(String key) => webLsRemove(key);

  static Future<void> _saveEmail(String email) async {
    if (kIsWeb) { _webSet(_keyEmail, email); return; }
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyEmail, email);
  }

  static Future<String?> _readEmail() async {
    if (kIsWeb) return _webGet(_keyEmail);
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyEmail);
  }

  static Future<void> _deleteEmail() async {
    if (kIsWeb) {
      _webRemove(_keyEmail);
      _webRemove(_keyToken);  // Limpa token legado do localStorage
      return;
    }
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyEmail);
  }

  // _saveToken / _readToken: mantidos apenas para limpar dados legados do localStorage.
  // A API Key não é armazenada no storage do cliente — vem do Firestore via AppProvider.

  // ══════════════════════════════════════════════════════════════════════════
  // WEB — OAuth via Redirect Flow (Safari-safe)
  // ══════════════════════════════════════════════════════════════════════════

  /// Inicia fluxo OAuth no web via redirect (mesma aba).
  ///
  /// PROBLEMA: Safari bloqueia popups OAuth chamados via Flutter porque
  /// o Dart VM quebra a cadeia de gestos. window.open() é sempre bloqueado,
  /// mesmo com onclick nativo em botões HTML reais.
  ///
  /// SOLUÇÃO: Redirect flow — window.location.href para accounts.google.com.
  /// Google redireciona de volta para https://medcasespro.com/#access_token=...
  /// O JS em index.html (_checkRedirectReturn) processa o hash ANTES do Flutter
  /// carregar e salva o token no localStorage + seta flag 'medcases_gsi_pending'.
  /// checkGeminiSession() no AppProvider detecta a flag no próximo boot.
  ///
  /// Fluxo:
  ///   Flutter chama medcasesShowGSIModal() → modal HTML aparece
  ///   Usuário toca botão HTML → _gsiHandleClick() → window.location.href [redirect]
  ///   Google autentica → redireciona com #access_token no hash
  ///   _checkRedirectReturn() salva token + seta medcases_gsi_pending
  ///   App reinicia → checkGeminiSession() detecta token → _geminiConnected = true
  ///
  /// IMPORTANTE: este método retorna null imediatamente após abrir o modal.
  /// signIn() vai retornar false, mas isso é esperado — o token chegará
  /// via checkGeminiSession() no próximo boot do app após o redirect.
  static Future<String?> _webSignIn() async {
    try {
      // webLsGet retorna null em nativas (no-op) — no Web tenta chamar via js.
      // A função medcasesShowGSIModal está definida no index.html.
      // Usamos webLsGet como probe de disponibilidade do ambiente JS;
      // a chamada real ao modal usa a mesma camada isolada do import condicional.
      webCallGSIModal();
      debugPrint('[GeminiService] modal GSI aberto — redirect flow iniciado');
    } catch (e) {
      debugPrint('[GeminiService] _webSignIn ERRO: $e');
    }
    // Retorna null — o token virá via checkGeminiSession() após reload
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // API PÚBLICA
  // ══════════════════════════════════════════════════════════════════════════

  /// Conecta com Google (identidade apenas — scope email).
  /// Web: abre modal GSI → redirect flow → index.html salva email no localStorage.
  /// Android: google_sign_in → salva email no SharedPreferences.
  ///
  /// IMPORTANTE: signIn() só salva o EMAIL. A API Key vem do Firestore via
  /// AppProvider._loadAiKeyFromFirestore() — não depende do OAuth token.
  static Future<bool> signIn() async {
    try {
      debugPrint('[GeminiService] signIn() — web: $kIsWeb');

      if (kIsWeb) {
        // ── Web: abre modal GSI → redirect flow (Safari-safe) ────────────
        // _webSignIn() retorna null imediatamente (redirect — página vai recarregar).
        // O email chegará via checkGeminiSession() no próximo boot.
        await _webSignIn();
        return false;  // false = redirect iniciado (não é erro)

      } else {
        // ── Android: google_sign_in — salva apenas email ─────────────────
        // BUILD 283: signOut() antes de signIn() evita cache stale de sessões
        // anteriores que podem causar ApiException code 10 (DEVELOPER_ERROR).
        debugPrint('[GeminiService][Android] signOut() antes de signIn() (flush stale session)');
        await _googleSignIn.signOut();
        debugPrint('[GeminiService][Android] chamando _googleSignIn.signIn()…');
        final account = await _googleSignIn.signIn();
        if (account == null) {
          debugPrint('[GeminiService][Android] signIn cancelado pelo usuário (account=null)');
          return false;
        }
        // Salva apenas o email — a API Key não depende do accessToken
        await _saveEmail(account.email);
        debugPrint(
          '[GeminiService][Android] signIn OK — '
          'email=${account.email} '
          'displayName=${account.displayName} '
          'id=${account.id.substring(0, account.id.length.clamp(0, 6))}…',
        );
        return true;
      }
    } catch (e, st) {
      // BUILD 283: diagnóstico rico para ApiException do Google Sign-In
      // ApiException codes:
      //   7  = NETWORK_ERROR       → sem conectividade
      //   10 = DEVELOPER_ERROR     → SHA-1 não registrado no Firebase Console OU
      //                              google-services.json desatualizado OU
      //                              serverClientId inválido (corrigido no BUILD 283)
      //   12501 = SIGN_IN_CANCELLED → usuário cancelou
      //   12502 = SIGN_IN_CURRENTLY_IN_PROGRESS → chamada dupla concorrente
      final eStr = e.toString();
      String hint = '';
      if (eStr.contains('ApiException: 10') || eStr.contains('DEVELOPER_ERROR')) {
        hint = '\n  ▶ DEVELOPER_ERROR (code 10): causas comuns:\n'
            '    1. SHA-1 do keystore NÃO está no Firebase Console\n'
            '       → Firebase Console → Configurações → Android → Adicionar SHA-1\n'
            '    2. google-services.json desatualizado\n'
            '       → Baixar novo google-services.json do Firebase Console\n'
            '    3. serverClientId configurado incorretamente\n'
            '       → BUILD 283 já removeu serverClientId — confirme flutter pub get';
      } else if (eStr.contains('ApiException: 7') || eStr.contains('NETWORK_ERROR')) {
        hint = '\n  ▶ NETWORK_ERROR (code 7): dispositivo sem conectividade com Google';
      }
      debugPrint(
        '[GeminiService][signIn][ERRO] '
        'exception=${e.runtimeType} '
        'message=$e$hint\n'
        'stack=${st.toString().substring(0, st.toString().length.clamp(0, 500))}',
      );
      return false;
    }
  }

  /// Desconecta a conta Google.
  static Future<void> signOut() async {
    try {
      if (!kIsWeb) await _googleSignIn.signOut();
      await _deleteEmail();
    } catch (e) {
      debugPrint('[GeminiService] signOut error: $e');
    }
  }

  /// Verifica se há sessão ativa (silencioso — nunca lança exceção).
  ///
  /// Nova lógica (Session 4):
  ///   Conectado = email salvo E _geminiApiKey carregada pelo AppProvider.
  ///   Não valida mais token OAuth via tokeninfo (token não é mais usado).
  static Future<bool> isConnected() async {
    try {
      final email = await _readEmail();
      if (email == null || email.isEmpty) return false;
      // API Key deve ter sido carregada pelo AppProvider antes desta chamada.
      // Se não foi carregada ainda, retorna false silenciosamente.
      return _geminiApiKey.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> connectedEmail() async => _readEmail();

  // _getAccessToken() REMOVIDO — Gemini agora usa API Key, não OAuth token.
  // A chave é acessada via _geminiApiKey (campo estático setado pelo AppProvider).

  // ══════════════════════════════════════════════════════════════════════════
  // CHAT — Gemini 2.5 Flash com Google Search Grounding
  //
  // Modelo atualizado: gemini-1.5-flash descontinuado em Mai/2025
  // useGrounding=true ativa a ferramenta nativa de busca web do Gemini.
  // O modelo decide autonomamente quando buscar — ideal para perguntas
  // clínicas que podem precisar de dados atualizados (doses, guias, etc.)
  //
  // Rate-limit (429): retry automático com backoff exponencial
  //   Tentativa 1 → espera 2s → Tentativa 2 → espera 4s → Tentativa 3
  //   Se todas falharem → retorna errorCode 'quota'
  // Fila serial: evita requisições paralelas que multiplicam o 429
  // ══════════════════════════════════════════════════════════════════════════

  // ── Fila serial — garante 1 requisição ativa por vez ─────────────────────
  static Future<void> _queue = Future.value();

  static Future<GeminiResult> chat({
    required String userMessage,
    required String systemPrompt,
    List<Map<String, String>> history = const [],
    int maxTokens = 2200,
    bool useGrounding = true,
  }) async {
    // Encadeia na fila serial — garante 1 requisição ativa por vez
    final result = Completer<GeminiResult>();
    _queue = _queue.then((_) async {
      try {
        result.complete(await _chatInternal(
          userMessage: userMessage,
          systemPrompt: systemPrompt,
          history: history,
          maxTokens: maxTokens,
          useGrounding: useGrounding,
        ));
      } catch (e) {
        result.completeError(e);
      }
    });
    return result.future;
  }

  static Future<GeminiResult> _chatInternal({
    required String userMessage,
    required String systemPrompt,
    List<Map<String, String>> history = const [],
    int maxTokens = 2200,
    bool useGrounding = true,
    int retryCount = 0,
  }) async {
    if (_geminiApiKey.isEmpty) {
      return GeminiResult.error('NOT_CONNECTED', 'not_connected');
    }

    final contents = <Map<String, dynamic>>[];
    for (final msg in history) {
      final role = msg['role'] == 'assistant' ? 'model' : 'user';
      contents.add({'role': role, 'parts': [{'text': msg['content'] ?? ''}]});
    }
    contents.add({'role': 'user', 'parts': [{'text': userMessage}]});

    // Google Search Grounding — permite ao Gemini buscar na web em tempo real.
    // Isso transforma o modelo em um RAG real: consulta base interna (system prompt)
    // + busca web quando necessário (guias atualizadas, doses, artigos).
    final tools = useGrounding
        ? [{'google_search': {}}]
        : null;

    // Build 113 — CORREÇÃO CRÍTICA: thinkingConfig: {thinkingBudget: 0} é
    // INCOMPATÍVEL com Google Search Grounding (tools: [google_search]).
    // A API Gemini rejeita a combinação com HTTP 400 silencioso, causando
    // fallback sem system_instruction — o que explica o vazamento de metadados
    // ("El idioma de la última pregunta...") e respostas enciclopédicas em inglês.
    //
    // Build 114: thinkingConfig REMOVIDO DEFINITIVAMENTE.
    // flash-lite não suporta thinkingConfig + tools: [google_search] no mesmo payload.
    // A combinação gerava HTTP 400 silencioso → bypass do system_instruction → crashes Web.
    // Omitir thinkingConfig completamente é o comportamento correto e estável.
    final generationConfig = <String, dynamic>{
      'maxOutputTokens': maxTokens,
      'temperature': 0.4,
      'topP': 0.95,
      'topK': 40,
    };

    final bodyMap = <String, dynamic>{
      'system_instruction': {'parts': [{'text': systemPrompt}]},
      'contents': contents,
      'generationConfig': generationConfig,
      'safetySettings': [
        {'category': 'HARM_CATEGORY_HARASSMENT',        'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_HATE_SPEECH',       'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_NONE'},
      ],
    };
    if (tools != null) bodyMap['tools'] = tools;

    final body = jsonEncode(bodyMap);

    try {
      final response = await http.post(
        Uri.parse('$_endpoint?key=$_geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) {
          final blockReason = data['promptFeedback']?['blockReason'] as String?;
          debugPrint('[GeminiService] sem candidates. blockReason=$blockReason useGrounding=$useGrounding');
          // Se grounding falhou, tenta sem ele
          if (useGrounding) {
            return _chatInternal(
              userMessage: userMessage,
              systemPrompt: systemPrompt,
              history: history,
              maxTokens: maxTokens,
              useGrounding: false,
              retryCount: retryCount,
            );
          }
          return GeminiResult.error('BLOCKED: ${blockReason ?? "unknown"}', 'blocked');
        }
        final candidate = candidates[0] as Map<String, dynamic>;
        final finishReason = candidate['finishReason'] as String?;
        debugPrint('[GeminiService] finishReason=$finishReason useGrounding=$useGrounding');
        if (finishReason == 'SAFETY' || finishReason == 'RECITATION') {
          if (useGrounding) {
            return _chatInternal(
              userMessage: userMessage,
              systemPrompt: systemPrompt,
              history: history,
              maxTokens: maxTokens,
              useGrounding: false,
              retryCount: retryCount,
            );
          }
          return GeminiResult.error('BLOCKED: $finishReason', 'blocked');
        }
        final parts = candidate['content']?['parts'] as List?;
        if (parts == null || parts.isEmpty) {
          debugPrint('[GeminiService] parts vazio. candidate=$candidate');
          return GeminiResult.error('EMPTY_RESPONSE', 'unknown');
        }
        // Concatena apenas parts de texto final visível ao usuário.
        // Filtra: thought, functionCall, executableCode, codeExecutionResult.
        final text = parts
            .where((p) {
              final part = p as Map<String, dynamic>;
              if (part['thought'] == true) return false;
              if (part.containsKey('functionCall')) return false;
              if (part.containsKey('executableCode')) return false;
              if (part.containsKey('codeExecutionResult')) return false;
              if (!part.containsKey('text')) return false;
              return true;
            })
            .map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
            .join('')
            .trim();
        final cleanedText = _cleanInternalBlocks(text);
        if (cleanedText.isEmpty) {
          debugPrint('[GeminiService] texto vazio após join/clean. parts=$parts');
          return GeminiResult.error('EMPTY_TEXT', 'unknown');
        }

        // ── MAX_TOKENS / TRUNCAMENTO — detectar e retentar ─────────────────────
        // Regra 1: finishReason == MAX_TOKENS → texto cortado pelo modelo.
        // Regra 2: _isTruncated() detecta frases abertas independente do finishReason
        //          (pode ocorrer mesmo com STOP se o modelo parar no meio de bullet).
        // Em AMBOS os casos: retry com +60% tokens (cap 4000).
        // O usuário NUNCA deve ver resposta incompleta como mensagem final.
        final truncated = finishReason == 'MAX_TOKENS' || _isTruncated(cleanedText);
        if (truncated) {
          debugPrint('[GeminiService] Truncamento detectado — finishReason=$finishReason, isTruncated=${_isTruncated(cleanedText)}');
          if (maxTokens < 4000) {
            final expandedTokens = (maxTokens * 1.6).round().clamp(maxTokens + 500, 4000);
            debugPrint('[GeminiService] Retry $maxTokens→$expandedTokens tokens');
            return _chatInternal(
              userMessage: userMessage,
              systemPrompt: systemPrompt,
              history: history,
              maxTokens: expandedTokens,
              useGrounding: useGrounding,
              retryCount: retryCount,
            );
          }
          // Já no limite: retorna o que tem mas loga
          debugPrint('[GeminiService] MAX_TOKENS no limite (4000) — resposta pode estar incompleta');
        }

        return GeminiResult(text: cleanedText);
      }

      // ── BUILD 283: DIAGNÓSTICO RICO — todos os erros HTTP logados para Logcat ──
      // Para cada código HTTP, o log inclui:
      //   [HTTPXXX] → código numérico exato
      //   status=xxx → para grep fácil em `adb logcat | grep GeminiService`
      //   body_preview → primeiros 400 chars da resposta bruta da API
      //   endpoint → URL do modelo que falhou
      //   retry → número de tentativas já feitas
      //   key_present → confirma se a API key estava presente (sem expor o valor)
      // ──────────────────────────────────────────────────────────────────────────
      if (response.statusCode == 401 || response.statusCode == 403) {
        final bodyPreview = response.body.substring(
            0, response.body.length.clamp(0, 400));
        // Extrai errorCode e message da resposta JSON do Google (se disponível)
        String errorCode = 'UNKNOWN';
        String errorMessage = '';
        try {
          final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
          final error = errorBody?['error'] as Map<String, dynamic>?;
          errorCode    = error?['status']  as String? ?? 'UNKNOWN';
          errorMessage = error?['message'] as String? ?? '';
        } catch (_) {}
        // ── Logcat fingerprint ────────────────────────────────────────────
        debugPrint(
          '[GeminiService][HTTP${response.statusCode}] '
          'status=${response.statusCode} '
          'error_code=$errorCode '
          'error_message="${errorMessage.substring(0, errorMessage.length.clamp(0, 200))}" '
          'key_present=${_geminiApiKey.isNotEmpty} '
          'key_len=${_geminiApiKey.length} '
          'endpoint=$_endpoint '
          'retry=$retryCount '
          'body_preview="$bodyPreview"',
        );
        // Diagnóstico específico por código de erro da API Google:
        if (errorCode == 'API_KEY_INVALID' || errorCode == 'PERMISSION_DENIED') {
          debugPrint(
            '[GeminiService][DIAGNÓSTICO] API_KEY_INVALID/PERMISSION_DENIED:\n'
            '  1. Verifique se a chave está habilitada em console.cloud.google.com\n'
            '  2. Verifique se "Generative Language API" está ativada no projeto\n'
            '  3. Verifique se há restrições de IP ou referrer na chave\n'
            '  4. Se SHA-1 do keystore mudou, regenere a chave OAuth no Firebase Console',
          );
        }
        return GeminiResult.error('API_KEY_INVALID', 'api_key_invalid');
      }
      if (response.statusCode == 429) {
        // ── Retry automático com backoff exponencial (máx 3 tentativas) ────
        // Tentativa 0 → espera 2s → T1 → espera 4s → T2 → espera 8s → T3
        const maxRetries = 3;
        if (retryCount < maxRetries) {
          final waitSeconds = [2, 4, 8][retryCount];
          debugPrint('[GeminiService] 429 quota — retry ${retryCount + 1}/$maxRetries em ${waitSeconds}s');
          await Future.delayed(Duration(seconds: waitSeconds));
          return _chatInternal(
            userMessage: userMessage,
            systemPrompt: systemPrompt,
            history: history,
            maxTokens: maxTokens,
            useGrounding: useGrounding,
            retryCount: retryCount + 1,
          );
        }
        // Todas as tentativas esgotadas
        debugPrint('[GeminiService] 429 quota DEFINITIVO após $maxRetries retries');
        return GeminiResult.error('QUOTA_EXCEEDED', 'quota');
      }
      // ── Qualquer outro código HTTP (400, 500, 503, etc.) ─────────────────
      final unknownBody = response.body.substring(
          0, response.body.length.clamp(0, 400));
      debugPrint(
        '[GeminiService][HTTP${response.statusCode}] '
        'status=${response.statusCode} '
        'key_present=${_geminiApiKey.isNotEmpty} '
        'retry=$retryCount '
        'body="$unknownBody"',
      );
      return GeminiResult.error('HTTP_${response.statusCode}', 'unknown');

    } on http.ClientException catch (e, st) {
      // BUILD 283: ClientException inclui o tipo de falha de rede (DNS, timeout, TLS)
      debugPrint(
        '[GeminiService][NETWORK_ERROR] '
        'exception=${e.runtimeType} '
        'message=${e.message} '
        'uri=${e.uri} '
        'stack=${st.toString().substring(0, st.toString().length.clamp(0, 300))}',
      );
      return GeminiResult.error('NETWORK_ERROR: ${e.message}', 'network');
    } catch (e, st) {
      // BUILD 283: catch genérico — captura TimeoutException, SocketException
      // (via catch genérico, sem importar dart:io), erros de jsonDecode, etc.
      debugPrint(
        '[GeminiService][CATCH_ALL] '
        'exception=${e.runtimeType} '
        'message=$e '
        'key_present=${_geminiApiKey.isNotEmpty} '
        'retry=$retryCount '
        'stack=${st.toString().substring(0, st.toString().length.clamp(0, 400))}',
      );
      return GeminiResult.error('ERROR: ${e.runtimeType} — $e', 'unknown');
    }
  }
}
