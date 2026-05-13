import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// GEMINI SERVICE — OAuth Google (sem API key manual)
//
// Fluxo:
//   1. Usuário toca "Conectar com Google"
//   2. GoogleSignIn abre tela nativa de seleção de conta
//   3. Recebemos accessToken OAuth com escopo Generative Language
//   4. Token salvo em flutter_secure_storage (Keychain/Keystore)
//   5. Chamadas ao Gemini usam token Bearer — sem chave nossa
//   6. Token renova automaticamente via google_sign_in
// ─────────────────────────────────────────────────────────────────────────────

class GeminiResult {
  final String text;
  final bool isError;
  final String? errorCode; // 'not_connected' | 'token_expired' | 'quota' | 'network' | 'unknown'
  const GeminiResult({required this.text, this.isError = false, this.errorCode});
  factory GeminiResult.error(String msg, String code) =>
      GeminiResult(text: msg, isError: true, errorCode: code);
}

class GeminiService {
  // ── Escopo necessário para Gemini API via OAuth ───────────────────────────
  static const _scopes = [
    'email',
    'https://www.googleapis.com/auth/generative-language.retriever',
  ];

  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  static const _storageKey = 'gemini_google_email';

  static final _storage = FlutterSecureStorage(
    aOptions: const AndroidOptions(encryptedSharedPreferences: true),
    iOptions: const IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static final _googleSignIn = GoogleSignIn(scopes: _scopes);

  // ── Conectar com Google (2 cliques) ──────────────────────────────────────
  /// Retorna true se conectou com sucesso.
  static Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return false; // usuário cancelou

      // Salva o e-mail para mostrar na UI
      await _storage.write(key: _storageKey, value: account.email);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[GeminiService] signIn error: $e');
      return false;
    }
  }

  // ── Desconectar ──────────────────────────────────────────────────────────
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _storage.delete(key: _storageKey);
    } catch (e) {
      if (kDebugMode) debugPrint('[GeminiService] signOut error: $e');
    }
  }

  // ── Estado atual ─────────────────────────────────────────────────────────
  /// Verifica se há conta conectada (sem fazer rede).
  static Future<bool> isConnected() async {
    final stored = await _storage.read(key: _storageKey);
    if (stored == null || stored.isEmpty) return false;
    // Confirma que a sessão ainda existe no GoogleSignIn
    final current = _googleSignIn.currentUser;
    if (current != null) return true;
    // Tenta restaurar sessão silenciosamente
    try {
      final restored = await _googleSignIn.signInSilently();
      return restored != null;
    } catch (_) {
      return false;
    }
  }

  /// E-mail do usuário conectado (para mostrar na UI).
  static Future<String?> connectedEmail() async {
    return _storage.read(key: _storageKey);
  }

  // ── Obter token de acesso ────────────────────────────────────────────────
  static Future<String?> _getAccessToken() async {
    try {
      // 1. Tenta conta atual
      GoogleSignInAccount? account = _googleSignIn.currentUser;

      // 2. Se não há conta atual, restaura silenciosamente
      account ??= await _googleSignIn.signInSilently();
      if (account == null) return null;

      // 3. Pega (ou renova) o token — google_sign_in renova automaticamente
      final auth = await account.authentication;
      return auth.accessToken;
    } catch (e) {
      if (kDebugMode) debugPrint('[GeminiService] _getAccessToken error: $e');
      return null;
    }
  }

  // ── Chamada principal ao Gemini ──────────────────────────────────────────
  static Future<GeminiResult> chat({
    required String userMessage,
    required String systemPrompt,
    List<Map<String, String>> history = const [],
    int maxTokens = 900,
  }) async {
    final token = await _getAccessToken();
    if (token == null) {
      return GeminiResult.error('NOT_CONNECTED', 'not_connected');
    }

    // Monta o array de contents no formato Gemini
    final contents = <Map<String, dynamic>>[];

    // Injeta histórico de conversa
    for (final msg in history) {
      final role = msg['role'] == 'assistant' ? 'model' : 'user';
      contents.add({
        'role': role,
        'parts': [{'text': msg['content'] ?? ''}],
      });
    }

    // Mensagem atual do usuário
    contents.add({
      'role': 'user',
      'parts': [{'text': userMessage}],
    });

    final body = jsonEncode({
      'system_instruction': {
        'parts': [{'text': systemPrompt}],
      },
      'contents': contents,
      'generationConfig': {
        'maxOutputTokens': maxTokens,
        'temperature': 0.4,
      },
    });

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        return GeminiResult(text: text.trim());
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        // Token expirou ou escopo insuficiente — força novo login
        await _googleSignIn.signOut();
        await _storage.delete(key: _storageKey);
        return GeminiResult.error('TOKEN_EXPIRED', 'token_expired');
      }

      if (response.statusCode == 429) {
        return GeminiResult.error('QUOTA_EXCEEDED', 'quota');
      }

      if (kDebugMode) {
        debugPrint('[GeminiService] HTTP ${response.statusCode}: ${response.body}');
      }
      return GeminiResult.error('HTTP_${response.statusCode}', 'unknown');

    } on http.ClientException {
      return GeminiResult.error('NETWORK_ERROR', 'network');
    } catch (e) {
      return GeminiResult.error('ERROR: $e', 'unknown');
    }
  }
}
