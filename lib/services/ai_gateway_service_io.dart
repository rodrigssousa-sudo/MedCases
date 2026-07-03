// ══════════════════════════════════════════════════════════════════════════════
// AiGatewayService — Implementação IO (iOS / Android / macOS / desktop)
// BUILD 309 — S2: dart:io HttpClient com connectionTimeout=8s
//
// PROBLEMA RESOLVIDO — IPv6 SYN Stall em Operadoras Brasileiras (S2):
//   package:http.Client() sem connectionTimeout deixa o dart:io aguardar o
//   handshake TCP do IPv6 por até 15s em operadoras BR (Claro, TIM, Vivo)
//   antes de falhar — sem Happy Eyeballs automático, sem fallback IPv4.
//   Resultado: timeout sempre na primeira call Android → falso "erro de rede".
//
// SOLUÇÃO:
//   HttpClient() do dart:io com connectionTimeout=8s encerra o SYN stall de
//   IPv6 em 8s — rápido o suficiente para o usuário perceber a falha e o
//   sistema de retry acionar a rota IPv4 via _httpStatusToCode('timeout').
//   HttpClient usa badCertificateCallback=null (padrão seguro, valida TLS).
//
// Este arquivo é importado APENAS em plataformas nativas (não-Web).
// Na Web, ai_gateway_service_web.dart assume o lugar.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;                                       // BUILD 309 S2: dart:io direto
import 'package:flutter/foundation.dart' show debugPrint;
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
  // BUILD 309 [S2]: HttpClient nativo dart:io com connectionTimeout de 8s.
  // Ao contrário de package:http.Client(), o HttpClient expõe connectionTimeout
  // no nível do socket TCP — aborta o SYN/SYN-ACK de IPv6 em 8s e libera o
  // fluxo para que a camada de retry (firstChunkTimer) tente outro endereço.
  // Sem connectionTimeout: o dart:io aguardaria até 60s (TCP kernel default)
  // em stall de IPv6 de operadora, superando o timeout de 15s do client.send()
  // que só cobre o tempo de resposta HTTP, não o handshake TCP.
  final ioClient = io.HttpClient()
    ..connectionTimeout = const Duration(seconds: 8); // trava SYN stall IPv6

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
      ioClient.close(force: true);
    }
  });

  try {
    final uri = Uri.parse(streamUrl);

    // BUILD 309 [S2]: openUrl + timeout cobre o handshake HTTPS completo.
    // connectionTimeout (acima) cobre o TCP SYN; este timeout cobre o TLS.
    final ioRequest = await ioClient
        .openUrl('POST', uri)
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            firstChunkTimer?.cancel();
            ioClient.close(force: true);
            throw TimeoutException('Handshake expirou', const Duration(seconds: 15));
          },
        );

    // Headers SSE idênticos ao fluxo anterior
    ioRequest.headers
      ..set(io.HttpHeaders.contentTypeHeader, 'application/json')
      ..set(io.HttpHeaders.acceptHeader,      'text/event-stream')
      ..set('Cache-Control', 'no-cache')
      ..set('X-Request-ID', requestId);

    // Escreve body e fecha o side de escrita
    ioRequest.write(payload);

    final ioResponse = await ioRequest.close().timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        firstChunkTimer?.cancel();
        ioClient.close(force: true);
        throw TimeoutException('Conexão expirou', const Duration(seconds: 15));
      },
    );

    // ── Erros HTTP ────────────────────────────────────────────────────────
    if (ioResponse.statusCode != 200) {
      firstChunkTimer?.cancel();
      ioClient.close(force: true);
      final code = _httpStatusToCode(ioResponse.statusCode);
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error(code))
          ..close();
      }
      return;
    }

    // ── Lê stream SSE byte a byte ─────────────────────────────────────────
    String buffer = '';

    await for (final bytes in ioResponse) {
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
    debugPrint('[GW-IO][$requestId] TimeoutException — connectionTimeout ou handshake');
    if (!controller.isClosed) {
      controller
        ..add(GeminiChunk.error('timeout'))
        ..close();
    }
  } on io.SocketException catch (e) {
    // BUILD 309 [S2]: SocketException captura falhas de resolução DNS e
    // rejeições de conexão — inclui ECONNREFUSED e ENETUNREACH (IPv6 sem rota).
    firstChunkTimer?.cancel();
    debugPrint('[GW-IO][$requestId] SocketException: ${e.message} (osError=${e.osError?.errorCode})');
    if (!controller.isClosed) {
      controller
        ..add(GeminiChunk.error('network'))
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
    ioClient.close(force: true);
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
