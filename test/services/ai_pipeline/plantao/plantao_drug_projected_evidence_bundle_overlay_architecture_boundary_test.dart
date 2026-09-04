import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('projected evidence overlay stays isolated and immutable', () {
    final source = File(
      'lib/services/ai_pipeline/plantao/shadow/'
      'plantao_drug_projected_evidence_bundle_overlay_shadow_adapter.dart',
    ).readAsStringSync();

    for (final forbidden in <String>[
      'AppProvider',
      'FirebaseFirestore',
      'FirestoreService',
      '.collection(',
      '.doc(',
      '.set(',
      '.update(',
      'notifyListeners',
      'PlantaoValidationShadowAdapter',
      'PlantaoDeterministicDrugValidator',
      'PlantaoMedicationItem(',
      'matchedDrugSummaries',
      'WebView',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }

    expect(source, contains('baseEvidenceBundleMutated = false'));
    expect(source, contains('validationConnected = false'));
    expect(source, contains('validationReexecuted = false'));
    expect(source, contains('productiveEvidenceOwnerReplaced = false'));
    expect(source, contains('promptConnected = false'));
    expect(source, contains('rendererConnected = false'));
    expect(source, contains('firestoreConnected = false'));
    expect(source, contains('writeExecuted = false'));
    expect(source, contains('writeEligible = false'));
    expect(source, contains('cutoverReadinessGranted = false'));
    expect(source, contains('cutoverAuthorized = false'));
    expect(source, contains('medicationMaterializationEnabled = false'));
    expect(source, contains('PlantaoEvidenceBundle('));
    expect(source, contains('drugDocuments: mergedDrugDocuments'));
    expect(source, contains('base_evidence_bundle_preserved'));
  });
}
