import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/plantao_pipeline.dart';

void main() {
  test('provenance round-trips every mandatory field', () {
    final PlantaoProvenance provenance = PlantaoProvenance(
      provider: 'gpt',
      model: 'model-x',
      sourceMode: PlantaoSourceMode.mixed,
      matchedClinicalDocumentIds: const <String>['clinical-1'],
      matchedDrugDocumentIds: const <String>['drug-1'],
      validatedDose: true,
      validatorReason: 'matched canonical document',
      usedExternalGrounding: false,
      continuationType: PlantaoContinuationType.examsEvolution,
      documentVersions: const <String, String>{
        'clinical-1': 'v2',
        'drug-1': 'v3',
      },
    );

    final PlantaoProvenance decoded = PlantaoProvenance.fromJson(
      provenance.toJson(),
    );

    expect(decoded.provider, 'gpt');
    expect(decoded.model, 'model-x');
    expect(decoded.sourceMode, PlantaoSourceMode.mixed);
    expect(decoded.matchedClinicalDocumentIds, <String>['clinical-1']);
    expect(decoded.matchedDrugDocumentIds, <String>['drug-1']);
    expect(decoded.validatedDose, isTrue);
    expect(decoded.validatorReason, 'matched canonical document');
    expect(decoded.usedExternalGrounding, isFalse);
    expect(decoded.continuationType, PlantaoContinuationType.examsEvolution);
    expect(decoded.documentVersions['drug-1'], 'v3');
  });

  test('strict mode rejects sensitive model-native pharmacology', () {
    final PlantaoProvenance provenance = PlantaoProvenance(
      provider: 'gpt',
      model: 'model-x',
      sourceMode: PlantaoSourceMode.modelNative,
      matchedClinicalDocumentIds: const <String>[],
      matchedDrugDocumentIds: const <String>[],
      validatedDose: false,
      validatorReason: 'no canonical drug document',
      usedExternalGrounding: false,
      continuationType: PlantaoContinuationType.initial,
      documentVersions: const <String, String>{},
    );

    expect(
      provenance.isStrictModeCompatible(containsSensitivePharmacology: true),
      isFalse,
    );
  });
}
