import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase3K-C5A-R5 canonical pair precedes every cutover consumer', () {
    final source = File(
      'lib/providers/app_provider.dart',
    ).readAsStringSync();

    final selector = source.indexOf('Future<bool> sendAiMessage(');
    final marker = source.indexOf(
      'Phase3K-C5A-R5: resolve the canonical pair before cutover.',
      selector,
    );
    final downstream = source.indexOf(
      'Phase3K-C5A-R5: the same pair continues through pipeline or legacy.',
      marker,
    );
    final eligibility = source.indexOf(
      'PlantaoQaCutoverEvent.eligibilityAccepted',
      downstream,
    );
    final gate = source.indexOf(
      'phase3kShouldAttemptBufferedCutover',
      eligibility,
    );
    final request = source.indexOf(
      'AiRequestContract(',
      gate,
    );
    final controller = source.indexOf(
      'phase3kActiveCutoverController.execute(',
      request,
    );

    expect(selector, greaterThanOrEqualTo(0));
    expect(marker, greaterThan(selector));
    expect(downstream, greaterThan(marker));
    expect(eligibility, greaterThan(downstream));
    expect(gate, greaterThan(eligibility));
    expect(request, greaterThan(gate));
    expect(controller, greaterThan(request));

    final bridge = source.indexOf(
      '/// Internal bridge used only by the typed AI pipeline.',
      downstream,
    );
    expect(bridge, greaterThan(controller));

    final productiveTail = source.substring(downstream, bridge);
    expect(
      RegExp(
        r'(?:requestId|sessionId)\s*:\s*'
        r'pipelineRequestId\b',
      ).hasMatch(productiveTail),
      isFalse,
    );
    expect(
      RegExp(
        r'(?:requestId|sessionId)\s*:\s*'
        r'pipelineSessionId\b',
      ).hasMatch(productiveTail),
      isFalse,
    );
    final preservedRequestLabels = RegExp(
      r'\bpipelineRequestId\s*:\s*'
      r'phase3kResolvedRequestId\b',
      multiLine: true,
    ).allMatches(productiveTail).length;
    final preservedSessionLabels = RegExp(
      r'\bpipelineSessionId\s*:\s*'
      r'phase3kResolvedSessionId\b',
      multiLine: true,
    ).allMatches(productiveTail).length;

    expect(preservedRequestLabels, 1);
    expect(preservedSessionLabels, 1);
    expect(productiveTail, contains('phase3kResolvedRequestId'));
    expect(productiveTail, contains('phase3kResolvedSessionId'));
  });

  test('canonical resolver is side-effect-free and eligibility scoped', () {
    final source = File(
      'lib/providers/app_provider.dart',
    ).readAsStringSync();

    final resolverStart = source.indexOf(
      '({String requestId, String sessionId}) '
      '_resolveCanonicalAiCorrelation({',
    );
    final selectorStart = source.indexOf(
      'Future<bool> sendAiMessage(',
      resolverStart,
    );
    final marker = source.indexOf(
      'Phase3K-C5A-R5: resolve the canonical pair before cutover.',
      selectorStart,
    );
    final downstream = source.indexOf(
      'Phase3K-C5A-R5: the same pair continues through pipeline or legacy.',
      marker,
    );

    expect(resolverStart, greaterThanOrEqualTo(0));
    expect(selectorStart, greaterThan(resolverStart));
    expect(marker, greaterThan(selectorStart));
    expect(downstream, greaterThan(marker));

    final resolver = source.substring(resolverStart, selectorStart);
    final block = source.substring(marker, downstream);

    expect(
      resolver,
      contains('ProviderRouterService.generateRequestId().trim()'),
    );
    expect(resolver, contains('_currentConversationSessionId.trim()'));
    expect(
      resolver,
      contains("'session_\${DateTime.now().millisecondsSinceEpoch}'"),
    );
    expect(
      resolver,
      isNot(anyOf(
        contains('_currentConversationSessionId ='),
        contains('onChunk('),
        contains('onDone('),
        contains('onError('),
        contains('persistAiExchangeOnce('),
        contains('batchWriteAiExchange('),
        contains('phase3kActiveCutoverController.execute('),
      )),
    );
    expect(block, contains('final phase3kCorrelation ='));
    expect(
      block,
      contains('phase3kResolvedRequestId = phase3kCorrelation.requestId;'),
    );
    expect(
      block,
      contains('phase3kResolvedSessionId = phase3kCorrelation.sessionId;'),
    );
    expect(block, isNot(contains('currentRequest.requestId')));
    expect(block, isNot(contains('currentRequest.sessionId')));
  });

  test('default-empty allowlist and repository currentRequest transport remain', () {
    final support = File(
      'lib/services/ai_pipeline/plantao/'
      'plantao_qa_cutover_support.dart',
    ).readAsStringSync();

    final correlatedInvocationPattern = RegExp(
      r'\.sendAiMessage\s*\('
      r'[\s\S]{0,3200}?'
      r'pipelineRequestId\s*:\s*currentRequest\.requestId\b'
      r'[\s\S]{0,3200}?'
      r'pipelineSessionId\s*:\s*currentRequest\.sessionId\b',
      multiLine: true,
    );

    var correlatedInvocationCount = 0;
    final correlatedFiles = <String>[];

    for (final entity in Directory('lib').listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }

      final content = entity.readAsStringSync();
      final count = correlatedInvocationPattern
          .allMatches(content)
          .length;

      if (count > 0) {
        correlatedInvocationCount += count;
        correlatedFiles.add(entity.path);
      }
    }

    expect(correlatedInvocationCount, 1);
    expect(correlatedFiles, hasLength(1));
    expect(
      support,
      contains('String.fromEnvironment'),
    );
    expect(
      support,
      isNot(contains(RegExp(r'uid_[A-Za-z0-9]'))),
    );
  });
}
