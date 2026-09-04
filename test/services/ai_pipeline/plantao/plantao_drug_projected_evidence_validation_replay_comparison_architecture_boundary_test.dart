import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validation replay comparison remains observational and write-free', () {
    final source = File(
      'lib/services/ai_pipeline/plantao/shadow/'
      'plantao_drug_projected_evidence_validation_replay_comparison_shadow_adapter.dart',
    ).readAsStringSync();

    for (final forbidden in <String>[
      'AppProvider',
      'PlantaoValidationShadowAdapter',
      'PlantaoPersistenceShadowAdapter',
      'FirebaseFirestore',
      'FirestoreService',
      '.collection(',
      '.doc(',
      '.set(',
      '.update(',
      'notifyListeners',
      'PlantaoMedicationItem(',
      'matchedDrugSummaries',
      'WebView',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }

    expect(source, contains('originalValidationReplaced = false'));
    expect(source, contains('productiveValidationOwnerReplaced = false'));
    expect(source, contains('productiveEvidenceOwnerReplaced = false'));
    expect(source, contains('persistenceRecomputed = false'));
    expect(source, contains('candidateValidationUsedForPersistence = false'));
    expect(source, contains('candidateValidationUsedForPrompt = false'));
    expect(source, contains('candidateValidationUsedForRendering = false'));
    expect(source, contains('firestoreConnected = false'));
    expect(source, contains('writeExecuted = false'));
    expect(source, contains('writeEligible = false'));
    expect(source, contains('cutoverReadinessGranted = false'));
    expect(source, contains('cutoverAuthorized = false'));
    expect(source, contains('medicationMaterializationEnabled = false'));
    expect(source, contains('original_validation_preserved'));
    expect(source, contains('persistence_recomputation_not_authorized'));
  });
}
