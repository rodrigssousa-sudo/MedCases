import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/ai_pipeline_contracts.dart';

AiRequestContract buildRequest() {
  return AiRequestContract(
    requestId: 'request-accumulator-bridge',
    sessionId: 'session-accumulator-bridge',
    input: 'Avaliar paciente.',
    mode: AiRequestMode.plantao,
    locale: AiRequestLocale.pt,
    sourceSurface: AiSourceSurface.aiScreen,
  );
}

void main() {
  group(
    'LegacyCallbackAiResponsePipeline + AiResponseAccumulator',
    () {
      test(
        'ponte delega snapshots crescentes ao acumulador',
        () async {
          late AiResponseAccumulator accumulator;

          final pipeline = LegacyCallbackAiResponsePipeline(
            accumulatorFactory: (
              request,
              expectedAttempt,
            ) {
              accumulator = AiResponseAccumulator(
                expectedAttempt: expectedAttempt,
              );

              return accumulator;
            },
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

          final deltas = events.whereType<AiResponseDelta>().toList();

          expect(deltas, hasLength(2));
          expect(deltas.first.delta, 'Con');
          expect(deltas.last.delta, 'duta');
          expect(accumulator.text, 'Conduta');
          expect(
            accumulator.acceptedUpdateCount,
            2,
          );
          expect(accumulator.isSealed, isTrue);
        },
      );

      test(
        'duplicata é suprimida e substituição é sinalizada',
        () async {
          late AiResponseAccumulator accumulator;

          final pipeline = LegacyCallbackAiResponsePipeline(
            accumulatorFactory: (
              request,
              expectedAttempt,
            ) {
              accumulator = AiResponseAccumulator(
                expectedAttempt: expectedAttempt,
              );

              return accumulator;
            },
            runner: (
              request, {
              required onChunk,
              required onDone,
              required onError,
            }) async {
              onChunk('Resposta inicial');
              onChunk('Resposta inicial');
              onChunk('Resposta substituta');
              onDone('Resposta substituta');
              return true;
            },
          );

          final events = await pipeline.execute(buildRequest()).toList();

          final deltas = events.whereType<AiResponseDelta>().toList();

          expect(deltas, hasLength(2));

          expect(
            deltas.first.replacesAccumulatedText,
            isFalse,
          );

          expect(
            deltas.last.replacesAccumulatedText,
            isTrue,
          );

          expect(
            deltas.last.delta,
            'Resposta substituta',
          );

          expect(
            accumulator.acceptedUpdateCount,
            2,
          );

          expect(
            accumulator.text,
            'Resposta substituta',
          );
        },
      );

      test(
        'erro terminal usa o snapshot canônico parcial',
        () async {
          late AiResponseAccumulator accumulator;

          final pipeline = LegacyCallbackAiResponsePipeline(
            accumulatorFactory: (
              request,
              expectedAttempt,
            ) {
              accumulator = AiResponseAccumulator(
                expectedAttempt: expectedAttempt,
              );

              return accumulator;
            },
            runner: (
              request, {
              required onChunk,
              required onDone,
              required onError,
            }) async {
              onChunk('Resposta');
              onChunk('Resposta parcial.');
              onError('stream_error');
              return false;
            },
          );

          final events = await pipeline.execute(buildRequest()).toList();

          final terminal = events.last as AiResponseTerminal;

          expect(
            terminal.result.finalText,
            'Resposta parcial.',
          );

          expect(terminal.result.isPartial, isTrue);
          expect(accumulator.isSealed, isTrue);
        },
      );

      test(
        'callback tardio não altera acumulador selado',
        () async {
          late AiResponseAccumulator accumulator;
          late AiLegacyChunkCallback capturedOnChunk;

          final pipeline = LegacyCallbackAiResponsePipeline(
            accumulatorFactory: (
              request,
              expectedAttempt,
            ) {
              accumulator = AiResponseAccumulator(
                expectedAttempt: expectedAttempt,
              );

              return accumulator;
            },
            runner: (
              request, {
              required onChunk,
              required onDone,
              required onError,
            }) async {
              capturedOnChunk = onChunk;

              onChunk('Resposta final.');
              onDone('Resposta final.');

              return true;
            },
          );

          final events = await pipeline.execute(buildRequest()).toList();

          final deltaCountBefore = events.whereType<AiResponseDelta>().length;

          expect(accumulator.isSealed, isTrue);

          capturedOnChunk(
            'Resposta final. Conteúdo tardio.',
          );

          expect(
            accumulator.text,
            'Resposta final.',
          );

          expect(
            accumulator.acceptedUpdateCount,
            1,
          );

          expect(
            events.whereType<AiResponseDelta>().length,
            deltaCountBefore,
          );
        },
      );

      test(
        'cancelamento sela acumulador e preserva parcial',
        () async {
          late AiResponseAccumulator accumulator;
          late AiTerminalCoordinator coordinator;

          final completer = Completer<bool>();
          var cancelCalls = 0;

          final pipeline = LegacyCallbackAiResponsePipeline(
            cancelLegacy: () {
              cancelCalls++;
            },
            accumulatorFactory: (
              request,
              expectedAttempt,
            ) {
              accumulator = AiResponseAccumulator(
                expectedAttempt: expectedAttempt,
              );

              return accumulator;
            },
            coordinatorFactory: (request) {
              coordinator = AiTerminalCoordinator(
                requestId: request.requestId,
                sessionId: request.sessionId,
              );

              return coordinator;
            },
            runner: (
              request, {
              required onChunk,
              required onDone,
              required onError,
            }) {
              onChunk('Resposta parcial.');
              return completer.future;
            },
          );

          final subscription = pipeline.execute(buildRequest()).listen(
                (_) {},
              );

          await Future<void>.delayed(Duration.zero);

          await subscription.cancel();

          expect(cancelCalls, 1);
          expect(accumulator.isSealed, isTrue);
          expect(
            accumulator.text,
            'Resposta parcial.',
          );

          expect(
            coordinator.result?.terminalCause,
            AiTerminalCause.cancelled,
          );

          expect(
            coordinator.result?.isPartial,
            isTrue,
          );

          completer.complete(true);

          await Future<void>.delayed(Duration.zero);

          expect(
            coordinator.result?.terminalCause,
            AiTerminalCause.cancelled,
          );
        },
      );
    },
  );
}
