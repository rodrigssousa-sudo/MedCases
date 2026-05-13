import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// GEMINI SERVICE — OAuth Google (sem API key manual)
//
// Fluxo:
//   1. Usuário toca "Conectar com Google"
//   2. GoogleSignIn abre tela nativa de seleção de conta
//   3. Recebemos accessToken OAuth com escopo Generative Language
//   4. Email salvo em shared_preferences (Web-compatible)
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
  // ── Escopos necessários para Gemini API via OAuth ─────────────────────────
  static const _scopes = [
    'email',
    'https://www.googleapis.com/auth/generative-language.retriever',
  ];

  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  static const _storageKey = 'gemini_google_email';

  // Client IDs gerados no Google Cloud Console
  static const _androidClientId =
      '1076800980330-0dhh85qno3uelf1tq55oan6kcgpk319p.apps.googleusercontent.com';
  static const _webClientId =
      '1076800980330-mpq75ceph6hipht135qt0g505pdu5u7d.apps.googleusercontent.com';

  static final _googleSignIn = GoogleSignIn(
    scopes: _scopes,
    // Web usa clientId direto; Android usa serverClientId para obter accessToken
    clientId: kIsWeb ? _webClientId : null,
    serverClientId: kIsWeb ? null : _androidClientId,
  );

  // ── Helpers de storage (Web-compatible) ──────────────────────────────────
  static Future<void> _saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, email);
  }

  static Future<String?> _readEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storageKey);
  }

  static Future<void> _deleteEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  // ── Conectar com Google ───────────────────────────────────────────────────
  static Future<bool> signIn() async {
    try {
      debugPrint('[GeminiService] signIn() — web: $kIsWeb');
      final account = await _googleSignIn.signIn();
      if (account == null) {
        debugPrint('[GeminiService] signIn cancelado pelo usuário');
        return false;
      }
      debugPrint('[GeminiService] signIn OK — ${account.email}');
      await _saveEmail(account.email);
      return true;
    } catch (e, st) {
      debugPrint('[GeminiService] signIn ERRO: $e');
      debugPrint('[GeminiService] STACK: $st');
      return false;
    }
  }

  // ── Desconectar ───────────────────────────────────────────────────────────
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _deleteEmail();
    } catch (e) {
      debugPrint('[GeminiService] signOut error: $e');
    }
  }

  // ── Estado atual ──────────────────────────────────────────────────────────
  static Future<bool> isConnected() async {
    final stored = await _readEmail();
    if (stored == null || stored.isEmpty) return false;
    final current = _googleSignIn.currentUser;
    if (current != null) return true;
    try {
      final restored = await _googleSignIn.signInSilently();
      return restored != null;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> connectedEmail() async => _readEmail();

  // ── Obter token de acesso ─────────────────────────────────────────────────
  static Future<String?> _getAccessToken() async {
    try {
      GoogleSignInAccount? account = _googleSignIn.currentUser;
      account ??= await _googleSignIn.signInSilently();
      if (account == null) return null;
      final auth = await account.authentication;
      return auth.accessToken;
    } catch (e) {
      debugPrint('[GeminiService] _getAccessToken error: $e');
      return null;
    }
  }

  // ── Chamada principal ao Gemini ───────────────────────────────────────────
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

    final contents = <Map<String, dynamic>>[];
    for (final msg in history) {
      final role = msg['role'] == 'assistant' ? 'model' : 'user';
      contents.add({'role': role, 'parts': [{'text': msg['content'] ?? ''}]});
    }
    contents.add({'role': 'user', 'parts': [{'text': userMessage}]});

    final body = jsonEncode({
      'system_instruction': {'parts': [{'text': systemPrompt}]},
      'contents': contents,
      'generationConfig': {'maxOutputTokens': maxTokens, 'temperature': 0.4},
    });

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        return GeminiResult(text: text.trim());
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        await _googleSignIn.signOut();
        await _deleteEmail();
        return GeminiResult.error('TOKEN_EXPIRED', 'token_expired');
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
