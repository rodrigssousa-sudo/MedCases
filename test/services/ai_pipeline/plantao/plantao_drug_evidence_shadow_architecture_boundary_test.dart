import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'canonical drug evidence remains disconnected from productive pipeline',
    () {
      final paths = <String>[
        'lib/services/ai_pipeline/plantao/contracts/'
            'plantao_canonical_drug_evidence.dart',
        'lib/services/ai_pipeline/plantao/ports/'
            'plantao_drug_evidence_port.dart',
        'lib/services/ai_pipeline/plantao/adapters/'
            'plantao_http_drug_evidence_adapter.dart',
        'lib/services/ai_pipeline/plantao/shadow/'
            'plantao_drug_candidate_resolver.dart',
        'lib/services/ai_pipeline/plantao/shadow/'
            'plantao_drug_evidence_shadow_adapter.dart',
      ];
      final combined = paths
          .map((path) => File(path).readAsStringSync())
          .join('\n');

      for (final forbidden in <String>[
        'app_provider.dart',
        'provider_router_service.dart',
        'gpt_sse_client.dart',
        'gemini_service',
        'firestore_service.dart',
        'notifyListeners',
        'matchedDrugSummaries',
        'PlantaoMedicationItem(',
        'ExternalToolLinkEngine',
        'WebView',
      ]) {
        expect(combined, isNot(contains(forbidden)), reason: forbidden);
      }

      expect(combined, contains('productiveConnectionEnabled = false'));
      expect(combined, contains('providerGroundingEnabled = false'));
      expect(combined, contains('promptMutationEnabled = false'));
      expect(combined, contains('medcasescalcu.com'));
      expect(combined, contains('supportsMedicationMaterialization'));
    },
  );

  test(
    'resolver uses exact identity matching and no free-text pattern parser',
    () {
      final resolver = File(
        'lib/services/ai_pipeline/plantao/shadow/'
        'plantao_drug_candidate_resolver.dart',
      ).readAsStringSync();
      expect(resolver, isNot(contains('RegExp(')));
      expect(resolver, isNot(contains('substring')));
      expect(resolver, isNot(contains('levenshtein')));
      expect(resolver, contains('exactId'));
      expect(resolver, contains('exactKeyword'));
    },
  );
}
