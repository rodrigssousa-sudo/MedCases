import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PHASE3I-J2B2 V2 Plantão continuation context', () {
    late String provider;

    setUpAll(() {
      provider = File('lib/providers/app_provider.dart').readAsStringSync();
    });

    test('QA continuation is rehydrated before evaluation', () {
      final marker = provider.indexOf(
        '[PHASE3I_J2B2][CONTINUATION_REHYDRATED][QA]',
      );
      final evaluate = provider.indexOf(
        'final qaThreadStatus = _threadManager.evaluate(',
      );

      expect(marker, greaterThanOrEqualTo(0));
      expect(evaluate, greaterThan(marker));
    });

    test('main streaming continuation is rehydrated before evaluation', () {
      final marker = provider.indexOf(
        '[PHASE3I_J2B2][CONTINUATION_REHYDRATED][MAIN]',
      );
      final evaluate = provider.indexOf(
        'final threadStatus = _threadManager.evaluate(',
      );

      expect(marker, greaterThanOrEqualTo(0));
      expect(evaluate, greaterThan(marker));
    });

    test('both guards require button, missing topic and valid history', () {
      expect(
        RegExp(
          r'if \(fromButton &&\s*'
          r'!_threadManager\.hasActiveThread &&\s*'
          r'_sanitizedHistory\.isNotEmpty\)',
        ).allMatches(provider).length,
        equals(2),
      );

      expect(
        RegExp(
          r'_threadManager\.primeFromHistory\(\s*'
          r'List<Map<String, String>>\.from\(_sanitizedHistory\)',
        ).allMatches(provider).length,
        equals(2),
      );
    });

    test('batch buildAIAnswer path is intentionally untouched', () {
      final answerEvaluate = provider.indexOf(
        'final threadStatusAnswer = _threadManager.evaluate(',
      );
      expect(answerEvaluate, greaterThanOrEqualTo(0));

      final nearestMarkerBefore = provider.lastIndexOf(
        'PHASE3I-J2B2',
        answerEvaluate,
      );
      expect(
        answerEvaluate - nearestMarkerBefore,
        greaterThan(1000),
      );
    });

    test('new clinical cases still retain hard reset protection', () {
      expect(
        provider,
        contains(
          'if (qaThreadStatus.action == ThreadAction.newThread && !longResponse)',
        ),
      );
      expect(
        provider,
        contains(
          'else if (threadStatus.action == ThreadAction.newThread)',
        ),
      );
    });

    test('J2B1 remains present', () {
      final screen = File('lib/screens/ai_screen.dart').readAsStringSync();
      expect(
        screen,
        contains('PHASE3I-J2B1: terminal ownership reached'),
      );
    });
  });
}
