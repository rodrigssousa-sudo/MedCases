import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

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

class GeminiService {
  // gemini-1.5-flash foi descontinuado em Mai/2025 → atualizado para gemini-2.5-flash
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  // Client IDs do Google OAuth (usados pelo google_sign_in no Android e pelo
  // redirect flow no index.html — o _webClientId é usado no HTML, não aqui)
  static const _androidClientId =
      '1076800980330-0dhh85qno3uelf1tq55oan6kcgpk319p.apps.googleusercontent.com';

  // ── API Key estática (carregada do Firestore pelo AppProvider) ────────────
  static String _geminiApiKey = '';
  static const _keyGak = 'medcases_gak'; // localStorage key para persistência entre reloads

  /// Setter chamado pelo AppProvider após carregar a chave do Firestore.
  /// Automaticamente persiste no localStorage para sobreviver reloads do service worker.
  static void setGeminiApiKey(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return;
    _geminiApiKey = trimmed;
    // Persiste via dart:js (mcLsSet) E via SharedPreferences (dupla garantia)
    if (kIsWeb) _webSet(_keyGak, trimmed);
    // SharedPreferences em background — não bloqueia, garante persistência
    SharedPreferences.getInstance().then((p) {
      p.setString(_keyGak, trimmed);
    }).catchError((_) {});
    debugPrint('[GeminiService] API Key definida e cacheada (localStorage + SharedPrefs) ✓');
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
        debugPrint('[GeminiService] API Key restaurada do SharedPreferences no boot ✓');
        return;
      }
    } catch (_) {}
    // Secundário: dart:js → mcLsGet (se disponível no window)
    if (kIsWeb) {
      final cached = _webGet(_keyGak);
      if (cached != null && cached.isNotEmpty) {
        _geminiApiKey = cached;
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

  /// Verifica se a API Key foi carregada (sem expor a chave em si).
  static bool get hasApiKey => _geminiApiKey.isNotEmpty;

  // Chaves de storage
  static const _keyEmail = 'gemini_google_email';
  // _keyToken mantido para limpeza de localStorage legado (não mais usado para auth)
  static const _keyToken = 'gemini_access_token';

  // ── Android: google_sign_in ───────────────────────────────────────────────
  static final _googleSignIn = GoogleSignIn(
    scopes: ['email'],  // Apenas email — sem scope restrito
    serverClientId: _androidClientId,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // STORAGE — localStorage (web) / SharedPreferences (Android)
  // ══════════════════════════════════════════════════════════════════════════

  // localStorage via funções globais window.mcLsGet / mcLsSet / mcLsRemove.
  // Definidas no index.html ANTES do Firebase/SES lockdown ser aplicado —
  // capturam a referência nativa ao localStorage enquanto ainda acessível.
  // Sem eval, sem proxies congelados: funciona com qualquer CSP em produção.

  static void _webSet(String key, String value) {
    try {
      js.context.callMethod('mcLsSet', [key, value]);
    } catch (_) {}
  }

  static String? _webGet(String key) {
    try {
      final result = js.context.callMethod('mcLsGet', [key]);
      if (result == null || result.toString() == 'null') return null;
      return result.toString();
    } catch (_) { return null; }
  }

  static void _webRemove(String key) {
    try {
      js.context.callMethod('mcLsRemove', [key]);
    } catch (_) {}
  }

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
      final hasFn = js.context.hasProperty('medcasesShowGSIModal');
      if (!hasFn) {
        debugPrint('[GeminiService] medcasesShowGSIModal não encontrada');
        return null;
      }
      // Abre o modal HTML. O onclick do botão chama _gsiHandleClick()
      // que faz window.location.href → redirect. A página vai recarregar,
      // então não há como aguardar um token aqui — retornamos null.
      js.context.callMethod('medcasesShowGSIModal', []);
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
        await _googleSignIn.signOut();
        final account = await _googleSignIn.signIn();
        if (account == null) {
          debugPrint('[GeminiService] Android signIn cancelado');
          return false;
        }
        // Salva apenas o email — a API Key não depende do accessToken
        await _saveEmail(account.email);
        debugPrint('[GeminiService] Android signIn OK — ${account.email}');
        return true;
      }
    } catch (e, st) {
      debugPrint('[GeminiService] signIn ERRO: $e\n$st');
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
  // ══════════════════════════════════════════════════════════════════════════

  static Future<GeminiResult> chat({
    required String userMessage,
    required String systemPrompt,
    List<Map<String, String>> history = const [],
    int maxTokens = 1800,
    bool useGrounding = true, // Google Search Grounding ativado por padrão
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

    final bodyMap = <String, dynamic>{
      'system_instruction': {'parts': [{'text': systemPrompt}]},
      'contents': contents,
      'generationConfig': {
        'maxOutputTokens': maxTokens,
        'temperature': 0.4,  // Respostas clínicas exigem maior determinismo
        'topP': 0.95,
        'topK': 40,
      },
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
            return chat(
              userMessage: userMessage,
              systemPrompt: systemPrompt,
              history: history,
              maxTokens: maxTokens,
              useGrounding: false,
            );
          }
          return GeminiResult.error('BLOCKED: ${blockReason ?? "unknown"}', 'blocked');
        }
        final candidate = candidates[0] as Map<String, dynamic>;
        final finishReason = candidate['finishReason'] as String?;
        debugPrint('[GeminiService] finishReason=$finishReason useGrounding=$useGrounding');
        if (finishReason == 'SAFETY' || finishReason == 'RECITATION') {
          if (useGrounding) {
            return chat(
              userMessage: userMessage,
              systemPrompt: systemPrompt,
              history: history,
              maxTokens: maxTokens,
              useGrounding: false,
            );
          }
          return GeminiResult.error('BLOCKED: $finishReason', 'blocked');
        }
        // MAX_TOKENS — resposta cortada mas usável
        if (finishReason == 'MAX_TOKENS') {
          debugPrint('[GeminiService] MAX_TOKENS atingido — usando resposta parcial');
        }
        final parts = candidate['content']?['parts'] as List?;
        if (parts == null || parts.isEmpty) {
          debugPrint('[GeminiService] parts vazio. candidate=$candidate');
          return GeminiResult.error('EMPTY_RESPONSE', 'unknown');
        }
        // Concatena apenas parts de texto final (Grounding pode gerar múltiplas parts)
        // Ignora parts do tipo 'thought' (raciocínio interno do Gemini 2.5 Flash)
        final text = parts
            .where((p) {
              final part = p as Map<String, dynamic>;
              // Gemini 2.5 Flash: parts de raciocínio têm {"thought": true} ou role != text
              final isThought = part['thought'] == true;
              return !isThought;
            })
            .map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
            .join('')
            .trim();
        final cleanedText = _cleanInternalBlocks(text);
        if (cleanedText.isEmpty) {
          debugPrint('[GeminiService] texto vazio após join/clean. parts=$parts');
          return GeminiResult.error('EMPTY_TEXT', 'unknown');
        }
        return GeminiResult(text: cleanedText);
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('[GeminiService] 401/403: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
        return GeminiResult.error('API_KEY_INVALID', 'api_key_invalid');
      }
      if (response.statusCode == 429) {
        debugPrint('[GeminiService] 429 quota: ${response.body.substring(0, response.body.length.clamp(0, 200))}');
        return GeminiResult.error('QUOTA_EXCEEDED', 'quota');
      }
      debugPrint('[GeminiService] HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 400))}');
      return GeminiResult.error('HTTP_${response.statusCode}', 'unknown');

    } on http.ClientException {
      return GeminiResult.error('NETWORK_ERROR', 'network');
    } catch (e) {
      return GeminiResult.error('ERROR: $e', 'unknown');
    }
  }
}
