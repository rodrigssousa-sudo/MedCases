// ══════════════════════════════════════════════════════════════════════════════
// AiGatewayService — Implementação WEB (Flutter Web / dart2js)
// Build 146
//
// PROBLEMA RAIZ DO BUFFERING NA WEB:
//   O pacote `http` usa `BrowserClient` que internamente chama window.fetch().
//   Mesmo que o ReadableStream seja incremental, o layer Dart VM (dart2js) pode
//   introduzir micro-batches antes de entregar ao `await for`. Além disso,
//   proxies Nginx podem buffer chunks até 4KB ou 1s de inatividade.
//
// SOLUÇÃO (Build 146):
//   Usar a Fetch API nativa do navegador via `dart:js_interop` com extension
//   types (Dart 3+), lendo o ReadableStream diretamente sem passar pelo
//   package:http. Cada chunk chega ao Dart no exato momento em que o navegador
//   o recebe do TCP socket — sem overhead adicional.
//
// EXTENSTION TYPES (Dart 3 / dart:js_interop):
//   Usamos `extension type` em vez de `@staticInterop` para compatibilidade
//   com Dart 3.x. O parâmetro T de JSPromise<T> deve ser `JSAny?`, então
//   usamos JSPromise<JSAny?> e fazemos cast do resultado com `.dartify()` /
//   acesso via membros externos declarados nas extension types.
// ══════════════════════════════════════════════════════════════════════════════

// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'gemini_service_v2.dart' show GeminiChunk;

// ── Extension types para Fetch API ───────────────────────────────────────────
// Todos os tipos JS devem ser subtypes de JSAny para serem usados com JSPromise

extension type _JsResponse._(JSObject _) implements JSAny {
  external int get status;
  external _JsReadableStream? get body;
}

extension type _JsReadableStream._(JSObject _) implements JSAny {
  external _JsReader getReader();
}

extension type _JsReader._(JSObject _) implements JSAny {
  external JSPromise<_JsReadResult> read();
  @JS('cancel')
  external JSPromise<JSAny?> cancelStream();
}

extension type _JsReadResult._(JSObject _) implements JSAny {
  external bool get done;
  external JSUint8Array? get value;
}

// _JsFetchInit: objeto de inicialização do fetch (method, headers, body)
extension type _JsFetchInit._(JSObject _) implements JSAny {
  external factory _JsFetchInit({
    JSString method,
    JSAny? headers,
    JSAny? body,
  });
}

// ── Declaração externa de window.fetch() ─────────────────────────────────────
@JS('fetch')
external JSPromise<_JsResponse> _jsFetch(JSString url, _JsFetchInit init);

// ─────────────────────────────────────────────────────────────────────────────
// Implementação Web do runner de SSE
// ─────────────────────────────────────────────────────────────────────────────

Future<void> runSseStreamPlatform({
  required StreamController<GeminiChunk> controller,
  required String streamUrl,
  required String payload,
  required String requestId,
}) async {
  debugPrint('[GW-Web][$requestId] Iniciando fetch SSE nativo → $streamUrl');

  bool completionFired = false;

  // ── Watchdog de primeiro chunk ──────────────────────────────────────────
  bool firstChunkReceived = false;
  Timer? firstChunkTimer = Timer(const Duration(seconds: 50), () {
    if (!firstChunkReceived && !controller.isClosed) {
      debugPrint('[GW-Web][$requestId] Timeout — sem primeiro chunk em 50s');
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error('timeout'))
          ..close();
      }
    }
  });

  _JsReader? reader;

  try {
    // ── Monta headers como JS object ────────────────────────────────────
    final headersMap = {
      'Content-Type':  'application/json',
      'Accept':        'text/event-stream',
      'Cache-Control': 'no-cache',
      'X-Request-ID':  requestId,
    };
    final headersJs = headersMap.jsify();

    // Body como Uint8Array (via .toJS em List<int>)
    final bodyBytes = utf8.encode(payload);
    final bodyJs    = bodyBytes.toJS;

    // ── Chamada fetch() nativa ───────────────────────────────────────────
    final fetchInit = _JsFetchInit(
      method:  'POST'.toJS,
      headers: headersJs,
      body:    bodyJs,
    );

    _JsResponse response;
    try {
      response = await _jsFetch(streamUrl.toJS, fetchInit).toDart;
    } catch (e) {
      firstChunkTimer?.cancel();
      debugPrint('[GW-Web][$requestId] fetch() falhou: $e');
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error('network'))
          ..close();
      }
      return;
    }

    // ── Verifica status HTTP ─────────────────────────────────────────────
    if (response.status != 200) {
      firstChunkTimer?.cancel();
      final code = _httpStatusToCode(response.status);
      debugPrint('[GW-Web][$requestId] HTTP ${response.status} → $code');
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error(code))
          ..close();
      }
      return;
    }

    // ── Obtém o ReadableStream do body ───────────────────────────────────
    final bodyStream = response.body;
    if (bodyStream == null) {
      firstChunkTimer?.cancel();
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error('stream_error'))
          ..close();
      }
      return;
    }

    reader = bodyStream.getReader();
    String buffer = '';

    // ── Loop de leitura chunk a chunk (ReadableStreamDefaultReader) ───────
    // Cada iteração recebe um Uint8Array diretamente do TCP socket do browser.
    // Não há buffering adicional por parte do Dart VM — o chunk chega no
    // exato milissegundo em que o browser o despacha do socket TCP.
    while (true) {
      if (controller.isClosed) break;

      final readResult = await reader.read().toDart;

      if (readResult.done) {
        // Stream encerrado pelo servidor
        break;
      }

      final chunkBytes = readResult.value;
      if (chunkBytes == null) continue;

      // Primeiro chunk recebido — cancela watchdog
      if (!firstChunkReceived) {
        firstChunkReceived = true;
        firstChunkTimer?.cancel();
        firstChunkTimer = null;
        debugPrint('[GW-Web][$requestId] Primeiro chunk recebido via fetch nativo');
      }

      // Decodifica bytes → string UTF-8
      buffer += utf8.decode(chunkBytes.toDart, allowMalformed: true);

      // Processa eventos SSE completos (\n\n como delimitador)
      // Um único read() pode conter zero, um ou múltiplos eventos SSE.
      bool keepProcessing = true;
      while (keepProcessing && buffer.contains('\n\n')) {
        final end   = buffer.indexOf('\n\n');
        final block = buffer.substring(0, end);
        buffer      = buffer.substring(end + 2);

        final result = _processEventBlock(block, requestId);
        if (result == null) continue;

        if (result == _kDone) {
          completionFired = true;
          if (!controller.isClosed) {
            controller
              ..add(GeminiChunk.done)
              ..close();
          }
          keepProcessing = false;
          break;
        }

        if (result.startsWith(_kError)) {
          completionFired = true;
          if (!controller.isClosed) {
            controller
              ..add(GeminiChunk.error(result.substring(_kError.length)))
              ..close();
          }
          keepProcessing = false;
          break;
        }

        // Chunk de texto: emite IMEDIATAMENTE (controller.add é síncrono)
        if (result.isNotEmpty && !controller.isClosed) {
          controller.add(GeminiChunk(text: result));
        }
      }

      if (completionFired) break;
    }

    // Fim do stream sem done explícito
    if (!completionFired && !controller.isClosed) {
      debugPrint('[GW-Web][$requestId] Stream encerrado sem done explícito');
      controller
        ..add(GeminiChunk.done)
        ..close();
    }

  } catch (e) {
    firstChunkTimer?.cancel();
    debugPrint('[GW-Web][$requestId] Erro inesperado: $e');
    if (!controller.isClosed) {
      controller
        ..add(GeminiChunk.error('network'))
        ..close();
    }
  } finally {
    firstChunkTimer?.cancel();
    // Cancela o reader para liberar o ReadableStream no navegador
    try {
      await reader?.cancelStream().toDart;
    } catch (_) {}
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

const _kDone  = '__DONE__';
const _kError = '__ERROR__:';

/// Processa um bloco de evento SSE (entre dois \n\n).
/// Retorna:
///   null            → evento ignorado (ping, comentário)
///   _kDone          → done recebido
///   '__ERROR__:code' → erro recebido
///   String          → texto do chunk
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
