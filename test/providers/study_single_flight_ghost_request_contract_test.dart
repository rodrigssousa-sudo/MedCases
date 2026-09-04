import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Study single-flight ghost request contract', () {
    test('busy projection is public to UI and provider guard is pre-registration', () {
      final source = File('lib/providers/app_provider.dart').readAsStringSync();

      expect(
        source,
        matches(
          RegExp(
            r'bool\s+get\s+aiRequestBusy\s*=>\s*'
            r'_aiCallInFlight\s*\|\|\s*'
            r'_aiAnswerInProgress\s*\|\|\s*'
            r'_aiStreamActive\s*;',
            multiLine: true,
          ),
        ),
      );

      final start = source.indexOf('Future<bool> _sendAiMessageLegacyCore(');
      expect(start, greaterThanOrEqualTo(0));
      final next = source.indexOf('Future<', start + 40);
      final core =
          next > start ? source.substring(start, next) : source.substring(start);

      final guard =
          core.indexOf(
            'if (_aiCallInFlight || _aiAnswerInProgress || _aiStreamActive)');
      final timing = core.indexOf('[AI_TIMING]');
      final registration =
          core.indexOf('AppResumeCoordinator.instance.registerAiRequest(');

      expect(guard, greaterThanOrEqualTo(0));
      expect(timing, greaterThan(guard));
      expect(registration, greaterThan(guard));
      expect(
        core,
        isNot(contains('[sendAiMessage] ignorado — resposta em andamento')),
      );
    });

    test('provider retains enough verbatim history for 30 exchanges', () {
      final source = File('lib/providers/app_provider.dart').readAsStringSync();

      expect(
        source,
        isNot(
          contains(
            'while (_aiHistory.length > 20) _aiHistory.removeAt(0);',
          ),
        ),
      );
      expect(
        source,
        contains(
          'while (_aiHistory.length > 60) _aiHistory.removeAt(0);',
        ),
      );
      expect(
        source,
        contains(
          'valid.length > 60 ? valid.sublist(valid.length - 60) : valid',
        ),
      );
      expect(source, contains('_completeAiRequestOnce('));
      expect(source, contains('_aiCallInFlight = false'));
      expect(source, contains('_aiAnswerInProgress = false'));
    });
  });
}
