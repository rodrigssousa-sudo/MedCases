import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('review envelope remains observational and write-free', () {
    final source = File(
      'lib/services/ai_pipeline/plantao/shadow/'
      'plantao_drug_provenance_persistence_review_envelope_shadow_adapter.dart',
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
    expect(source, contains('manual_cutover_review_required'));
    expect(source, contains('_freezeMap('));
  });
}
