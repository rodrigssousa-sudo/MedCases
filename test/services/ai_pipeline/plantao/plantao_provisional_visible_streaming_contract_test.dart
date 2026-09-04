import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/ai_request_contract.dart';
import 'package:medcases/services/ai_pipeline/ai_response_event.dart';
import 'package:medcases/services/ai_pipeline/ai_response_pipeline.dart';
import 'package:medcases/services/ai_pipeline/ai_response_result.dart';
import 'package:medcases/services/ai_pipeline/plantao/plantao_buffered_cutover_controller.dart';

final class _Pipeline implements AiResponsePipeline {
  final Stream<AiResponseEvent> Function(AiRequestContract request) runner;

  const _Pipeline(this.runner);

  @override
  Stream<AiResponseEvent> execute(AiRequestContract request) {
    return runner(request);
  }
}

AiRequestContract _request() {
  return AiRequestContract(
    requestId: 'request-r12',
    sessionId: 'session-r12',
    input: 'Avaliar streaming provisório.',
    mode: AiRequestMode.plantao,
    locale: AiRequestLocale.pt,
    sourceSurface: AiSourceSurface.aiScreen,
  );
}

AiResponseResult _result() {
  return AiResponseResult(
    requestId: 'request-r12',
    sessionId: 'session-r12',
    finalText: 'Conduta final.',
    displayText: 'Conduta final.',
    provider: 'fake',
    terminalCause: AiTerminalCause.completed,
    persistenceStatus: AiPersistenceStatus.notAttempted,
  );
}

void main() {
  group('Phase3K-C5A-R12 provisional visible streaming', () {
    test('controller projects multiple accumulated snapshots before terminal',
        () async {
      final provisional = <String>[];

      final controller = PlantaoBufferedCutoverController(
        enabled: true,
        pipeline: _Pipeline((request) async* {
          yield AiResponseStarted(
            requestId: request.requestId,
            sessionId: request.sessionId,
            provider: 'fake',
          );
          yield AiResponseDelta(
            requestId: request.requestId,
            sessionId: request.sessionId,
            delta: 'Con',
            accumulatedText: 'Con',
            provider: 'fake',
          );
          yield AiResponseDelta(
            requestId: request.requestId,
            sessionId: request.sessionId,
            delta: 'du',
            accumulatedText: 'Condu',
            provider: 'fake',
          );
          yield AiResponseDelta(
            requestId: request.requestId,
            sessionId: request.sessionId,
            delta: 'ta',
            accumulatedText: 'Conduta',
            provider: 'fake',
          );
          yield AiResponseTerminal(
            requestId: request.requestId,
            sessionId: request.sessionId,
            result: _result(),
          );
        }),
      );

      final decision = await controller.execute(
        _request(),
        onProvisionalText: provisional.add,
      );

      expect(
        decision.disposition,
        PlantaoBufferedCutoverDisposition.committed,
      );
      expect(provisional, <String>['Con', 'Condu', 'Conduta']);
      expect(decision.result?.finalText, 'Conduta final.');
    });

    test('provisional observer failure cannot change terminal ownership',
        () async {
      final controller = PlantaoBufferedCutoverController(
        enabled: true,
        pipeline: _Pipeline((request) async* {
          yield AiResponseStarted(
            requestId: request.requestId,
            sessionId: request.sessionId,
            provider: 'fake',
          );
          yield AiResponseDelta(
            requestId: request.requestId,
            sessionId: request.sessionId,
            delta: 'Con',
            accumulatedText: 'Con',
            provider: 'fake',
          );
          yield AiResponseTerminal(
            requestId: request.requestId,
            sessionId: request.sessionId,
            result: _result(),
          );
        }),
      );

      final decision = await controller.execute(
        _request(),
        onProvisionalText: (_) {
          throw StateError('visual consumer failed');
        },
      );

      expect(
        decision.disposition,
        PlantaoBufferedCutoverDisposition.committed,
      );
      expect(decision.terminalCount, 1);
      expect(decision.result?.finalText, 'Conduta final.');
    });

    test('AppProvider bridges provisional text with active request guard', () {
      final source =
          File('lib/providers/app_provider.dart').readAsStringSync();

      expect(
        source,
        contains('onProvisionalText: (provisionalText) {'),
      );
      expect(
        source,
        contains(
          'if (!_plantaoBufferedCutoverExecutionActive) return;',
        ),
      );
      expect(
        source,
        contains(
          'if (_activeRequestId != phase3kRequest.requestId) return;',
        ),
      );

      final provisionalIndex = source.indexOf(
        'onProvisionalText: (provisionalText) {',
      );
      final switchIndex = source.indexOf(
        'switch (phase3kDecision.disposition)',
        provisionalIndex,
      );
      final finalReconciliationIndex = source.indexOf(
        'onChunk(phase3kResult.displayText);',
        switchIndex,
      );
      final doneIndex = source.indexOf(
        'onDone(phase3kResult.finalText);',
        finalReconciliationIndex,
      );

      expect(provisionalIndex, isNonNegative);
      expect(switchIndex, greaterThan(provisionalIndex));
      expect(finalReconciliationIndex, greaterThan(switchIndex));
      expect(doneIndex, greaterThan(finalReconciliationIndex));
    });

    test('AiScreen uses one provisional slot without direct persistence', () {
      final source =
          File('lib/screens/ai_screen.dart').readAsStringSync();

      final start = source.indexOf(
        'onChunk: (accumulated) {',
      );
      final end = source.indexOf(
        'onDone: (finalText) {',
        start,
      );

      expect(start, isNonNegative);
      expect(end, greaterThan(start));

      final block = source.substring(start, end);

      expect(
        block,
        contains('_streamingTextNotifier?.value = visibleStreamingChunk;'),
      );
      expect(
        block,
        contains(
          "_messages.add(_ChatMsg(role: 'ai', text: cleanedChunk));",
        ),
      );
      expect(
        block,
        contains('_messages[streamingMsgIdx] = _ChatMsg.withId('),
      );
      expect(
        block,
        contains('streamingMsgIdx = _messages.length - 1;'),
      );

      const forbidden = <String>[
        '_saveAiSession',
        '_saveCurrentSessionToHistory',
        'persistAiExchangeOnce',
        'batchWriteAiExchange',
        'Firestore',
        'SESSION_PERSIST',
      ];

      for (final token in forbidden) {
        expect(block, isNot(contains(token)), reason: token);
      }
    });

    test('AiScreen owns a bounded terminalization gap indicator', () {
      final source =
          File('lib/screens/ai_screen.dart').readAsStringSync();

      expect(source, contains('Timer? terminalGapIndicatorTimer;'));
      expect(
        source,
        contains('const Duration(milliseconds: 450)'),
      );
      expect(
        source,
        contains(
          '[GUARDIA_TERMINAL_GAP] stage=indicator_on ',
        ),
      );
      expect(
        source,
        contains(
          '[GUARDIA_TERMINAL_GAP] stage=indicator_off ',
        ),
      );
      expect(
        source,
        contains("clearTerminalGapIndicator(reason: 'next_chunk');"),
      );
      expect(source, contains('armTerminalGapIndicator();'));
    });

    test('terminalization indicator is closed by done and error', () {
      final source =
          File('lib/screens/ai_screen.dart').readAsStringSync();

      final done = source.indexOf('onDone: (finalText) {');
      final error = source.indexOf('onError: (errorMsg) {', done);

      expect(done, isNonNegative);
      expect(error, greaterThan(done));

      final doneBlock = source.substring(done, error);
      expect(
        doneBlock,
        contains("reason: 'done'"),
      );
      expect(
        doneBlock,
        contains('rebuild: false'),
      );

      final errorTail = source.substring(error);
      expect(
        errorTail,
        contains("reason: 'error'"),
      );
    });

    test('HARD STOP remains hidden while streaming', () {
      final source = File(
        'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('if (!isStreaming || rawText.isEmpty) return rawText;'),
      );
      expect(
        source,
        contains(
          'return rawText.substring(0, boundary.start).trimRight();',
        ),
      );
      expect(source, contains("'Red flags/escalamiento'"));
      expect(source, contains("'Red flags/escalonamento'"));
    });
  });
}
