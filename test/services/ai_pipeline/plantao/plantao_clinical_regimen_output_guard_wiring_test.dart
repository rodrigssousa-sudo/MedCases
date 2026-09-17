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
      // Verifica o fluxo, inclusive a terceira barreira, sem depender de
      // uma substring que era invalidada por quebras de linha do formatter.
      final start = source.indexOf(
        'Future<void> _finalizeGptSuccessfulRequest({',
      );
      expect(start, greaterThanOrEqualTo(0));

      final guard = source.indexOf(
        'final regimenOutputGuardModified = safeOutput != preRegimenSafeOutput;',
        start,
      );
      final evidence = source.indexOf(
        'final evidenceComplianceModified =',
        start,
      );
      final dto = source.indexOf(
        'final ClinicalStructuredOutput? safeClinicalOutput =',
        start,
      );
      final persist = source.indexOf(
        'final persistStatus = await persistAiExchangeOnce(',
        start,
      );
      final done = source.indexOf(
        'wrappedOnDone(finalUiText, safeClinicalOutput);',
        start,
      );
      expect(guard, greaterThan(start));
      expect(evidence, greaterThan(guard));
      expect(dto, greaterThan(evidence));
      expect(persist, greaterThan(dto));
      expect(done, greaterThan(persist));

      final binding = source.substring(dto, persist);
      final rebindsFromFinalText = RegExp(
        r'final ClinicalStructuredOutput\?\s+safeClinicalOutput\s*=\s*'
        r'safeOutput\s*==\s*validatedOutput\s*\?\s*productiveClinicalOutput'
        r'\s*:\s*\(\s*regimenOutputGuardModified\s*\|\|\s*'
        r'questionsRepairedToValidContract\s*\|\|\s*'
        r'evidenceComplianceModified\s*\)\s*\?\s*'
        r'PlantaoLocalClinicalOutputAdapter\.fromValidatedText'
        r'\(\s*safeOutput\s*\)\s*:\s*null\s*;',
      );
      expect(rebindsFromFinalText.hasMatch(binding), isTrue);
      expect(
        source.substring(persist, done),
        contains('assistantOutput: safeOutput,'),
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
