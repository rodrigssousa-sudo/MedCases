import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IAM generic whole-response semantic-core wiring', () {
    late String source;

    setUpAll(() {
      source = File('lib/providers/app_provider.dart').readAsStringSync();
    });

    test('dedicated owner is imported exactly once', () {
      expect(
        RegExp(
          r"import '../services/ai_pipeline/plantao/"
          r"plantao_generic_acs_whole_response_semantic_core\.dart';",
        ).allMatches(source),
        hasLength(1),
      );
    });

    test(
      'shared final output helper materializes semantic core before regimen guard',
      () {
        final helper = source.indexOf(
          'String _applyPlantaoClinicalRegimenOutputGuard({',
        );
        final semantic = source.indexOf(
          'PlantaoGenericAcsWholeResponseSemanticCore.materialize(',
          helper,
        );
        final regimen = source.indexOf(
          'PlantaoClinicalRegimenOutputGuard.enforce(',
          helper,
        );
        final helperEnd = source.indexOf('\n  }', regimen);

        expect(helper, greaterThanOrEqualTo(0));
        expect(semantic, greaterThan(helper));
        expect(regimen, greaterThan(semantic));
        expect(helperEnd, greaterThan(regimen));
      },
    );

    test('existing pre-persist regimen call-site topology is unchanged', () {
      expect(
        RegExp(r'_applyPlantaoClinicalRegimenOutputGuard\(').allMatches(source),
        hasLength(12),
      );
      expect(
        RegExp(
          r'final gptText =\s*_applyPlantaoClinicalRegimenOutputGuard\(',
        ).allMatches(source),
        hasLength(1),
      );
      expect(
        RegExp(
          r'final paidText =\s*_applyPlantaoClinicalRegimenOutputGuard\(',
        ).allMatches(source),
        hasLength(2),
      );
      expect(
        RegExp(
          r'final qaFinalText =\s*_applyPlantaoClinicalRegimenOutputGuard\(',
        ).allMatches(source),
        hasLength(1),
      );
      expect(
        RegExp(
          r'final partialText =\s*_applyPlantaoClinicalRegimenOutputGuard\(',
        ).allMatches(source),
        hasLength(1),
      );
      expect(
        RegExp(
          r'retryFinalText =\s*_applyPlantaoClinicalRegimenOutputGuard\(',
        ).allMatches(source),
        hasLength(1),
      );
    });

    test(
      'semantic-core change remains before canonical GPT persistence and DTO rebind',
      () {
        final start = source.indexOf(
          'Future<void> _finalizeGptSuccessfulRequest({',
        );
        final helperCall = source.indexOf(
          'safeOutput = _applyPlantaoClinicalRegimenOutputGuard(',
          start,
        );
        final rebind = source.indexOf(
          'PlantaoLocalClinicalOutputAdapter.fromValidatedText(safeOutput)',
          helperCall,
        );
        final persist = source.indexOf(
          'final persistStatus = await persistAiExchangeOnce(',
          helperCall,
        );

        expect(helperCall, greaterThan(start));
        expect(rebind, greaterThan(helperCall));
        expect(persist, greaterThan(rebind));
      },
    );
  });
}
