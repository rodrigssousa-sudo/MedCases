import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('typed regimen capability matrix remains observational', () {
    final source = File(
      'lib/services/ai_pipeline/plantao/shadow/'
      'plantao_drug_typed_regimen_capability_matrix_shadow_adapter.dart',
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
      'RegExp(',
      'double.tryParse',
      'num.tryParse',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }

    expect(source, contains('freeTextDoseExtractionEnabled = false'));
    expect(source, contains('freeTextRouteExtractionEnabled = false'));
    expect(source, contains('freeTextFrequencyExtractionEnabled = false'));
    expect(source, contains('inferredTypedRegimenEnabled = false'));
    expect(source, contains('firestoreConnected = false'));
    expect(source, contains('writeExecuted = false'));
    expect(source, contains('writeEligible = false'));
    expect(source, contains('cutoverReadinessGranted = false'));
    expect(source, contains('cutoverAuthorized = false'));
    expect(source, contains('medicationMaterializationEnabled = false'));
    expect(source, contains('typed_regimen_contract_unavailable'));
    expect(source, contains('free_text_regimen_inference_not_authorized'));
  });
}
