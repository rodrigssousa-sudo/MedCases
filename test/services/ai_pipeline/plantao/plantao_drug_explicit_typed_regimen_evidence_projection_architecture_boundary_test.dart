import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('explicit typed regimen projection stays isolated', () {
    final source = File(
      'lib/services/ai_pipeline/plantao/shadow/'
      'plantao_drug_explicit_typed_regimen_evidence_projection_shadow_adapter.dart',
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
      'localizedPayload(',
      'document.pt',
      'document.es',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }

    expect(source, contains("document.raw['aiRegimens']"));
    expect(source, contains("final dose = rawRegimen['dose']"));
    expect(source, contains('dose is! num'));
    expect(source, contains("_requiredString(rawRegimen['unit'])"));
    expect(source, contains("_requiredString(rawRegimen['route'])"));
    expect(source, contains("_requiredString(rawRegimen['frequency'])"));
    expect(source, contains('freeTextDoseExtractionEnabled = false'));
    expect(source, contains('freeTextRouteExtractionEnabled = false'));
    expect(source, contains('freeTextFrequencyExtractionEnabled = false'));
    expect(source, contains('inferredTypedRegimenEnabled = false'));
    expect(source, contains('validationConnected = false'));
    expect(source, contains('evidenceBundleMutationEnabled = false'));
    expect(source, contains('firestoreConnected = false'));
    expect(source, contains('writeExecuted = false'));
    expect(source, contains('cutoverAuthorized = false'));
    expect(source, contains('medicationMaterializationEnabled = false'));
  });
}
