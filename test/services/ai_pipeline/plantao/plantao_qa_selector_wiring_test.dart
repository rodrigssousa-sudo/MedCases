import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase3K-C3 QA selector wiring', () {
    test('support and typed pipeline are wired exactly once', () {
      final source = File(
        'lib/providers/app_provider.dart',
      ).readAsStringSync();

      expect(
        RegExp(r'PlantaoQaCutoverSupport _plantaoQaCutoverSupport')
            .allMatches(source)
            .length,
        1,
      );
      expect(
        RegExp(r'AppProviderAiResponsePipeline\.fromAppProvider\s*\(')
            .allMatches(source)
            .length,
        1,
      );
      expect(
        source,
        contains(
          'const PlantaoBufferedCutoverController.disabled()',
        ),
      );
    });

    test('default-empty allowlist preserves legacy path', () {
      final app = File(
        'lib/providers/app_provider.dart',
      ).readAsStringSync();
      final support = File(
        'lib/services/ai_pipeline/plantao/'
        'plantao_qa_cutover_support.dart',
      ).readAsStringSync();

      expect(support, contains("defaultValue: ''"));
      expect(
        RegExp(
          r'phase3kQaEligible\s*'
          r'\?\s*PlantaoBufferedCutoverController\s*\(',
        ).hasMatch(app),
        isTrue,
      );
      expect(
        app,
        contains(': _plantaoBufferedCutoverController'),
      );
      expect(app, isNot(contains('rawUidAllowlist:')));
    });

    test('eligibility uses Plantão criterion and authenticated UID', () {
      final source = File(
        'lib/providers/app_provider.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('final phase3kQaIsPlantao = !longResponse;'),
      );
      expect(
        source,
        contains('authenticatedUid: phase3kQaAuthenticatedUid'),
      );
      expect(
        source,
        contains('isPlantao: phase3kQaIsPlantao'),
      );
    });

    test('active controller owns eligibility and execution', () {
      final source = File(
        'lib/providers/app_provider.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('phase3kActiveCutoverController.enabled'),
      );
      expect(
        source,
        contains('phase3kActiveCutoverController.execute('),
      );
      expect(
        source,
        isNot(
          contains(
            '_plantaoBufferedCutoverController.execute(',
          ),
        ),
      );
    });

    test('observability emits closed QA events', () {
      final source = File(
        'lib/providers/app_provider.dart',
      ).readAsStringSync();

      const events = <String>[
        'eligibilityAccepted',
        'eligibilityRejected',
        'pipelineStarted',
        'legacyFallbackBeforeEvent',
        'validationRejected',
        'commitValidated',
        'terminalCompleted',
      ];
      for (final event in events) {
        expect(
          source,
          contains('PlantaoQaCutoverEvent.$event'),
        );
      }

      expect(
        source,
        contains('phase3kQaAllowlistConfigured'),
      );
      expect(
        source,
        isNot(contains('rawUidAllowlist:')),
      );
    });

    test('provider seam remains single and non-recursive', () {
      final source = File(
        'lib/services/ai_pipeline/'
        'app_provider_ai_response_pipeline.dart',
      ).readAsStringSync();

      expect(
        RegExp(r'provider\.sendAiMessageForPipeline\s*\(')
            .allMatches(source)
            .length,
        1,
      );
      expect(
        RegExp(r'provider\.sendAiMessage\s*\(')
            .allMatches(source)
            .length,
        0,
      );
    });
  });
}
