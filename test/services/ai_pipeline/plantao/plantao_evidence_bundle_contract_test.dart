import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/plantao_pipeline.dart';

void main() {
  test('empty evidence is explicit and never looks complete', () {
    final PlantaoEvidenceBundle bundle = PlantaoEvidenceBundle.empty(
      missingRequirements: const <String>[
        'ketones',
        'bicarbonate',
        'anion_gap',
        'osmolality',
      ],
    );

    expect(bundle.isEmpty, isTrue);
    expect(bundle.hasDeterministicDrugEvidence, isFalse);
    expect(bundle.retrievalStatus, PlantaoRetrievalStatus.empty);
    expect(bundle.missingRequirements, contains('ketones'));
  });

  test('drug evidence carries deterministic dose fields', () {
    final PlantaoDrugEvidenceDocument document = PlantaoDrugEvidenceDocument(
      documentId: 'drug-insulin-1',
      version: 'v1',
      excerpt: 'Dose canônica validada.',
      drugName: 'Insulina regular',
      dose: 0.1,
      unit: 'U/kg/h',
      route: 'IV',
      frequency: 'infusão contínua',
    );

    final PlantaoEvidenceBundle bundle = PlantaoEvidenceBundle(
      clinicalDocuments: const <PlantaoEvidenceDocument>[],
      drugDocuments: <PlantaoDrugEvidenceDocument>[document],
      protocolDocuments: const <PlantaoEvidenceDocument>[],
      patientFacts: const <PlantaoEvidenceDocument>[],
      caseEvidence: const <PlantaoEvidenceDocument>[],
      externalGrounding: const <PlantaoEvidenceDocument>[],
      documentVersions: const <String, String>{'drug-insulin-1': 'v1'},
      coverage: const PlantaoEvidenceCoverage(
        hasClinical: false,
        hasDrug: true,
        hasProtocol: false,
        hasPatientFacts: false,
      ),
      missingRequirements: const <String>[],
      retrievalStatus: PlantaoRetrievalStatus.complete,
    );

    final PlantaoEvidenceBundle decoded = PlantaoEvidenceBundle.fromJson(
      bundle.toJson(),
    );

    expect(decoded.hasDeterministicDrugEvidence, isTrue);
    expect(decoded.drugDocuments.single.route, 'IV');
    expect(decoded.drugDocuments.single.frequency, 'infusão contínua');
  });
}
