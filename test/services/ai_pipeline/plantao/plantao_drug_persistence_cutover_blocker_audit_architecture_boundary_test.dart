import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cutover blocker audit remains observational and write-free', () {
    final source = File(
      'lib/services/ai_pipeline/plantao/shadow/'
      'plantao_drug_persistence_cutover_blocker_audit_shadow_adapter.dart',
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
      'PlantaoMedicationItem(',
      'matchedDrugSummaries',
      'WebView',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }

    expect(source, contains('firestoreConnected = false'));
    expect(source, contains('writeExecuted = false'));
    expect(source, contains('writeEligible = false'));
    expect(source, contains('cutoverReadinessGranted = false'));
    expect(source, contains('cutoverAuthorized = false'));
    expect(source, contains('persistenceOwnerReplaced = false'));
    expect(source, contains('persistenceEligibilityPromoted = false'));
    expect(source, contains('medicationMaterializationEnabled = false'));
    expect(source, contains('typed_regimen_evidence_absent'));
    expect(source, contains('dose_not_deterministically_validated'));
    expect(source, contains('productive_cutover_not_authorized'));
  });
}
