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

class GeminiService {
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  // Client IDs do Google OAuth (usados pelo google_sign_in no Android e pelo
  // redirect flow no index.html — o _webClientId é usado no HTML, não aqui)
  static const _androidClientId =
      '1076800980330-0dhh85qno3uelf1tq55oan6kcgpk319p.apps.googleusercontent.com';

  // ── API Key estática (carregada do Firestore pelo AppProvider) ────────────
  static String _geminiApiKey = '';

  /// Setter chamado pelo AppProvider após carregar a chave do Firestore.
  static void setGeminiApiKey(String key) {
    _geminiApiKey = key.trim();
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

  // localStorage via eval() — resistente ao SES lockdown do Firebase Auth.
  // O lockdown-install.js do Firebase congela proxies do dart:js, fazendo
  // context['localStorage'].callMethod() retornar null silenciosamente.
  // eval() acessa o localStorage nativo do browser sem passar pelo proxy.

  static void _webSet(String key, String value) {
    try {
      final k = key.replaceAll("'", "\\'");
      final v = value.replaceAll("'", "\\'").replaceAll('\n', '\\n');
      js.context.callMethod('eval', ["localStorage.setItem('$k','$v')"]);
    } catch (_) {}
  }

  static String? _webGet(String key) {
    try {
      final k = key.replaceAll("'", "\\'");
      final result = js.context.callMethod('eval', ["localStorage.getItem('$k')"]);
      if (result == null || result.toString() == 'null') return null;
      return result.toString();
    } catch (_) { return null; }
  }

  static void _webRemove(String key) {
    try {
      final k = key.replaceAll("'", "\\'");
      js.context.callMethod('eval', ["localStorage.removeItem('$k')"]);
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
  // CHAT — Gemini 1.5 Flash
  // ══════════════════════════════════════════════════════════════════════════

  static Future<GeminiResult> chat({
    required String userMessage,
    required String systemPrompt,
    List<Map<String, String>> history = const [],
    int maxTokens = 900,
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

    final body = jsonEncode({
      'system_instruction': {'parts': [{'text': systemPrompt}]},
      'contents': contents,
      'generationConfig': {
        'maxOutputTokens': maxTokens,
        'temperature': 0.7,
        'topP': 0.9,
        'topK': 40,
      },
      'safetySettings': [
        {'category': 'HARM_CATEGORY_HARASSMENT',        'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_HATE_SPEECH',       'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_NONE'},
      ],
    });

    try {
      // API Key via query param — sem Authorization header (não usa OAuth token)
      final response = await http.post(
        Uri.parse('$_endpoint?key=$_geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) {
          final blockReason = data['promptFeedback']?['blockReason'] as String?;
          return GeminiResult.error('BLOCKED: ${blockReason ?? "unknown"}', 'blocked');
        }
        final candidate = candidates[0] as Map<String, dynamic>;
        final finishReason = candidate['finishReason'] as String?;
        if (finishReason == 'SAFETY' || finishReason == 'RECITATION') {
          return GeminiResult.error('BLOCKED: $finishReason', 'blocked');
        }
        final parts = candidate['content']?['parts'] as List?;
        if (parts == null || parts.isEmpty) {
          return GeminiResult.error('EMPTY_RESPONSE', 'unknown');
        }
        final text = parts[0]['text'] as String? ?? '';
        if (text.trim().isEmpty) {
          return GeminiResult.error('EMPTY_TEXT', 'unknown');
        }
        return GeminiResult(text: text.trim());
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        // 403 com API Key = chave inválida/revogada (não é token expirado)
        return GeminiResult.error('API_KEY_INVALID', 'api_key_invalid');
      }
      if (response.statusCode == 429) {
        return GeminiResult.error('QUOTA_EXCEEDED', 'quota');
      }
      debugPrint('[GeminiService] HTTP ${response.statusCode}: ${response.body}');
      return GeminiResult.error('HTTP_${response.statusCode}', 'unknown');

    } on http.ClientException {
      return GeminiResult.error('NETWORK_ERROR', 'network');
    } catch (e) {
      return GeminiResult.error('ERROR: $e', 'unknown');
    }
  }
}
