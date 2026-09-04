import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_drug_relation.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_evidence_bundle.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_deterministic_drug_validator.dart';

PlantaoMedicationCandidate candidate({num dose = 300}) {
  return PlantaoMedicationCandidate(
    drugName: 'Ácido acetilsalicílico',
    relation: PlantaoDrugRelationType.concomitant,
    indication: 'Síndrome coronariana aguda',
    dose: dose,
    unit: 'mg',
    route: 'VO',
    frequency: 'dose de ataque',
  );
}

PlantaoEvidenceBundle evidence({num dose = 300}) {
  final document = PlantaoDrugEvidenceDocument(
    documentId: 'drug-aas-v1',
    version: '1.0.0',
    excerpt: 'AAS 300 mg VO em dose de ataque.',
    drugName: 'Ácido acetilsalicílico',
    dose: dose,
    unit: 'mg',
    route: 'VO',
    frequency: 'dose de ataque',
  );
  return PlantaoEvidenceBundle(
    clinicalDocuments: const <PlantaoEvidenceDocument>[],
    drugDocuments: <PlantaoDrugEvidenceDocument>[document],
    protocolDocuments: const <PlantaoEvidenceDocument>[],
    patientFacts: const <PlantaoEvidenceDocument>[],
    caseEvidence: const <PlantaoEvidenceDocument>[],
    externalGrounding: const <PlantaoEvidenceDocument>[],
    documentVersions: const <String, String>{'drug-aas-v1': '1.0.0'},
    coverage: const PlantaoEvidenceCoverage(
      hasClinical: false,
      hasDrug: true,
      hasProtocol: false,
      hasPatientFacts: false,
    ),
    missingRequirements: const <String>[],
    retrievalStatus: PlantaoRetrievalStatus.complete,
  );
}

void main() {
  test('exact deterministic evidence validates and preserves concomitant', () {
    final outcome = PlantaoDeterministicDrugValidator.validate(
      candidates: <PlantaoMedicationCandidate>[candidate()],
      evidenceBundle: evidence(),
    );
    expect(outcome.status, PlantaoDeterministicValidationStatus.validated);
    expect(outcome.validatedDose, isTrue);
    expect(outcome.medications, hasLength(1));
    expect(
      outcome.medications.single.relation,
      PlantaoDrugRelationType.concomitant,
    );
    expect(outcome.medications.single.drugDocumentId, 'drug-aas-v1');
  });

  test('dose mismatch blocks all medication typing', () {
    final outcome = PlantaoDeterministicDrugValidator.validate(
      candidates: <PlantaoMedicationCandidate>[candidate(dose: 100)],
      evidenceBundle: evidence(dose: 300),
    );
    expect(outcome.status, PlantaoDeterministicValidationStatus.blocked);
    expect(outcome.medications, isEmpty);
    expect(outcome.reasons.single, contains('mismatch'));
  });

  test('candidate without deterministic evidence remains incomplete', () {
    final outcome = PlantaoDeterministicDrugValidator.validate(
      candidates: <PlantaoMedicationCandidate>[candidate()],
      evidenceBundle: PlantaoEvidenceBundle.empty(),
    );
    expect(
      outcome.status,
      PlantaoDeterministicValidationStatus.incompleteEvidence,
    );
    expect(outcome.medications, isEmpty);
  });

  test('no typed candidate is not evaluated and never parsed from text', () {
    final outcome = PlantaoDeterministicDrugValidator.validate(
      candidates: const <PlantaoMedicationCandidate>[],
      evidenceBundle: evidence(),
    );
    expect(outcome.status, PlantaoDeterministicValidationStatus.notEvaluated);
    expect(outcome.medications, isEmpty);
  });
}
