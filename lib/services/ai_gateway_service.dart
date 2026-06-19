// ══════════════════════════════════════════════════════════════════════════════
// AiGatewayService — Build 145
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
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'gemini_service_v2.dart' show GeminiChunk;

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

  // ── Timeouts ────────────────────────────────────────────────────────────────

  /// Timeout para estabelecer a conexão inicial com o servidor.
  static const _connectTimeout = Duration(seconds: 15);

  /// Timeout para receber o primeiro chunk após conexão.
  /// O servidor tem watchdog de 45s — alinhado para ser um pouco maior.
  static const _firstChunkTimeout = Duration(seconds: 50);

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

  // ── Pipeline interno ────────────────────────────────────────────────────────

  static Future<void> _runSseStream({
    required StreamController<GeminiChunk> controller,
    required String userMessage,
    required String systemPrompt,
    required List<Map<String, String>> history,
    required bool useGrounding,
  }) async {
    if (controller.isClosed) return;

    final requestId = 'gw_${DateTime.now().millisecondsSinceEpoch}';
    debugPrint('[AiGatewayService][$requestId] Iniciando stream SSE → $_streamUrl');

    // ── Monta payload ──────────────────────────────────────────────────────
    final payload = jsonEncode({
      'userMessage':  userMessage,
      'systemPrompt': systemPrompt,
      'history':      history,
      'useGrounding': useGrounding,
    });

    // ── http.Client com suporte a streaming ───────────────────────────────
    // Usamos http.Client.send() com Request em vez de http.post() porque
    // precisamos acessar response.stream (body como Stream<List<int>>)
    // que não está disponível no Response estático do http.post().
    final client = http.Client();
    final request = http.Request('POST', Uri.parse(_streamUrl))
      ..headers.addAll({
        'Content-Type':  'application/json',
        'Accept':        'text/event-stream',
        'Cache-Control': 'no-cache',
        'X-Request-ID':  requestId,
      })
      ..body = payload;

    // ── Watchdog de primeiro chunk ─────────────────────────────────────────
    // Se o servidor não responder dentro de _firstChunkTimeout, emite timeout.
    Timer? firstChunkTimer;
    bool firstChunkReceived = false;

    firstChunkTimer = Timer(_firstChunkTimeout, () {
      if (!firstChunkReceived && !controller.isClosed) {
        debugPrint('[AiGatewayService][$requestId] Timeout — sem primeiro chunk após ${_firstChunkTimeout.inSeconds}s');
        _emitError(controller, 'timeout');
        client.close();
      }
    });

    try {
      // ── Conecta com timeout ────────────────────────────────────────────
      final streamedResponse = await client.send(request).timeout(
        _connectTimeout,
        onTimeout: () {
          firstChunkTimer?.cancel();
          client.close();
          throw TimeoutException('Conexão com o servidor expirou', _connectTimeout);
        },
      );

      // ── Erros HTTP ────────────────────────────────────────────────────
      if (streamedResponse.statusCode == 401 || streamedResponse.statusCode == 403) {
        firstChunkTimer?.cancel();
        client.close();
        _emitError(controller, 'api_key_invalid');
        return;
      }
      if (streamedResponse.statusCode == 400) {
        firstChunkTimer?.cancel();
        client.close();
        _emitError(controller, 'bad_request');
        return;
      }
      if (streamedResponse.statusCode == 429) {
        firstChunkTimer?.cancel();
        client.close();
        _emitError(controller, 'quota');
        return;
      }
      if (streamedResponse.statusCode == 500) {
        firstChunkTimer?.cancel();
        client.close();
        _emitError(controller, 'server_error');
        return;
      }
      if (streamedResponse.statusCode != 200) {
        firstChunkTimer?.cancel();
        client.close();
        _emitError(controller, 'http_${streamedResponse.statusCode}');
        return;
      }

      // ── Lê stream SSE chunk a chunk ───────────────────────────────────
      // O servidor envia linhas no formato SSE padrão.
      // Acumula bytes até encontrar '\n\n' (fim de evento SSE).
      final decoder   = utf8.decoder;
      String buffer   = '';
      bool completionFired = false;

      await for (final bytes in streamedResponse.stream) {
        if (controller.isClosed) break;

        // Primeiro chunk recebido — cancela watchdog
        if (!firstChunkReceived) {
          firstChunkReceived = true;
          firstChunkTimer?.cancel();
          firstChunkTimer = null;
          debugPrint('[AiGatewayService][$requestId] Primeiro chunk recebido');
        }

        buffer += decoder.convert(bytes);

        // Processa eventos SSE completos (delimitados por '\n\n')
        while (true) {
          final eventEnd = buffer.indexOf('\n\n');
          if (eventEnd == -1) break; // evento incompleto — aguarda mais bytes

          final eventBlock = buffer.substring(0, eventEnd);
          buffer = buffer.substring(eventEnd + 2);

          for (final line in eventBlock.split('\n')) {
            final trimmed = line.trim();

            // Ignora linhas de comentário (heartbeat ': ping')
            if (trimmed.isEmpty || trimmed.startsWith(':')) continue;

            // Processa linha 'data: {...}'
            if (!trimmed.startsWith('data:')) continue;

            final jsonStr = trimmed.substring(5).trim();
            if (jsonStr == '[DONE]') {
              completionFired = true;
              if (!controller.isClosed) {
                controller
                  ..add(GeminiChunk.done)
                  ..close();
              }
              return;
            }

            // Parseia JSON do evento
            Map<String, dynamic> event;
            try {
              event = jsonDecode(jsonStr) as Map<String, dynamic>;
            } catch (e) {
              debugPrint('[AiGatewayService][$requestId] JSON inválido ignorado: ${jsonStr.substring(0, jsonStr.length.clamp(0, 80))}');
              continue;
            }

            // ── Evento de erro do servidor ──────────────────────────────
            if (event.containsKey('error')) {
              final code = event['error']?.toString() ?? 'server_error';
              debugPrint('[AiGatewayService][$requestId] Erro recebido: $code');
              if (!completionFired) {
                completionFired = true;
                _emitError(controller, code);
              }
              return;
            }

            // ── Evento de conclusão ────────────────────────────────────
            if (event['done'] == true) {
              if (!completionFired) {
                completionFired = true;
                if (!controller.isClosed) {
                  controller
                    ..add(GeminiChunk.done)
                    ..close();
                }
              }
              return;
            }

            // ── Chunk de texto ─────────────────────────────────────────
            final text = event['text']?.toString() ?? '';
            if (text.isNotEmpty && !controller.isClosed) {
              controller.add(GeminiChunk(text: text));
            }
          }

          if (completionFired) return;
        }
      }

      // Stream encerrado pelo servidor sem evento done explícito
      if (!completionFired && !controller.isClosed) {
        debugPrint('[AiGatewayService][$requestId] Stream encerrado sem done explícito');
        controller
          ..add(GeminiChunk.done)
          ..close();
      }

    } on TimeoutException catch (e) {
      firstChunkTimer?.cancel();
      debugPrint('[AiGatewayService][$requestId] TimeoutException: $e');
      _emitError(controller, 'timeout');
    } catch (e) {
      firstChunkTimer?.cancel();
      debugPrint('[AiGatewayService][$requestId] Erro inesperado: $e');
      _emitError(controller, 'network');
    } finally {
      firstChunkTimer?.cancel();
      client.close();
      debugPrint('[AiGatewayService][$requestId] Stream encerrado. client.close()');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

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
