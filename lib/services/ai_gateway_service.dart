// ══════════════════════════════════════════════════════════════════════════════
// AiGatewayService — Build 146
// Cliente SSE para o MedCases AI Gateway (servidor Node.js/Express)
//
// ARQUITETURA:
//   Flutter → POST /api/ai/stream → servidor Express → Gemini SSE → Flutter
//
// VANTAGENS vs. BYOA (GeminiServiceV2):
//   • API key gerenciada exclusivamente no servidor (não exposta no cliente)
//   • ANTI_COGNITION_LEAK_PROMPT injetado server-side como primeiro bloco
//   • Rate limit e retry no servidor (60 req/min por IP, 3 retries)
//   • Filtros duplos de CoT no servidor (API flags + padrão textual)
//
// PROTOCOLO SSE DO SERVIDOR:
//   Eventos recebidos:
//     data: {"text":"fragmento"}\n\n   → chunk de texto
//     data: {"done":true}\n\n         → stream concluído
//     data: {"error":"código"}\n\n    → falha com código
//     : ping\n\n                       → heartbeat (ignorado)
//
// INTERFACE DE SAÍDA:
//   Stream<GeminiChunk> — mesma interface do GeminiServiceV2 para que o
//   AppProvider possa usar os dois backends de forma transparente.
//
// CONFIGURAÇÃO:
//   AiGatewayService.configure(baseUrl: 'https://seu-servidor.ondigitalocean.app')
//   AiGatewayService.isConfigured → true se baseUrl foi definida
//
// MODO DE ATIVAÇÃO:
//   Primário: quando baseUrl configurada E usuário NÃO tem BYOA key
//   Opt-in:   pode ser forçado via AiGatewayService.forceGateway = true
//
// ANTI-BUFFERING (Build 146):
//   Importação condicional por plataforma:
//     • IO  (iOS/Android/desktop): ai_gateway_service_io.dart
//         → usa package:http com http.Client.send() streaming — dart:io lê
//           o socket TCP de forma incremental, sem buffering extra.
//     • Web (Flutter Web / dart2js): ai_gateway_service_web.dart
//         → usa dart:js_interop + window.fetch() nativo com ReadableStream,
//           bypassando o BrowserClient do http.dart e eliminando o
//           micro-batching do Dart VM na Web.
//   A função runSseStreamPlatform() é o ponto de entrada de cada arquivo.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'gemini_service_v2.dart' show GeminiChunk;

// ── Importação condicional por plataforma (Build 146) ────────────────────────
// Na Web: ai_gateway_service_web.dart (dart:js_interop + fetch nativo)
// Nas demais plataformas: ai_gateway_service_io.dart (http.Client streaming)
import 'ai_gateway_service_io.dart'
    if (dart.library.js_interop) 'ai_gateway_service_web.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AiGatewayService
// ─────────────────────────────────────────────────────────────────────────────
class AiGatewayService {
  AiGatewayService._(); // classe estática — sem instâncias

  // ── Configuração ───────────────────────────────────────────────────────────

  /// URL base do servidor AI Gateway (ex: 'https://medcases-ai.ondigitalocean.app').
  /// Deve ser definida via [configure()] antes do primeiro uso.
  static String? _baseUrl;

  /// true → usa o gateway mesmo quando BYOA key estiver disponível.
  /// Útil para testes comparativos ou quando o servidor tem quota maior.
  static bool forceGateway = false;

  /// Configura o endpoint base do servidor.
  /// [baseUrl] deve incluir protocolo e host, sem barra no final.
  /// Exemplo: 'https://medcases-pro-ai.ondigitalocean.app'
  static void configure({required String baseUrl}) {
    _baseUrl = baseUrl.trimRight().replaceAll(RegExp(r'/$'), '');
    debugPrint('[AiGatewayService] Configurado → $_baseUrl');
  }

  /// true se o gateway foi configurado e está pronto para uso.
  static bool get isConfigured => _baseUrl != null && _baseUrl!.isNotEmpty;

  /// Endpoint de streaming SSE.
  static String get _streamUrl => '$_baseUrl/api/ai/stream';

  /// Endpoint síncrono (Context Classifier).
  static String get _syncUrl => '$_baseUrl/api/ai/sync';

  // ── Stream SSE principal ────────────────────────────────────────────────────

  /// Envia uma mensagem ao servidor e retorna um [Stream<GeminiChunk>].
  ///
  /// [userMessage]  — pergunta clínica do usuário
  /// [systemPrompt] — prompt de sistema montado pelo AiService (19 seções)
  /// [history]      — histórico de turnos [{role, content}]
  /// [useGrounding] — ativar Google Search no servidor (padrão: true)
  ///
  /// O servidor injeta automaticamente o ANTI_COGNITION_LEAK_PROMPT ANTES
  /// do [systemPrompt], garantindo a blindagem anti-CoT server-side.
  static Stream<GeminiChunk> sendStream({
    required String userMessage,
    required String systemPrompt,
    List<Map<String, String>> history = const [],
    bool useGrounding = true,
  }) {
    if (!isConfigured) {
      return Stream.value(GeminiChunk.error('gateway_not_configured'));
    }

    final controller = StreamController<GeminiChunk>();
    _runSseStream(
      controller: controller,
      userMessage: userMessage,
      systemPrompt: systemPrompt,
      history: history,
      useGrounding: useGrounding,
    );
    return controller.stream;
  }

  // ── Pipeline interno — delega à implementação de plataforma (Build 146) ─────

  static Future<void> _runSseStream({
    required StreamController<GeminiChunk> controller,
    required String userMessage,
    required String systemPrompt,
    required List<Map<String, String>> history,
    required bool useGrounding,
  }) async {
    if (controller.isClosed) return;

    final requestId = 'gw_${DateTime.now().millisecondsSinceEpoch}';
    debugPrint('[AiGatewayService][$requestId] iniciando stream → $_streamUrl');

    // Monta o payload JSON que será enviado ao servidor
    final payload = jsonEncode({
      'userMessage':  userMessage,
      'systemPrompt': systemPrompt,
      'history':      history,
      'useGrounding': useGrounding,
    });

    // Delega à função runSseStreamPlatform() do arquivo de plataforma
    // selecionado em compile-time pela importação condicional acima:
    //   • Web  → ai_gateway_service_web.dart  (fetch nativo via dart:js_interop)
    //   • IO   → ai_gateway_service_io.dart   (http.Client streaming)
    await runSseStreamPlatform(
      controller: controller,
      streamUrl:  _streamUrl,
      payload:    payload,
      requestId:  requestId,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  // Mantido para compatibilidade caso algum código externo referencie.
  // Na Build 146 os erros são emitidos dentro de runSseStreamPlatform().
  static void _emitError(StreamController<GeminiChunk> ctrl, String code) {
    if (!ctrl.isClosed) {
      ctrl
        ..add(GeminiChunk.error(code))
        ..close();
    }
  }

  // ── Context Classifier síncrono (opcional) ─────────────────────────────────

  /// Chama o endpoint síncrono do servidor para classificar contexto.
  /// Retorna 'MÉDICO' ou 'NOVO', com fallback conservador 'MÉDICO'.
  ///
  /// [prompt] — prompt completo (system + pergunta do usuário)
  /// [maxTokens] — limite de tokens da resposta (padrão: 20)
  static Future<String> classifyContext(String prompt, {int maxTokens = 20}) async {
    if (!isConfigured) return 'MÉDICO';

    try {
      final response = await http.post(
        Uri.parse(_syncUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userMessage': prompt,
          'systemPrompt': 'Responda apenas MÉDICO ou NOVO.',
          'maxTokens': maxTokens,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return 'MÉDICO';

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = (data['text'] ?? '').toString().trim().toUpperCase();
      return text.contains('NOVO') ? 'NOVO' : 'MÉDICO';
    } catch (_) {
      return 'MÉDICO'; // fallback conservador
    }
  }

  // ── Health check ────────────────────────────────────────────────────────────

  /// Verifica se o servidor está online.
  /// Retorna true se o endpoint /health retornar status 200.
  static Future<bool> checkHealth() async {
    if (!isConfigured) return false;
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
