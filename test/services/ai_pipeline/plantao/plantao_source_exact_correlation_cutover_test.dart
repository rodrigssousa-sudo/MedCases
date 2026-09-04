import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _between(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  expect(startIndex, isNonNegative, reason: 'Missing start token: $start');
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(endIndex, isNonNegative, reason: 'Missing end token: $end');
  return source.substring(startIndex, endIndex);
}

int _count(String source, String token) => token.allMatches(source).length;

void main() {
  late String appProviderSource;
  late String publicSelector;
  late String canonicalResolver;

  setUpAll(() {
    appProviderSource =
        File('lib/providers/app_provider.dart').readAsStringSync();
    canonicalResolver = _between(
      appProviderSource,
      '({String requestId, String sessionId}) '
          '_resolveCanonicalAiCorrelation({',
      'Future<bool> sendAiMessage(',
    );
    publicSelector = _between(
      appProviderSource,
      'Future<bool> sendAiMessage(',
      '/// Internal bridge used only by the typed AI pipeline.',
    );
  });

  group('Phase3K-C5A-R5 source-exact correlation', () {
    test('canonical resolver exists before the public selector', () {
      final resolverIndex =
          appProviderSource.indexOf('_resolveCanonicalAiCorrelation({');
      final selectorIndex = appProviderSource.indexOf('Future<bool> sendAiMessage(');

      expect(resolverIndex, isNonNegative);
      expect(selectorIndex, greaterThan(resolverIndex));
      expect(
        canonicalResolver,
        contains('ProviderRouterService.generateRequestId().trim()'),
      );
      expect(
        canonicalResolver,
        contains("'session_\${DateTime.now().millisecondsSinceEpoch}'"),
      );
      expect(
        canonicalResolver,
        isNot(anyOf(
          contains('_currentConversationSessionId ='),
          contains('onChunk('),
          contains('onDone('),
          contains('onError('),
          contains('persistAiExchangeOnce('),
          contains('batchWriteAiExchange('),
          contains('execute('),
        )),
      );
    });

    test('eligible Plantao resolves both ids before observability and gate', () {
      final resolutionIndex = publicSelector.indexOf(
        'phase3kResolvedSessionId = phase3kCorrelation.sessionId;',
      );
      final eligibilityIndex = publicSelector.indexOf(
        'event: phase3kQaEligible',
      );
      final gateIndex = publicSelector.indexOf(
        'final phase3kShouldAttemptBufferedCutover',
      );

      expect(resolutionIndex, isNonNegative);
      expect(eligibilityIndex, greaterThan(resolutionIndex));
      expect(gateIndex, greaterThan(eligibilityIndex));
      expect(
        publicSelector,
        contains('phase3kResolvedRequestId = phase3kCorrelation.requestId;'),
      );
      expect(
        publicSelector,
        contains('phase3kResolvedSessionId = phase3kCorrelation.sessionId;'),
      );
    });

    test('pipeline contract and legacy core receive the identical pair', () {
      expect(
        publicSelector,
        contains('requestId: phase3kResolvedRequestId,'),
      );
      expect(
        publicSelector,
        contains('sessionId: phase3kResolvedSessionId,'),
      );
      expect(
        publicSelector,
        contains('pipelineRequestId: phase3kResolvedRequestId,'),
      );
      expect(
        publicSelector,
        contains('pipelineSessionId: phase3kResolvedSessionId,'),
      );
      expect(
        appProviderSource,
        contains('sessionId: phase3kLegacyCorrelation.sessionId,'),
      );
      expect(
        appProviderSource,
        contains('requestId: phase3kLegacyCorrelation.requestId,'),
      );
    });

    test('there is one session creation owner and no old inline owner', () {
      expect(
        _count(appProviderSource, '_resolveCanonicalAiCorrelation('),
        4,
      );
      expect(
        _count(
          appProviderSource,
          "'session_\${DateTime.now().millisecondsSinceEpoch}'",
        ),
        1,
      );
      expect(
        _count(
          appProviderSource,
          '_currentConversationSessionId = '
              'phase3kLegacyCorrelation.sessionId;',
        ),
        1,
      );
      expect(
        appProviderSource,
        isNot(contains(
          'final normalizedPipelineSessionId = pipelineSessionId?.trim();',
        )),
      );
    });

    test('Study isolation remains before the Plantao pipeline', () {
      final studyModeIndex = publicSelector.indexOf(
        'final phase3kQaIsPlantao = !longResponse;',
      );
      final studyReasonIndex = publicSelector.indexOf(
        'PlantaoQaCutoverReason.notPlantaoMode',
      );
      final pipelineStartIndex = publicSelector.indexOf(
        'PlantaoQaCutoverEvent.pipelineStarted',
      );

      expect(studyModeIndex, isNonNegative);
      expect(studyReasonIndex, greaterThan(studyModeIndex));
      expect(pipelineStartIndex, greaterThan(studyReasonIndex));
      expect(publicSelector, contains('!longResponse &&'));
      expect(publicSelector, contains('phase3kResolvedRequestId != null'));
    });

    test('fallback is allowed only before an external pipeline event', () {
      final rejectedIndex = publicSelector.indexOf(
        'case PlantaoBufferedCutoverDisposition.rejectedAfterStart:',
      );
      final rejectedReturnIndex = publicSelector.indexOf(
        "onError('PIPELINE_RESULT_REJECTED_AFTER_START');",
        rejectedIndex,
      );
      final fallbackIndex = publicSelector.indexOf(
        'case PlantaoBufferedCutoverDisposition.fallbackAllowed:',
      );
      final legacyCallIndex = publicSelector.indexOf(
        'return _sendAiMessageLegacyCore(',
      );

      expect(rejectedIndex, isNonNegative);
      expect(rejectedReturnIndex, greaterThan(rejectedIndex));
      expect(fallbackIndex, greaterThan(rejectedReturnIndex));
      expect(legacyCallIndex, greaterThan(fallbackIndex));
      expect(
        publicSelector.substring(rejectedIndex, fallbackIndex),
        contains('return false;'),
      );
    });

    test('controller and committed terminal remain single in selector', () {
      expect(
        _count(
          publicSelector,
          'phase3kActiveCutoverController.execute(',
        ),
        1,
      );
      expect(
        _count(
          publicSelector,
          'event: PlantaoQaCutoverEvent.pipelineStarted',
        ),
        1,
      );
      expect(
        _count(
          publicSelector,
          'event: PlantaoQaCutoverEvent.commitValidated',
        ),
        1,
      );
      expect(
        _count(
          publicSelector,
          'event: PlantaoQaCutoverEvent.terminalCompleted',
        ),
        1,
      );
      expect(
        _count(publicSelector, 'onChunk(phase3kResult.displayText);'),
        1,
      );
    });

    test('QA observability does not receive clinical text fields', () {
      var searchFrom = 0;
      var emitCount = 0;
      while (true) {
        final start = publicSelector.indexOf(
          '_plantaoQaCutoverSupport.emit(',
          searchFrom,
        );
        if (start < 0) break;
        final end = publicSelector.indexOf(');', start);
        expect(end, greaterThan(start));
        final emitBlock = publicSelector.substring(start, end + 2);
        expect(
          emitBlock,
          isNot(anyOf(
            contains('input:'),
            contains('question:'),
            contains('finalText:'),
            contains('displayText:'),
            contains('assistantOutput:'),
          )),
        );
        emitCount += 1;
        searchFrom = end + 2;
      }
      expect(emitCount, greaterThanOrEqualTo(1));
    });

    test('persistence retains request idempotency and canonical paths', () {
      expect(
        appProviderSource,
        contains('if (_persistedExchangeIds.contains(context.requestId))'),
      );
      expect(
        appProviderSource,
        contains('_persistedExchangeIds.add(context.requestId);'),
      );
      expect(
        appProviderSource,
        contains("'users/\${context.uid}/ai_sessions/\${context.sessionId}'"),
      );
      expect(
        appProviderSource,
        contains("'\$parentPath/exchanges/\${context.requestId}'"),
      );
    });
  });
}
