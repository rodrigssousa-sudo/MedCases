import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ACS pre-persist output guard wiring', () {
    late String source;

    setUpAll(() {
      source = File('lib/providers/app_provider.dart').readAsStringSync();
    });

    test('single owner import and adapter helper exist', () {
      expect(
        RegExp(
          r"import '../services/ai_pipeline/plantao/"
          r"plantao_clinical_regimen_output_guard\.dart';",
        ).allMatches(source),
        hasLength(1),
      );
      expect(
        source,
        contains('String _applyPlantaoClinicalRegimenOutputGuard({'),
      );
      expect(source, contains('PlantaoClinicalRegimenOutputGuard.enforce('));
    });

    test('GPT canonical finalizer guards before persistence', () {
      final start = source.indexOf(
        'Future<void> _finalizeGptSuccessfulRequest({',
      );
      final guard = source.indexOf(
        'safeOutput = _applyPlantaoClinicalRegimenOutputGuard(',
        start,
      );
      final persist = source.indexOf(
        'final persistStatus = await persistAiExchangeOnce(',
        start,
      );

      expect(start, greaterThanOrEqualTo(0));
      expect(guard, greaterThan(start));
      expect(persist, greaterThan(guard));
    });

    test('GPT guard text change rebinds the structured DTO', () {
      expect(
        source,
        contains(
          'regimenOutputGuardModified || questionsRepairedToValidContract',
        ),
      );
    });

    test('wrappedOnDone keeps regimen guard as final backstop', () {
      expect(
        source,
        contains(
          'final regimenGuardedText = '
          '_applyPlantaoClinicalRegimenOutputGuard(',
        ),
      );
      expect(source, contains('assistantOutput: regimenGuardedText'));
    });

    test('winner variables are guarded before direct history use', () {
      expect(
        RegExp(
          r'final gptText =\s*'
          r'_applyPlantaoClinicalRegimenOutputGuard\(',
        ).allMatches(source),
        hasLength(1),
      );
      expect(
        RegExp(
          r'final paidText =\s*'
          r'_applyPlantaoClinicalRegimenOutputGuard\(',
        ).allMatches(source),
        hasLength(2),
      );
      expect(
        RegExp(
          r'final qaFinalText =\s*'
          r'_applyPlantaoClinicalRegimenOutputGuard\(',
        ).allMatches(source),
        hasLength(1),
      );
      expect(
        RegExp(
          r'final partialText =\s*'
          r'_applyPlantaoClinicalRegimenOutputGuard\(',
        ).allMatches(source),
        hasLength(1),
      );
      expect(
        RegExp(
          r'retryFinalText\s*=\s*'
          r'_applyPlantaoClinicalRegimenOutputGuard\(',
        ).allMatches(source),
        hasLength(1),
      );
    });

    test('Gemini free main guard precedes history and persistence', () {
      final guardPayload = source.indexOf(
        'assistantOutput: sanitized?.text ?? barrierText',
      );
      final history = source.indexOf('_aiHistory', guardPayload);
      final persist = source.indexOf(
        'final freePersistStatus = await persistAiExchangeOnce(',
        guardPayload,
      );

      expect(guardPayload, greaterThanOrEqualTo(0));
      expect(history, greaterThan(guardPayload));
      expect(persist, greaterThan(history));
    });
  });
}
