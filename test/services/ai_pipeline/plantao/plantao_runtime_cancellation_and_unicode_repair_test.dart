import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/ai_legacy_callback_pipeline.dart';
import 'package:medcases/services/ai_pipeline/ai_request_contract.dart';
import 'package:medcases/services/ai_pipeline/ai_response_event.dart';
import 'package:medcases/services/ai_pipeline/ai_response_pipeline.dart';
import 'package:medcases/services/ai_pipeline/ai_response_result.dart';
import 'package:medcases/services/ai_pipeline/plantao/plantao_buffered_cutover_controller.dart';

AiRequestContract _request() {
  return AiRequestContract(
    requestId: 'request-r8',
    sessionId: 'session-r8',
    input: 'Avaliar cancelamento.',
    mode: AiRequestMode.plantao,
    locale: AiRequestLocale.pt,
    sourceSurface: AiSourceSurface.aiScreen,
  );
}

String _between(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'Missing start token: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: 'Missing end token: $end');
  return source.substring(startIndex, endIndex);
}

final class _Pipeline implements AiResponsePipeline {
  final Stream<AiResponseEvent> Function(AiRequestContract request) runner;

  const _Pipeline(this.runner);

  @override
  Stream<AiResponseEvent> execute(AiRequestContract request) {
    return runner(request);
  }
}

void main() {
  group('Phase3K-C5A-R8 runtime cancellation and Unicode repair', () {
    test('external provider cancellation closes the typed bridge once',
        () async {
      final runnerCompleter = Completer<bool>();
      final streamDone = Completer<void>();
      final events = <AiResponseEvent>[];
      late AiLegacyErrorCallback emitError;

      final pipeline = LegacyCallbackAiResponsePipeline(
        runner: (
          request, {
          required onChunk,
          required onDone,
          required onError,
        }) {
          emitError = onError;
          return runnerCompleter.future;
        },
      );

      pipeline.execute(_request()).listen(
        events.add,
        onDone: () => streamDone.complete(),
      );

      await Future<void>.delayed(Duration.zero);
      emitError('PIPELINE_STREAM_CANCELLED');
      await streamDone.future.timeout(const Duration(seconds: 1));

      runnerCompleter.complete(true);
      await Future<void>.delayed(Duration.zero);

      final terminals = events.whereType<AiResponseTerminal>().toList();
      expect(events.whereType<AiResponseStarted>(), hasLength(1));
      expect(terminals, hasLength(1));
      expect(
        terminals.single.result.terminalCause,
        AiTerminalCause.cancelled,
      );
      expect(terminals.single.result.requestId, 'request-r8');
      expect(terminals.single.result.sessionId, 'session-r8');
    });

    test('cancelled terminal after start never permits legacy fallback',
        () async {
      final controller = PlantaoBufferedCutoverController(
        enabled: true,
        pipeline: _Pipeline((request) async* {
          yield AiResponseStarted(
            requestId: request.requestId,
            sessionId: request.sessionId,
            provider: 'cancel-test',
          );
          yield AiResponseTerminal(
            requestId: request.requestId,
            sessionId: request.sessionId,
            result: AiResponseResult(
              requestId: request.requestId,
              sessionId: request.sessionId,
              finalText: '',
              displayText: '',
              provider: 'cancel-test',
              terminalCause: AiTerminalCause.cancelled,
              persistenceStatus: AiPersistenceStatus.notAttempted,
            ),
          );
        }),
      );

      final decision = await controller.execute(_request());

      expect(
        decision.disposition,
        PlantaoBufferedCutoverDisposition.rejectedAfterStart,
      );
      expect(decision.reason, 'terminal_invariant_rejected');
      expect(decision.eventCount, 2);
      expect(decision.terminalCount, 1);
      expect(decision.mayFallback, isFalse);
    });

    test('AppProvider cancellation invalidates request and releases owners',
        () {
      final source =
          File('lib/providers/app_provider.dart').readAsStringSync();
      final cancelBody = _between(
        source,
        'void cancelAiStream({bool notifyBufferedPipeline = true})',
        '/// Envia mensagem com streaming token-a-token',
      );

      expect(
        source,
        contains('String? _plantaoBufferedPipelineCancellationRequestId;'),
      );
      expect(
        source,
        contains('void Function()? _plantaoBufferedPipelineCancellation;'),
      );
      expect(
        cancelBody,
        contains("final cancelledRequestId = _activeRequestId.trim();"),
      );
      expect(cancelBody, contains("_activeRequestId = '';"));
      expect(
        cancelBody,
        contains('_completeAiRequestOnce(cancelledRequestId);'),
      );
      expect(
        cancelBody,
        contains('scheduleMicrotask(bufferedCancellation);'),
      );
      expect(
        cancelBody.indexOf("_activeRequestId = '';"),
        lessThan(cancelBody.indexOf('scheduleMicrotask(bufferedCancellation);')),
      );
    });

    test('buffered bridge owns one request-scoped cancellation callback', () {
      final source =
          File('lib/providers/app_provider.dart').readAsStringSync();
      final bridge = _between(
        source,
        'Future<bool> sendAiMessageForPipeline(',
        'Future<bool> _sendAiMessageLegacyCore(',
      );

      expect(
        bridge,
        contains(
          "bufferedOnError.call('PIPELINE_STREAM_CANCELLED');",
        ),
      );
      expect(
        bridge,
        contains('_plantaoBufferedPipelineCancellationRequestId ='),
      );
      expect(
        bridge,
        contains('_plantaoBufferedPipelineCancellation ='),
      );
      expect(bridge, contains('void clearCancellationOwner()'));
      expect(bridge, contains('final bufferedOnChunk = onChunk;'));
      expect(bridge, contains('final bufferedOnDone = onDone;'));
      expect(bridge, contains('final bufferedOnError = onError;'));
      expect(bridge, isNot(contains('onChunk(')));
      expect(bridge, isNot(contains('onDone(')));
      expect(bridge, isNot(contains('onError(')));
      expect(
        RegExp(r'_sendAiMessageLegacyCore\s*\(').allMatches(bridge).length,
        1,
      );
      expect(
        bridge,
        contains(
          "bufferedOnError.call('PIPELINE_CANCELLATION_OWNER_BUSY');",
        ),
      );
    });

    test('consumer-side stream cancellation does not notify back recursively',
        () {
      final source = File(
        'lib/services/ai_pipeline/app_provider_ai_response_pipeline.dart',
      ).readAsStringSync();

      expect(
        source,
        contains(
          'provider.cancelAiStream(notifyBufferedPipeline: false);',
        ),
      );
      expect(source, isNot(contains('provider.cancelAiStream();')));
    });

    test('busy eligible cutover fails closed before legacy core', () {
      final source =
          File('lib/providers/app_provider.dart').readAsStringSync();
      final selector = _between(
        source,
        'Future<bool> sendAiMessage(',
        '/// Internal bridge used only by the typed AI pipeline.',
      );
      final busyGuard = _between(
        selector,
        'if (phase3kBufferedCutoverBusy) {',
        'final phase3kShouldAttemptBufferedCutover',
      );

      expect(
        selector,
        contains(
          'PlantaoQaCutoverEvent.executionRejectedWhileActive',
        ),
      );
      expect(
        selector,
        contains('PlantaoQaCutoverReason.cutoverAlreadyActive'),
      );
      expect(
        busyGuard,
        contains("onError('PIPELINE_CUTOVER_ALREADY_ACTIVE');"),
      );
      expect(busyGuard, contains('return false;'));
      expect(busyGuard, isNot(contains('_sendAiMessageLegacyCore(')));
    });

    test('eligible correlation no longer depends on the active flag', () {
      final source =
          File('lib/providers/app_provider.dart').readAsStringSync();
      final correlation = _between(
        source,
        '// Phase3K-C5A-R8: resolve it even when another cutover is',
        '// Phase3K-C5A-R5: the same pair continues through pipeline or legacy.',
      );

      expect(correlation, contains('_resolveCanonicalAiCorrelation('));
      expect(
        correlation,
        isNot(contains('_plantaoBufferedCutoverExecutionActive')),
      );
    });

    test('QA observability keeps the busy rejection in closed enums', () {
      final source = File(
        'lib/services/ai_pipeline/plantao/'
        'plantao_qa_cutover_support.dart',
      ).readAsStringSync();

      expect(source, contains('executionRejectedWhileActive,'));
      expect(source, contains('cutoverAlreadyActive,'));
      expect(
        source,
        isNot(anyOf(
          contains('String message'),
          contains('String prompt'),
          contains('String response'),
        )),
      );
    });

    test('Plantao organizer preview is rune-safe and source-exact', () {
      final source =
          File('lib/services/plantao_pipeline.dart').readAsStringSync();

      expect(
        source,
        contains('final condutaPreview = String.fromCharCodes('),
      );
      expect(
        source,
        contains('response.conduta.runes.take(40),'),
      );
      expect(
        source,
        contains("'conduta=\"\$condutaPreview…\"'"),
      );
      expect(
        source,
        isNot(contains('response.conduta.substring(0, 40)')),
      );
    });

    test('legacy bridge maps only the closed cancellation code', () {
      final source = File(
        'lib/services/ai_pipeline/ai_legacy_callback_pipeline.dart',
      ).readAsStringSync();

      expect(
        source,
        contains("error.trim() == 'PIPELINE_STREAM_CANCELLED'"),
      );
      expect(
        source,
        contains("source: 'legacy_external_cancel'"),
      );
      expect(
        RegExp(r'PIPELINE_STREAM_CANCELLED').allMatches(source).length,
        1,
      );
    });
  });
}
