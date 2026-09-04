// ══════════════════════════════════════════════════════════════════════════════
// lib/services/ai_stream/gpt_sse_client.dart
// BUILD 462B-REDIRECIONADA — Real GPT SSE Client
//
// RESPONSABILIDADE:
//   Conecta ao endpoint gptProxyStream (Cloud Function v2 onRequest com SSE)
//   e converte a resposta em Stream<AiEvent>, consumindo bytes reais da rede.
//
// PROIBIDO NESTE ARQUIVO:
//   • Future.delayed de qualquer valor
//   • Fatiamento de texto em chunks de 30 chars
//   • Loops temporizados de 18ms
//   • Conversão de resposta fechada em stream artificial
//
// FLUXO REAL:
//   HTTP POST para gptProxyStream
//   → Content-Type: text/event-stream
//   → response.stream (bytes reais chegando do servidor)
//   → SseParser (decoder UTF-8 incremental + parser de linhas SSE)
//   → SseEventFilter (descarta requestId/attempt/sequence inválidos)
//   → AiEvent (AiStarted → AiTextDelta* → AiCompleted / AiFailed)
//
// CANCELAMENTO END-TO-END:
//   GptSseClient usa http.Client próprio por request — nunca global.
//   cancel() → fecha o http.Client → desconecta do endpoint SSE.
//   O backend detecta 'close' via res.on('close') e aciona AbortController.
//
// ESTADO DOS ESTADOS DE STREAM:
//   connecting → started → streaming → finalizing → completed
//                                   ↘ failed
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:http/http.dart' as http;
import '../../models/clinical_structured_output.dart';
import 'ai_event.dart';
import 'sse_parser.dart';

import '../clinical_identity_transport_envelope.dart';
typedef GptHttpClientFactory = http.Client Function();

// ─────────────────────────────────────────────────────────────────────────────
/// Payload clínico para o endpoint gptProxyStream.
/// Idêntico ao payload do callGptProxy (legado) — compatibilidade total.
// ─────────────────────────────────────────────────────────────────────────────
class GptSsePayload {
  final String userMessage;
  final String systemPrompt;
  final List<Map<String, String>> history;
  final String mode;
  final String lang;
  final String requestId;
  final int maxOutputTokens;

  const GptSsePayload({
    required this.userMessage,
    required this.systemPrompt,
    this.history = const [],
    this.mode = 'plantao',
    this.lang = 'pt',
    this.requestId = '',
    this.maxOutputTokens = 800,
  });

  Map<String, dynamic> toJson() => {
        'userMessage': userMessage,
        'systemPrompt': systemPrompt,
        ...ClinicalIdentityTransportEnvelope.fromStructuredSystemPrompt(systemPrompt),
        'history': history,
        'mode': mode,
        'lang': lang,
        'requestId': requestId,
        'maxOutputTokens': maxOutputTokens,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
/// Resultado do cancelamento de um stream GPT SSE.
// ─────────────────────────────────────────────────────────────────────────────
class GptSseCancellation {
  final String requestId;
  final int attempt;
  final int deltaCount;
  final int durationMs;
  final String reason;

  const GptSseCancellation({
    required this.requestId,
    required this.attempt,
    required this.deltaCount,
    required this.durationMs,
    required this.reason,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
/// Cliente SSE para o GPT fallback — cada request tem cliente HTTP próprio.
///
/// Uso:
///   final client = GptSseClient(
///     endpointUrl: GptSseClient.kDefaultEndpoint,
///     idToken: token,
///   );
///   await for (final event in client.stream(payload)) {
///     switch (event) {
///       AiStarted e      => ...
///       AiTextDelta e    => ...
///       AiCompleted e    => ...
///       AiFailed e       => ...
///       AiProviderSwitched e => ...
///       AiStreamReset e  => ...
///       _ => {}
///     }
///   }
///   // Para cancelar:
///   client.cancel(reason: 'user_cancelled');
// ─────────────────────────────────────────────────────────────────────────────
class GptSseClient {
  /// URL da Cloud Function gptProxyStream.
  /// Produção: us-central1-medcases-pro (mesmo projeto).
  static const String kDefaultEndpoint =
      'https://us-central1-medcases-pro.cloudfunctions.net/gptProxyStream';

  /// Attempt fixo para GPT fallback (Layer 2).
  static const int kGptAttempt = 2;

  /// Limiar de parcial clínico significativo (chars).
  static const int kSignificantPartialThreshold =
      AiFailed.kSignificantPartialThreshold;

  final String endpointUrl;
  final String idToken;
  final GptHttpClientFactory _clientFactory;

  // Estado interno — um cliente HTTP por request
  http.Client? _httpClient;
  bool _cancelled = false;
  bool _completed = false;

  // Identidade real informada pelo backend no evento started.
  String _activeModel = 'gpt-4o-mini';
  String _activeProvider = 'gpt_4o_mini';

  // Métricas de cancelamento
  int _deltaCount = 0;
  int _startMs = 0;

  GptSseClient({
    required this.endpointUrl,
    required this.idToken,
    GptHttpClientFactory? clientFactory,
  }) : _clientFactory = clientFactory ?? (() => http.Client());

  /// Cria cliente com endpoint padrão de produção.
  factory GptSseClient.production({required String idToken}) =>
      GptSseClient(endpointUrl: kDefaultEndpoint, idToken: idToken);

  // ──────────────────────────────────────────────────────────────────────────
  /// Conecta ao endpoint SSE e emite [AiEvent] em tempo real.
  ///
  /// O stream é cancelável: chamar [cancel()] fecha o http.Client e o stream
  /// fecha naturalmente (EOF ou exception → AiFailed local se sem transport_done).
  ///
  /// Garante:
  ///   • Primeiro AiTextDelta chega ANTES de a OpenAI terminar a resposta
  ///   • Nenhum Future.delayed ou fatiamento artificial
  ///   • Bytes reais da rede → SseParser → AiEvent
  // ──────────────────────────────────────────────────────────────────────────
  Stream<AiEvent> stream(GptSsePayload payload) async* {
    _startMs = DateTime.now().millisecondsSinceEpoch;
    _cancelled = false;
    _completed = false;
    _deltaCount = 0;
    _activeModel = 'gpt-4o-mini';
    _activeProvider = 'gpt_4o_mini';

    final reqId =
        payload.requestId.isEmpty ? 'req_$_startMs' : payload.requestId;

    _currentRequestId = reqId;

    // Criar http.Client dedicado a este request.
    // Em produção usa http.Client(); testes podem injetar transporte determinístico.
    _httpClient = _clientFactory();

    final parser = SseParser();
    final filter = SseEventFilter(
      requestId: reqId,
      expectedAttempt: kGptAttempt,
    );

    // Acumulador de texto para AiCompleted / AiFailed parcial
    final accumulator = StringBuffer();
    bool transportDoneReceived = false;
    int sequence = 0;

    // Escutar erros de protocolo SSE
    SseParseError? protocolError;
    parser.errors.listen((err) {
      protocolError = err;
      if (kDebugMode) {
        debugPrint('[GPT_SSE] protocol_error type=${err.eventType} '
            'error=${err.errorMessage}');
      }
    });

    if (kDebugMode) {
      debugPrint('[GPT_SSE] → connecting requestId=$reqId attempt=$kGptAttempt '
          'endpoint=$endpointUrl');
    }

    http.StreamedResponse? streamedResponse;
    try {
      final request = http.Request('POST', Uri.parse(endpointUrl))
        ..headers.addAll({
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $idToken',
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
        })
        ..body = jsonEncode(payload.toJson());

      streamedResponse = await _httpClient!.send(request);
    } catch (e) {
      _httpClient?.close();
      _httpClient = null;
      if (_cancelled) return; // cancelado antes da conexão — silencioso
      yield AiFailed.now(
        requestId: reqId,
        attempt: kGptAttempt,
        code: 'gpt_sse_connect_error',
        message: e.toString(),
        retryable: true,
      );
      parser.dispose();
      return;
    }

    // Verificar status HTTP ANTES de abrir SSE
    if (streamedResponse.statusCode == 401) {
      _httpClient?.close();
      _httpClient = null;
      yield AiFailed.now(
        requestId: reqId,
        attempt: kGptAttempt,
        code: 'gpt_sse_unauthenticated',
        message: 'HTTP 401 — antes dos headers SSE',
        retryable: false,
      );
      parser.dispose();
      return;
    }

    if (streamedResponse.statusCode == 429) {
      _httpClient?.close();
      _httpClient = null;
      yield AiFailed.now(
        requestId: reqId,
        attempt: kGptAttempt,
        code: 'gpt_sse_budget_guard',
        message: 'HTTP 429 — budget guard acionado',
        retryable: false,
      );
      parser.dispose();
      return;
    }

    if (streamedResponse.statusCode != 200) {
      _httpClient?.close();
      _httpClient = null;
      yield AiFailed.now(
        requestId: reqId,
        attempt: kGptAttempt,
        code: 'gpt_sse_http_${streamedResponse.statusCode}',
        message: 'HTTP ${streamedResponse.statusCode}',
        retryable: streamedResponse.statusCode >= 500,
      );
      parser.dispose();
      return;
    }

    // Verificar Content-Type
    final contentType = streamedResponse.headers['content-type'] ?? '';
    if (!contentType.contains('text/event-stream')) {
      _httpClient?.close();
      _httpClient = null;
      yield AiFailed.now(
        requestId: reqId,
        attempt: kGptAttempt,
        code: 'gpt_sse_wrong_content_type',
        message: 'Content-Type=$contentType (esperado text/event-stream)',
        retryable: false,
      );
      parser.dispose();
      return;
    }

    if (kDebugMode) {
      debugPrint('[GPT_SSE] ← connected requestId=$reqId '
          'status=${streamedResponse.statusCode} '
          'durationToConnect=${DateTime.now().millisecondsSinceEpoch - _startMs}ms');
    }

    // ── CONSUMO REAL DO STREAM DE BYTES ──────────────────────────────────────
    try {
      await for (final sseEvent
          in streamedResponse.stream.transform(parser.transformer)) {
        // Cancelado → fechar
        if (_cancelled) break;

        // Erro de protocolo acumulado → falha imediata
        if (protocolError != null) {
          final err = protocolError!;
          protocolError = null;
          yield AiFailed.now(
            requestId: reqId,
            attempt: kGptAttempt,
            code: 'sse_protocol_json_error',
            message: err.errorMessage,
            retryable: false,
            partialText: accumulator.isNotEmpty ? accumulator.toString() : null,
          );
          break;
        }

        // Filtrar eventos inválidos
        final verdict = filter.accept(sseEvent);
        if (!verdict.accepted) {
          if (kDebugMode) {
            debugPrint('[GPT_SSE] discarded type=${sseEvent.type} '
                'reason=${verdict.discardReason}');
          }
          continue;
        }

        // Processar evento por tipo
        switch (sseEvent.type) {
          case 'started':
            final data = sseEvent.data ?? {};

            _activeModel = data['model'] as String? ?? _activeModel;
            _activeProvider = data['provider'] as String? ?? _activeProvider;

            yield AiStarted.now(
              requestId: reqId,
              attempt: kGptAttempt,
              model: _activeModel,
              provider: _activeProvider,
            );

          case 'text_delta':
            final data = sseEvent.data ?? {};
            final delta = data['delta'] as String? ?? '';
            if (delta.isNotEmpty) {
              final seq = (data['sequence'] as num?)?.toInt() ?? sequence;
              sequence = seq + 1;
              _deltaCount++;
              accumulator.write(delta);
              yield AiTextDelta.now(
                requestId: reqId,
                attempt: kGptAttempt,
                delta: delta,
                sequence: seq,
              );
            }

          case 'sources':
            final data = sseEvent.data ?? {};
            final rawList = data['sources'];
            if (rawList is List) {
              final sources = rawList
                  .whereType<Map>()
                  .map((s) => s.cast<String, String>())
                  .toList();
              yield AiSources(
                requestId: reqId,
                attempt: kGptAttempt,
                timestamp: AiEvent.nowIso(),
                sources: sources,
              );
            }

          case 'transport_done':
            // Backend sinaliza conclusão do transporte
            // AppProvider emitirá AiCompleted APÓS sanitizeAndCheck()
            transportDoneReceived = true;
            _completed = true;
            final data = sseEvent.data ?? {};

            _activeModel = data['model'] as String? ?? _activeModel;
            _activeProvider = data['provider'] as String? ?? _activeProvider;

            final inputTok = (data['inputTokensApprox'] as num?)?.toInt() ?? 0;
            final outputTok =
                (data['outputTokensApprox'] as num?)?.toInt() ?? 0;

            final rawStructuredOutput = data['structuredOutput'];
            ClinicalStructuredOutput? clinicalOutput;

            if (rawStructuredOutput != null) {
              try {
                if (rawStructuredOutput is! Map) {
                  throw const FormatException(
                    'clinical_structured_output_invalid_root',
                  );
                }

                clinicalOutput = ClinicalStructuredOutput.fromJson(
                  Map<String, dynamic>.from(rawStructuredOutput),
                );
              } on FormatException catch (error) {
                // Um payload estruturado não nulo representa um contrato
                // explícito do backend. Falhas de forma ou conteúdo não podem
                // ser degradadas silenciosamente para o caminho legado.
                transportDoneReceived = true;
                _completed = false;

                yield AiFailed.now(
                  requestId: reqId,
                  attempt: kGptAttempt,
                  code: 'gpt_sse_invalid_structured_output',
                  message: error.message.toString(),
                  retryable: false,
                  partialText:
                      accumulator.isNotEmpty ? accumulator.toString() : null,
                );
                break;
              } on TypeError catch (error) {
                transportDoneReceived = true;
                _completed = false;

                yield AiFailed.now(
                  requestId: reqId,
                  attempt: kGptAttempt,
                  code: 'gpt_sse_invalid_structured_output',
                  message: error.toString(),
                  retryable: false,
                  partialText:
                      accumulator.isNotEmpty ? accumulator.toString() : null,
                );
                break;
              }
            }

            final durationMs = DateTime.now().millisecondsSinceEpoch - _startMs;
            if (kDebugMode) {
              debugPrint('[GPT_SSE] ✅ transport_done requestId=$reqId '
                  'attempt=$kGptAttempt deltaCount=$_deltaCount '
                  'textLen=${accumulator.length} durationMs=$durationMs');
            }
            // Emitir AiCompleted com texto acumulado (sanitizeAndCheck() é responsabilidade do AppProvider)
            yield AiCompleted.now(
              requestId: reqId,
              attempt: kGptAttempt,
              fullText: accumulator.toString(),
              usedProvider: _activeProvider,
              inputTokensApprox: inputTok,
              outputTokensApprox: outputTok,
              durationMs: durationMs,
              clinicalOutput: clinicalOutput,
            );
            break;

          case 'error':
            final data = sseEvent.data ?? {};
            final code = data['error'] as String? ?? 'gpt_sse_server_error';
            final message = data['message'] as String? ?? '';
            yield AiFailed.now(
              requestId: reqId,
              attempt: kGptAttempt,
              code: code,
              message: message,
              retryable: _isRetryable(code),
              partialText:
                  accumulator.isNotEmpty ? accumulator.toString() : null,
            );
            break;

          default:
            // Tipo desconhecido → ignorar (tolerância para eventos futuros)
            if (kDebugMode) {
              debugPrint('[GPT_SSE] unknown event type=${sseEvent.type}');
            }
        }

        // Se transport_done foi recebido, sair do loop
        if (transportDoneReceived) break;
      }
    } catch (e) {
      if (!_cancelled) {
        if (kDebugMode) {
          debugPrint('[GPT_SSE] stream_error requestId=$reqId error=$e');
        }
        // Emitir AiFailed somente se ainda não completou
        if (!transportDoneReceived) {
          final partialLen = accumulator.length;
          yield AiFailed.now(
            requestId: reqId,
            attempt: kGptAttempt,
            code: 'gpt_sse_stream_error',
            message: e.toString(),
            retryable: true,
            partialText: partialLen > 0 ? accumulator.toString() : null,
          );
        }
      }
    } finally {
      // ── EOF sem transport_done → criar AiFailed local ─────────────────────
      if (!transportDoneReceived && !_cancelled && accumulator.isNotEmpty) {
        final durationMs = DateTime.now().millisecondsSinceEpoch - _startMs;
        if (kDebugMode) {
          debugPrint('[GPT_SSE] eof_no_transport_done requestId=$reqId '
              'partialLen=${accumulator.length} durationMs=$durationMs');
        }
        yield AiFailed.now(
          requestId: reqId,
          attempt: kGptAttempt,
          code: 'eof_no_transport_done',
          message: 'Stream encerrou sem transport_done',
          retryable: false,
          partialText: accumulator.toString(),
        );
      }

      _httpClient?.close();
      _httpClient = null;
      parser.dispose();

      if (kDebugMode) {
        debugPrint('[GPT_SSE] closed requestId=$reqId '
            'cancelled=$_cancelled completed=$_completed '
            'deltaCount=$_deltaCount '
            'durationMs=${DateTime.now().millisecondsSinceEpoch - _startMs}');
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  /// Cancela o request em andamento.
  ///
  /// Fecha o http.Client dedicado → desconecta do endpoint SSE.
  /// O backend detecta via res.on('close') e aciona AbortController upstream.
  ///
  /// LOGS (conforme contrato — sem dados clínicos ou API keys):
  ///   requestId, attempt, provider, motivo, duração, quantidade de deltas.
  // ──────────────────────────────────────────────────────────────────────────
  GptSseCancellation cancel({String reason = 'user_cancelled'}) {
    _cancelled = true;
    _httpClient?.close();
    _httpClient = null;

    final durationMs = DateTime.now().millisecondsSinceEpoch - _startMs;

    // Log de cancelamento — SEM API key, ID Token, prompt, dados do paciente
    debugPrint('[GPT_SSE] cancel requestId=$_currentRequestId '
        'attempt=$kGptAttempt provider=$_activeProvider '
        'model=$_activeModel reason=$reason '
        'durationMs=$durationMs deltaCount=$_deltaCount');

    return GptSseCancellation(
      requestId: _currentRequestId,
      attempt: kGptAttempt,
      deltaCount: _deltaCount,
      durationMs: durationMs,
      reason: reason,
    );
  }

  String _currentRequestId = '';

  static bool _isRetryable(String code) => switch (code) {
        'cf_timeout' => true,
        'cf_internal' => true,
        'timeout' => true,
        'network' => true,
        'http_503' => true,
        _ => false,
      };
}
