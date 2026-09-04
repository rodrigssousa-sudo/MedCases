import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('semantic equality gate remains observational and write-free', () {
    final source = File(
      'lib/services/ai_pipeline/plantao/shadow/'
      'plantao_drug_provenance_semantic_equality_gate_shadow_adapter.dart',
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
    expect(source, contains('cutoverReadinessGranted = false'));
    expect(source, contains('cutoverAuthorized = false'));
    expect(source, contains('persistenceOwnerReplaced = false'));
    expect(source, contains('persistenceEligibilityPromoted = false'));
    expect(source, contains('medicationMaterializationEnabled = false'));
    expect(source, contains('binding.provenance.toJson()'));
    expect(source, contains('_collectMismatchPaths('));
    expect(source, contains(r"final childPath = '$path.$key';"));
    expect(source, contains(r"mismatches.add('$childPath:missing')"));
  });
}
