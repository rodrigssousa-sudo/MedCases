import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão clinical consistency productive binding', () {
    late String aiScreen;
    late String provider;
    late String promptContract;

    setUpAll(() {
      aiScreen = File(
        'lib/screens/ai_screen.dart',
      ).readAsStringSync();

      provider = File(
        'lib/providers/app_provider.dart',
      ).readAsStringSync();

      promptContract = File(
        'lib/services/ai_service.dart',
      ).readAsStringSync();
    });

    test('binds the guard before paid persistence', () {
      expect(
        provider,
        contains(
          'safeOutput = PlantaoClinicalResponseConsistencyGuard.enforce(',
        ),
      );
      expect(
        provider.indexOf(
          'safeOutput = PlantaoClinicalResponseConsistencyGuard.enforce(',
        ),
        lessThan(provider
            .indexOf('final persistStatus = await persistAiExchangeOnce(')),
      );
    });

    test('keeps paid safeOutput mutable for the post-gate guard', () {
      expect(provider, contains('String safeOutput;'));
      expect(provider, isNot(contains('final String safeOutput;')));
      expect(
        provider.indexOf('String safeOutput;'),
        lessThan(
          provider.indexOf(
            'safeOutput = PlantaoClinicalResponseConsistencyGuard.enforce(',
          ),
        ),
      );
    });

    test('binds the guard at the universal terminal callback', () {
      expect(
        provider,
        contains(
          'final guardedText = !longResponse',
        ),
      );
      expect(provider, contains('onDone(guardedText);'));
      expect(
        provider,
        contains(
          'onStructuredDone?.call(guardedText, guardedClinicalOutput);',
        ),
      );
    });

    test('keeps the complete model input available to the guard', () {
      expect(provider, contains('userInput: input,'));
      expect(provider, contains('assistantOutput: safeOutput,'));
      expect(provider, contains('assistantOutput: text,'));
    });

    test('preserves the visible/model payload separation contract', () {
      expect(aiScreen, contains('visibleUserInput: trimmed,'));
      expect(
        provider,
        contains('userInput: persistedUserInput,'),
      );
      expect(
        provider,
        contains('userMessage: input'),
      );
    });

    test('active compact prompt no longer requests generic ranking', () {
      expect(promptContract, isNot(contains('1ª linha:')));
      expect(promptContract, isNot(contains('2ª linha:')));
      expect(promptContract, isNot(contains('1ª linea:')));
      expect(promptContract, isNot(contains('2ª linea:')));
    });

    test('active compact prompt requests neutral medication grouping without artificial ranking', () {
      expect(
        promptContract,
        contains('Medicamentos e intervencoes indicados, sem hierarquia artificial.'),
      );
      expect(
        promptContract,
        contains('Medicamentos e intervenciones indicados, sin jerarquia artificial.'),
      );
    });
  });
}
