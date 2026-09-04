import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persistence payload preparation remains shadow and write-free', () {
    final source = File(
      'lib/services/ai_pipeline/plantao/shadow/'
      'plantao_drug_provenance_persistence_payload_shadow_adapter.dart',
    ).readAsStringSync();

    for (final forbidden in <String>[
      'AppProvider',
      'FirebaseFirestore',
      'FirestoreService',
      '.set(',
      '.add(',
      '.update(',
      'notifyListeners',
      'PlantaoMedicationItem(',
      'matchedDrugSummaries',
      'WebView',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }

    expect(source, contains('firestoreConnected = false'));
    expect(source, contains('persistenceOwnerReplaced = false'));
    expect(source, contains('persistenceEligibilityPromoted = false'));
    expect(source, contains("..['provenance'] = binding.provenance.toJson()"));
    expect(source, contains('baseFuturePersistenceEligible'));
  });
}
