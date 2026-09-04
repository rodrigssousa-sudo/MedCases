import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String bounded(
  String source,
  String startToken,
  String endToken,
) {
  final start = source.indexOf(startToken);
  expect(start, greaterThanOrEqualTo(0), reason: startToken);

  final end = source.indexOf(endToken, start + startToken.length);
  expect(end, greaterThan(start), reason: endToken);

  return source.substring(start, end);
}

void main() {
  group('R18 Study terminal busy release', () {
    late String source;

    setUpAll(() {
      source = File('lib/providers/app_provider.dart').readAsStringSync();
    });

    test('canonical busy getter remains the triple latch', () {
      expect(
        RegExp(
          r'bool\s+get\s+aiRequestBusy\s*=>\s*'
          r'_aiCallInFlight\s*\|\|\s*'
          r'_aiAnswerInProgress\s*\|\|\s*'
          r'_aiStreamActive\s*;',
        ).hasMatch(source),
        isTrue,
      );
    });

    test('terminal helper is request correlated', () {
      final helper = bounded(
        source,
        'bool _releaseAiBusyForRequest(',
        'void _completeAiRequestOnce(String requestId)',
      );

      expect(
        helper,
        contains('if (_activeRequestId != requestId)'),
      );
      expect(
        helper,
        contains('[AI_BUSY_RELEASE][STALE_PRESERVED]'),
      );
      expect(helper, contains('_aiCallInFlight = false;'));
      expect(helper, contains('_aiAnswerInProgress = false;'));
      expect(helper, contains('_aiStreamActive = false;'));
      expect(
        helper,
        contains('aiChatProvider.setStreaming(false);'),
      );
      expect(
        helper,
        contains('[AI_BUSY_RELEASE][RELEASED]'),
      );
      expect(helper, contains(r'afterBusy=$aiRequestBusy'));

      // R17 deliberately keeps the completed request id until the next
      // request replaces it, so late callbacks can be correlated safely.
      expect(
        helper,
        isNot(contains("_activeRequestId = '';")),
      );
    });

    test('canonical completion releases busy before coordinator', () {
      final block = bounded(
        source,
        'void _completeAiRequestOnce(String requestId)',
        '// ── MICRO-BUILD 462E-A.5.3.7.3.2.5 [PILLAR 1]',
      );

      final release = block.indexOf('_releaseAiBusyForRequest(');
      final coordinator = block.indexOf(
        'AppResumeCoordinator.instance.completeAiRequest(requestId);',
      );

      expect(release, greaterThanOrEqualTo(0));
      expect(coordinator, greaterThan(release));
      expect(
        block,
        contains("source: 'terminal_completion'"),
      );
    });

    test('late rejected onDone cannot clear a newer request', () {
      for (final label in <String>[
        'stream_onDone',
        'retry_onDone',
      ]) {
        final start = source.indexOf(
          "if (!tryAcquireTerminalOwnership('$label'))",
        );
        expect(start, greaterThanOrEqualTo(0), reason: label);

        final end = source.indexOf('return;', start);
        expect(end, greaterThan(start), reason: label);

        final branch = source.substring(start, end + 'return;'.length);

        expect(
          branch,
          contains('if (_activeRequestId == thisRequestId)'),
          reason: label,
        );
        expect(
          branch,
          contains(
            '[AI_BUSY_RELEASE][STALE_CALLBACK_PRESERVED]',
          ),
          reason: label,
        );
      }
    });

    test('legacy finally remains unchanged in behavior', () {
      final legacy = bounded(
        source,
        '// Build 134 — Single-Flight Guard: liberação no finally.',
        'Future<String> buildAIAnswer(',
      );

      expect(
        legacy,
        contains('_aiCallInFlight = false;'),
      );
      expect(
        legacy,
        contains('if (!_aiStreamActive)'),
      );
      expect(
        legacy,
        contains('_completeAiRequestOnce(thisRequestId);'),
      );
      expect(
        legacy,
        isNot(
          contains('[AI_BUSY_RELEASE][STALE_FINALLY_PRESERVED]'),
        ),
      );
    });

    test('ghost request guard remains before lifecycle registration', () {
      final core = bounded(
        source,
        'Future<bool> _sendAiMessageLegacyCore(',
        '// Build 134 — Single-Flight Guard: liberação no finally.',
      );

      final guard = core.indexOf(
        'if (_aiCallInFlight || '
        '_aiAnswerInProgress || _aiStreamActive)',
      );
      final timing = core.indexOf('[AI_TIMING]');
      final registration = core.indexOf(
        'AppResumeCoordinator.instance.registerAiRequest(',
      );

      expect(guard, greaterThanOrEqualTo(0));
      expect(timing, greaterThan(guard));
      expect(registration, greaterThan(guard));
      expect(
        core,
        isNot(
          contains(
            '[sendAiMessage] ignorado — resposta em andamento',
          ),
        ),
      );
    });
  });
}
