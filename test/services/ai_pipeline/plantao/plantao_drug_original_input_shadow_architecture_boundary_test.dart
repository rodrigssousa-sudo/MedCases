import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'original-input identity resolution stays outside productive ownership',
    () {
      final paths = <String>[
        'lib/services/ai_pipeline/plantao/shadow/'
            'plantao_drug_original_input_identity_extractor.dart',
        'lib/services/ai_pipeline/plantao/shadow/'
            'plantao_drug_evidence_shadow_adapter.dart',
        'lib/services/ai_pipeline/plantao/adapters/'
            'plantao_http_drug_evidence_adapter.dart',
      ];
      final combined = paths
          .map((path) => File(path).readAsStringSync())
          .join('\n');

      for (final forbidden in <String>[
        'app_provider.dart',
        'ai_service.dart',
        'provider_router_service.dart',
        'gpt_sse_client.dart',
        'gemini_service',
        'firestore_service.dart',
        'notifyListeners',
        'matchedDrugSummaries',
        'PlantaoMedicationItem(',
        'ExternalToolLinkEngine',
        'lastAiResponse',
        'generatedText',
        'finalText',
        'WebView',
      ]) {
        expect(combined, isNot(contains(forbidden)), reason: forbidden);
      }

      expect(combined, contains('originalUserInput'));
      expect(combined, contains('explicit_pharmacology_intent_absent'));
      expect(combined, contains('clearCache'));
      expect(combined, contains('supportsMedicationMaterialization'));
    },
  );

  test('extractor uses boundary-normalized canonical index identities', () {
    final source = File(
      'lib/services/ai_pipeline/plantao/shadow/'
      'plantao_drug_original_input_identity_extractor.dart',
    ).readAsStringSync();

    expect(source, contains('normalizeForBoundary'));
    expect(source, contains('canonical_alias_collision'));
    expect(source, contains('interaction_requires_exactly_two_drugs'));
    expect(source, isNot(contains('RegExp(')));
    expect(source, isNot(contains('lastAiResponse')));
  });
}
