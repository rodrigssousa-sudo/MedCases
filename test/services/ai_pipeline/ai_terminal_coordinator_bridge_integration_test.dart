import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/ai_pipeline_contracts.dart';

AiRequestContract buildRequest() {
  return AiRequestContract(
    requestId: 'request-bridge-coordinator',
    sessionId: 'session-bridge-coordinator',
    input: 'Avaliar paciente.',
    mode: AiRequestMode.plantao,
    locale: AiRequestLocale.pt,
    sourceSurface: AiSourceSurface.aiScreen,
  );
}

void main() {
  group(
    'LegacyCallbackAiResponsePipeline + AiTerminalCoordinator',
    () {
      test(
        'structured callback vence no coordenador',
        () async {
          late AiTerminalCoordinator coordinator;

          final structured = <String, Object?>{
            'diagnostico': 'Pneumonia',
          };

          final pipeline = LegacyCallbackAiResponsePipeline(
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
            }) async {
              onDone('Resposta estruturada.');
              onDone(
                'Resposta estruturada.',
                structured,
              );
              return true;
            },
          );

          final events = await pipeline.execute(buildRequest()).toList();

          expect(coordinator.isCompleted, isTrue);
          expect(
            coordinator.acceptedSource,
            'legacy_structured_done',
          );
          expect(
            coordinator.result?.structuredOutput,
            same(structured),
          );
          expect(
            events.whereType<AiResponseTerminal>(),
            hasLength(1),
          );
        },
      );

      test(
        'erro é registrado com origem única',
        () async {
          late AiTerminalCoordinator coordinator;

          final pipeline = LegacyCallbackAiResponsePipeline(
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
            }) async {
              onChunk('Resposta parcial.');
              onError('stream_error');
              onDone('Sucesso tardio.');
              return true;
            },
          );

          final events = await pipeline.execute(buildRequest()).toList();

          expect(
            coordinator.acceptedSource,
            'legacy_error',
          );
          expect(
            coordinator.result?.terminalCause,
            AiTerminalCause.error,
          );
          expect(
            coordinator.result?.isPartial,
            isTrue,
          );
          expect(
            coordinator.result?.finalText,
            'Resposta parcial.',
          );
          expect(
            events.whereType<AiResponseTerminal>(),
            hasLength(1),
          );
        },
      );

      test(
        'rejeição sem callback é coordenada',
        () async {
          late AiTerminalCoordinator coordinator;

          final pipeline = LegacyCallbackAiResponsePipeline(
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
            }) async {
              return false;
            },
          );

          final events = await pipeline.execute(buildRequest()).toList();

          expect(
            coordinator.acceptedSource,
            'legacy_rejected',
          );
          expect(
            coordinator.result?.errorCode,
            'legacy_send_rejected',
          );
          expect(
            events.whereType<AiResponseTerminal>(),
            hasLength(1),
          );
        },
      );

      test(
        'cancelamento vence e bloqueia terminal tardio',
        () async {
          late AiTerminalCoordinator coordinator;

          final runnerCompleter = Completer<bool>();
          late AiLegacyDoneCallback capturedOnDone;

          var cancelCalls = 0;
          final events = <AiResponseEvent>[];

          final pipeline = LegacyCallbackAiResponsePipeline(
            cancelLegacy: () {
              cancelCalls++;
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
              capturedOnDone = onDone;
              onChunk('Parcial.');
              return runnerCompleter.future;
            },
          );

          final subscription =
              pipeline.execute(buildRequest()).listen(events.add);

          await Future<void>.delayed(Duration.zero);

          await subscription.cancel();
          await subscription.cancel();

          expect(cancelCalls, 1);
          expect(coordinator.isCompleted, isTrue);
          expect(
            coordinator.acceptedSource,
            'consumer_cancel',
          );
          expect(
            coordinator.result?.terminalCause,
            AiTerminalCause.cancelled,
          );
          expect(
            coordinator.result?.isPartial,
            isTrue,
          );

          capturedOnDone('Sucesso tardio.');
          runnerCompleter.complete(true);

          await Future<void>.delayed(Duration.zero);

          expect(
            coordinator.result?.terminalCause,
            AiTerminalCause.cancelled,
          );
          expect(
            events.whereType<AiResponseTerminal>(),
            isEmpty,
          );
        },
      );

      test(
        'done textual simples mantém origem legacy_done',
        () async {
          late AiTerminalCoordinator coordinator;

          final pipeline = LegacyCallbackAiResponsePipeline(
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
            }) async {
              onDone('Resposta final.');
              return true;
            },
          );

          final events = await pipeline.execute(buildRequest()).toList();

          expect(
            coordinator.acceptedSource,
            'legacy_done',
          );
          expect(
            coordinator.result?.terminalCause,
            AiTerminalCause.completed,
          );
          expect(
            events.whereType<AiResponseTerminal>(),
            hasLength(1),
          );
        },
      );
    },
  );
}
