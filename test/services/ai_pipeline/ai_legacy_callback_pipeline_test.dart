import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/ai_pipeline_contracts.dart';

AiRequestContract buildRequest() {
  return AiRequestContract(
    requestId: 'request-bridge',
    sessionId: 'session-bridge',
    input: 'Avaliar paciente.',
    mode: AiRequestMode.plantao,
    locale: AiRequestLocale.pt,
    sourceSurface: AiSourceSurface.aiScreen,
  );
}

void main() {
  group('LegacyCallbackAiResponsePipeline', () {
    test('converte snapshots acumulados em deltas', () async {
      final pipeline = LegacyCallbackAiResponsePipeline(
        provider: 'legacy-provider',
        runner: (
          request, {
          required onChunk,
          required onDone,
          required onError,
        }) async {
          onChunk('Con');
          onChunk('Conduta');
          onDone('Conduta final.');
          return true;
        },
      );

      final events = await pipeline.execute(buildRequest()).toList();

      expect(events, hasLength(4));

      final first = events[1] as AiResponseDelta;
      final second = events[2] as AiResponseDelta;
      final terminal = events[3] as AiResponseTerminal;

      expect(first.delta, 'Con');
      expect(first.replacesAccumulatedText, isFalse);
      expect(second.delta, 'duta');
      expect(second.replacesAccumulatedText, isFalse);
      expect(terminal.result.finalText, 'Conduta final.');
      expect(terminal.result.provider, 'legacy-provider');
    });

    test('identifica substituição e suprime duplicata', () async {
      final pipeline = LegacyCallbackAiResponsePipeline(
        runner: (
          request, {
          required onChunk,
          required onDone,
          required onError,
        }) async {
          onChunk('Inicial');
          onChunk('Inicial');
          onChunk('Substituta');
          onDone('Substituta');
          return true;
        },
      );

      final events = await pipeline.execute(buildRequest()).toList();

      final deltas = events.whereType<AiResponseDelta>().toList();

      expect(deltas, hasLength(2));
      expect(deltas.last.delta, 'Substituta');
      expect(
        deltas.last.replacesAccumulatedText,
        isTrue,
      );
    });

    test('emite somente o primeiro terminal', () async {
      final pipeline = LegacyCallbackAiResponsePipeline(
        runner: (
          request, {
          required onChunk,
          required onDone,
          required onError,
        }) async {
          onDone('Primeiro terminal.');
          onError('Erro tardio.');
          onDone('Segundo terminal.');
          onChunk('Chunk tardio.');
          return true;
        },
      );

      final events = await pipeline.execute(buildRequest()).toList();

      final terminals = events.whereType<AiResponseTerminal>().toList();

      expect(terminals, hasLength(1));
      expect(
        terminals.single.result.finalText,
        'Primeiro terminal.',
      );
      expect(events.whereType<AiResponseDelta>(), isEmpty);
    });

    test('agrega callback textual e structured output', () async {
      final structured = <String, Object?>{
        'diagnostico': 'Pneumonia',
      };

      final pipeline = LegacyCallbackAiResponsePipeline(
        runner: (
          request, {
          required onChunk,
          required onDone,
          required onError,
        }) async {
          onDone('Resposta estruturada.');
          onDone('Resposta estruturada.', structured);
          return true;
        },
      );

      final events = await pipeline.execute(buildRequest()).toList();

      final terminal = events.last as AiResponseTerminal;

      expect(terminal.result.finalText, 'Resposta estruturada.');
      expect(
        terminal.result.structuredOutput,
        same(structured),
      );
    });

    test('aceita structured output explicitamente nulo', () async {
      final pipeline = LegacyCallbackAiResponsePipeline(
        runner: (
          request, {
          required onChunk,
          required onDone,
          required onError,
        }) async {
          onDone('Resposta.');
          onDone('Resposta.', null);
          return true;
        },
      );

      final events = await pipeline.execute(buildRequest()).toList();

      expect(
        events.whereType<AiResponseTerminal>(),
        hasLength(1),
      );
    });

    test('materializa rejeição e exceção', () async {
      final rejected = LegacyCallbackAiResponsePipeline(
        runner: (
          request, {
          required onChunk,
          required onDone,
          required onError,
        }) async {
          return false;
        },
      );

      final throwing = LegacyCallbackAiResponsePipeline(
        runner: (
          request, {
          required onChunk,
          required onDone,
          required onError,
        }) async {
          throw StateError('falha simulada');
        },
      );

      final rejectedEvents = await rejected.execute(buildRequest()).toList();

      final throwingEvents = await throwing.execute(buildRequest()).toList();

      expect(
        (rejectedEvents.last as AiResponseTerminal).result.errorCode,
        'legacy_send_rejected',
      );

      expect(
        (throwingEvents.last as AiResponseTerminal).result.errorCode,
        'legacy_runner_exception',
      );
    });

    test('preserva parcial e códigos de autenticação', () async {
      final partial = LegacyCallbackAiResponsePipeline(
        runner: (
          request, {
          required onChunk,
          required onDone,
          required onError,
        }) async {
          onChunk('Resposta parcial.');
          onError('stream_error');
          return false;
        },
      );

      final auth = LegacyCallbackAiResponsePipeline(
        runner: (
          request, {
          required onChunk,
          required onDone,
          required onError,
        }) async {
          onError('AUTH_REQUIRED');
          return false;
        },
      );

      final partialEvents = await partial.execute(buildRequest()).toList();

      final authEvents = await auth.execute(buildRequest()).toList();

      final partialTerminal = partialEvents.last as AiResponseTerminal;

      expect(partialTerminal.result.isPartial, isTrue);
      expect(
        partialTerminal.result.finalText,
        'Resposta parcial.',
      );

      expect(
        (authEvents.last as AiResponseTerminal).result.errorCode,
        'AUTH_REQUIRED',
      );
    });

    test('encaminha cancelamento exatamente uma vez', () async {
      final completer = Completer<bool>();
      final events = <AiResponseEvent>[];

      var cancelCalls = 0;

      final pipeline = LegacyCallbackAiResponsePipeline(
        cancelLegacy: () {
          cancelCalls++;
        },
        runner: (
          request, {
          required onChunk,
          required onDone,
          required onError,
        }) {
          return completer.future;
        },
      );

      final subscription = pipeline.execute(buildRequest()).listen(
            events.add,
          );

      await Future<void>.delayed(Duration.zero);

      expect(
        events.whereType<AiResponseStarted>(),
        hasLength(1),
      );

      await subscription.cancel();
      await subscription.cancel();

      expect(cancelCalls, 1);

      completer.complete(true);

      await Future<void>.delayed(Duration.zero);

      expect(
        events.whereType<AiResponseTerminal>(),
        isEmpty,
      );
    });
  });
}
