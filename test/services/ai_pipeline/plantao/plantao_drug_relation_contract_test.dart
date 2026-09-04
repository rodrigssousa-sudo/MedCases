import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/plantao_pipeline.dart';

void main() {
  test('contract exposes all required therapeutic relations', () {
    expect(
      PlantaoDrugRelationType.values.map(
        (PlantaoDrugRelationType item) => item.name,
      ),
      containsAll(<String>[
        'concomitant',
        'alternative',
        'conditional',
        'firstLine',
        'secondLine',
        'adjunct',
        'rescue',
        'contraindicated',
        'sequenceStep',
      ]),
    );
  });

  test('AAS and ticagrelor can both be concomitant', () {
    const PlantaoMedicationItem aas = PlantaoMedicationItem(
      drugDocumentId: 'drug-aas',
      drugName: 'AAS',
      relation: PlantaoDrugRelationType.concomitant,
      indication: 'Antiagregação no IAM',
      dose: 300,
      unit: 'mg',
      route: 'VO',
      frequency: 'dose de ataque',
      evidenceVersion: 'v1',
      validationStatus: PlantaoDrugValidationStatus.validated,
    );
    const PlantaoMedicationItem ticagrelor = PlantaoMedicationItem(
      drugDocumentId: 'drug-ticagrelor',
      drugName: 'Ticagrelor',
      relation: PlantaoDrugRelationType.concomitant,
      indication: 'Dupla antiagregação no IAM',
      dose: 180,
      unit: 'mg',
      route: 'VO',
      frequency: 'dose de ataque',
      evidenceVersion: 'v1',
      validationStatus: PlantaoDrugValidationStatus.validated,
    );

    expect(aas.relation, PlantaoDrugRelationType.concomitant);
    expect(ticagrelor.relation, PlantaoDrugRelationType.concomitant);
    expect(
      PlantaoMedicationItem.fromJson(aas.toJson()).relation,
      PlantaoDrugRelationType.concomitant,
    );
  });
}
