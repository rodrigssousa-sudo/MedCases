import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/ai_request_contract.dart';
import 'package:medcases/services/ai_pipeline/ai_response_event.dart';
import 'package:medcases/services/ai_pipeline/ai_response_pipeline.dart';
import 'package:medcases/services/ai_pipeline/ai_response_result.dart';
import 'package:medcases/services/ai_pipeline/plantao/plantao_buffered_cutover_controller.dart';

final class _FakePipeline implements AiResponsePipeline {
  final Stream<AiResponseEvent> Function(
    AiRequestContract request,
  ) runner;

  const _FakePipeline(this.runner);

  @override
  Stream<AiResponseEvent> execute(
    AiRequestContract request,
  ) {
    return runner(request);
  }
}

AiRequestContract _request() {
  return AiRequestContract(
    requestId: 'request-phase3k',
    sessionId: 'session-phase3k',
    input: 'Conduta imediata.',
    mode: AiRequestMode.plantao,
    locale: AiRequestLocale.pt,
    sourceSurface: AiSourceSurface.other,
  );
}

AiResponseResult _result({
  String requestId = 'request-phase3k',
  String sessionId = 'session-phase3k',
  String finalText = 'Conduta final.',
  String displayText = 'Conduta final.',
  AiTerminalCause terminalCause = AiTerminalCause.completed,
  bool isPartial = false,
}) {
  return AiResponseResult(
    requestId: requestId,
    sessionId: sessionId,
    finalText: finalText,
    displayText: displayText,
    provider: 'fake',
    terminalCause: terminalCause,
    isPartial: isPartial,
    persistenceStatus: AiPersistenceStatus.notAttempted,
  );
}

void main() {
  group('PlantaoBufferedCutoverController', () {
    test('feature flag fechada não assina o pipeline', () async {
      var calls = 0;
      final controller = PlantaoBufferedCutoverController(
        enabled: false,
        pipeline: _FakePipeline((request) {
          calls++;
          return const Stream<AiResponseEvent>.empty();
        }),
      );

      final decision = await controller.execute(_request());

      expect(
        decision.disposition,
        PlantaoBufferedCutoverDisposition.bypassed,
      );
      expect(calls, 0);
      expect(decision.result, isNull);
    });

    test('terminal tipado válido é o único commit', () async {
      final controller = PlantaoBufferedCutoverController(
        enabled: true,
        pipeline: _FakePipeline((request) async* {
          yield AiResponseStarted(
            requestId: request.requestId,
            sessionId: request.sessionId,
            provider: 'fake',
          );
          yield AiResponseDelta(
            requestId: request.requestId,
            sessionId: request.sessionId,
            delta: 'Conduta final.',
            accumulatedText: 'Conduta final.',
            provider: 'fake',
          );
          yield AiResponseTerminal(
            requestId: request.requestId,
            sessionId: request.sessionId,
            result: _result(),
          );
        }),
      );

      final decision = await controller.execute(_request());

      expect(
        decision.disposition,
        PlantaoBufferedCutoverDisposition.committed,
      );
      expect(decision.shouldCommit, isTrue);
      expect(decision.mayFallback, isFalse);
      expect(decision.terminalCount, 1);
      expect(decision.result?.finalText, 'Conduta final.');
      expect(
        decision.result?.displayText,
        decision.result?.finalText,
      );
    });

    test('falha antes do primeiro evento permite fallback legado',
        () async {
      final controller = PlantaoBufferedCutoverController(
        enabled: true,
        pipeline: _FakePipeline(
          (request) => Stream<AiResponseEvent>.error(
            StateError('preflight failure'),
          ),
        ),
      );

      final decision = await controller.execute(_request());

      expect(
        decision.disposition,
        PlantaoBufferedCutoverDisposition.fallbackAllowed,
      );
      expect(decision.mayFallback, isTrue);
      expect(decision.eventCount, 0);
    });

    test('resultado inválido depois do início bloqueia reexecução',
        () async {
      final controller = PlantaoBufferedCutoverController(
        enabled: true,
        pipeline: _FakePipeline((request) async* {
          yield AiResponseStarted(
            requestId: request.requestId,
            sessionId: request.sessionId,
            provider: 'fake',
          );
          yield AiResponseTerminal(
            requestId: request.requestId,
            sessionId: request.sessionId,
            result: _result(
              displayText: 'Texto divergente.',
            ),
          );
        }),
      );

      final decision = await controller.execute(_request());

      expect(
        decision.disposition,
        PlantaoBufferedCutoverDisposition.rejectedAfterStart,
      );
      expect(decision.mayFallback, isFalse);
      expect(decision.result, isNull);
    });

    test('evento tardio após terminal é rejeitado', () async {
      final controller = PlantaoBufferedCutoverController(
        enabled: true,
        pipeline: _FakePipeline((request) async* {
          yield AiResponseTerminal(
            requestId: request.requestId,
            sessionId: request.sessionId,
            result: _result(),
          );
          yield AiResponseDelta(
            requestId: request.requestId,
            sessionId: request.sessionId,
            delta: 'tardio',
            accumulatedText: 'Conduta final.tardio',
            provider: 'fake',
          );
        }),
      );

      final decision = await controller.execute(_request());

      expect(
        decision.disposition,
        PlantaoBufferedCutoverDisposition.rejectedAfterStart,
      );
      expect(decision.reason, 'event_after_terminal');
      expect(decision.mayFallback, isFalse);
    });

    test('AppProvider não descarta mais o output do facade', () {
      final source = File(
        'lib/providers/app_provider.dart',
      ).readAsStringSync();

      expect(
        source,
        contains(
          'const PlantaoBufferedCutoverController.disabled()',
        ),
      );
      expect(
        source,
        contains(
          'phase3kActiveCutoverController.execute(',
        ),
      );
      expect(
        source,
        isNot(contains('PlantaoResponsePipeline()')),
      );
      expect(
        source,
        isNot(contains('.drain<void>()')),
      );
      expect(
        source,
        contains(
          'PlantaoBufferedCutoverDisposition.committed',
        ),
      );
      expect(
        source,
        contains(
          'PlantaoBufferedCutoverDisposition.fallbackAllowed',
        ),
      );
      expect(
        source,
        contains(
          'PlantaoBufferedCutoverDisposition.rejectedAfterStart',
        ),
      );
    });
  });
}
