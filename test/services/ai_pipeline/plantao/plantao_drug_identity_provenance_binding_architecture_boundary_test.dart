import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('identity provenance binding remains observational', () {
    final source = File(
      'lib/services/ai_pipeline/plantao/shadow/'
      'plantao_drug_identity_provenance_binding_shadow_adapter.dart',
    ).readAsStringSync();

    for (final forbidden in <String>[
      'AppProvider',
      'AiService',
      'ProviderRouter',
      'Firestore',
      'notifyListeners',
      'PlantaoMedicationItem(',
      'matchedDrugSummaries',
      'ExternalToolLinkEngine',
      'WebView',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }

    expect(
      source,
      contains('validatedDose: validationProvenance.validatedDose'),
    );
    expect(source, contains('medicationCandidateBound = false'));
    expect(source, contains('medicationMaterializationEnabled = false'));
    expect(source, contains('canonical_drug_identity_provenance_bound'));
    expect(
      source,
      contains('drug_identity_evidence_not_used_for_dose_validation'),
    );
  });
}
