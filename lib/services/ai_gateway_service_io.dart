// ══════════════════════════════════════════════════════════════════════════════
// AiGatewayService — Implementação IO (iOS / Android / macOS / desktop)
// Build 146
//
// Usa package:http com http.Client.send() para leitura de stream SSE.
// O http.Client nativo usa dart:io internamente, que lê o socket TCP de
// forma verdadeiramente incremental — sem buffering extra.
//
// Este arquivo é importado APENAS em plataformas nativas (não-Web).
// Na Web, ai_gateway_service_web.dart assume o lugar.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'gemini_service_v2.dart' show GeminiChunk;

// ─────────────────────────────────────────────────────────────────────────────
// Implementação IO do runner de SSE
// Chamada por AiGatewayService._runSseStream() via stub de plataforma
// ─────────────────────────────────────────────────────────────────────────────

Future<void> runSseStreamPlatform({
  required StreamController<GeminiChunk> controller,
  required String streamUrl,
  required String payload,
  required String requestId,
}) async {
  final client = http.Client();
  final request = http.Request('POST', Uri.parse(streamUrl))
    ..headers.addAll({
      'Content-Type':  'application/json',
      'Accept':        'text/event-stream',
      'Cache-Control': 'no-cache',
      'X-Request-ID':  requestId,
    })
    ..body = payload;

  bool completionFired = false;

  // ── Watchdog de primeiro chunk ──────────────────────────────────────────
  bool firstChunkReceived = false;
  Timer? firstChunkTimer = Timer(const Duration(seconds: 50), () {
    if (!firstChunkReceived && !controller.isClosed) {
      debugPrint('[GW-IO][$requestId] Timeout — sem primeiro chunk');
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error('timeout'))
          ..close();
      }
      client.close();
    }
  });

  try {
    final streamedResponse = await client.send(request).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        firstChunkTimer?.cancel();
        client.close();
        throw TimeoutException('Conexão expirou', const Duration(seconds: 15));
      },
    );

    // ── Erros HTTP ────────────────────────────────────────────────────────
    if (streamedResponse.statusCode != 200) {
      firstChunkTimer?.cancel();
      client.close();
      final code = _httpStatusToCode(streamedResponse.statusCode);
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error(code))
          ..close();
      }
      return;
    }

    // ── Lê stream SSE byte a byte ─────────────────────────────────────────
    String buffer = '';

    await for (final bytes in streamedResponse.stream) {
      if (controller.isClosed) break;

      if (!firstChunkReceived) {
        firstChunkReceived = true;
        firstChunkTimer?.cancel();
        firstChunkTimer = null;
      }

      buffer += utf8.decode(bytes, allowMalformed: true);

      // Processa eventos SSE completos (\n\n delimitador)
      while (true) {
        final end = buffer.indexOf('\n\n');
        if (end == -1) break;

        final block = buffer.substring(0, end);
        buffer = buffer.substring(end + 2);

        final result = _processEventBlock(block, requestId);
        if (result == null) continue;
        if (result == _kDone) {
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
        if (result.startsWith(_kError)) {
          if (!completionFired) {
            completionFired = true;
            if (!controller.isClosed) {
              controller
                ..add(GeminiChunk.error(result.substring(_kError.length)))
                ..close();
            }
          }
          return;
        }
        // Texto normal
        if (result.isNotEmpty && !controller.isClosed) {
          controller.add(GeminiChunk(text: result));
        }
      }

      if (completionFired) break;
    }

    if (!completionFired && !controller.isClosed) {
      controller
        ..add(GeminiChunk.done)
        ..close();
    }

  } on TimeoutException {
    firstChunkTimer?.cancel();
    if (!controller.isClosed) {
      controller
        ..add(GeminiChunk.error('timeout'))
        ..close();
    }
  } catch (e) {
    firstChunkTimer?.cancel();
    debugPrint('[GW-IO][$requestId] Erro: $e');
    if (!controller.isClosed) {
      controller
        ..add(GeminiChunk.error('network'))
        ..close();
    }
  } finally {
    firstChunkTimer?.cancel();
    client.close();
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

const _kDone  = '__DONE__';
const _kError = '__ERROR__:';

/// Processa um bloco de evento SSE (entre dois \n\n).
/// Retorna:
///   null      → evento ignorado (ping, comentário)
///   _kDone    → done recebido
///   '__ERROR__:código' → erro recebido
///   String    → texto do chunk
String? _processEventBlock(String block, String requestId) {
  for (final line in block.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith(':')) continue;
    if (!trimmed.startsWith('data:')) continue;

    final jsonStr = trimmed.substring(5).trim();
    if (jsonStr == '[DONE]') return _kDone;

    Map<String, dynamic> event;
    try {
      event = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      continue;
    }

    if (event.containsKey('error')) {
      return '$_kError${event['error'] ?? 'server_error'}';
    }
    if (event['done'] == true) return _kDone;

    final text = event['text']?.toString() ?? '';
    if (text.isNotEmpty) return text;
  }
  return null;
}

String _httpStatusToCode(int status) {
  switch (status) {
    case 400: return 'bad_request';
    case 401:
    case 403: return 'api_key_invalid';
    case 429: return 'quota';
    case 500:
    case 502:
    case 503: return 'server_error';
    default:  return 'http_$status';
  }
}
