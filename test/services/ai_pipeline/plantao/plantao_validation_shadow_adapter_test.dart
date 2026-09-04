import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_drug_relation.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_evidence_bundle.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_request.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_section.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_deterministic_drug_validator.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_finalization_shadow_snapshot.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_validation_shadow_adapter.dart';

PlantaoRequest request() => PlantaoRequest(
      requestId: 'req-validation',
      sessionId: 'session-1',
      question: 'Conduta na síndrome coronariana aguda',
      language: PlantaoLanguage.ptBr,
      trigger: PlantaoRequestTrigger.userInput,
      continuationType: PlantaoContinuationType.initial,
      requestedSections: const <PlantaoSection>[],
    );

PlantaoFinalizationShadowSnapshot finalization({int deferred = 1}) {
  return PlantaoFinalizationShadowSnapshot(
    requestId: 'req-validation',
    status: PlantaoFinalizationShadowStatus.structured,
    rawText: 'texto produtivo',
    sanitizedText: 'texto produtivo',
    canonicalStatus: 'ready',
    usedBackendStructuredOutput: true,
    usedLocalClinicalAdapter: false,
    usedPlantaoParser: true,
    deferredMedicationCount: deferred,
    missingRequestedSections: const <String>[],
    observedAt: DateTime.utc(2026, 7, 26),
  );
}

PlantaoEvidenceBundle evidence() {
  final document = PlantaoDrugEvidenceDocument(
    documentId: 'drug-ticagrelor-v1',
    version: '1.0.0',
    excerpt: 'Ticagrelor 180 mg VO em dose de ataque.',
    drugName: 'Ticagrelor',
    dose: 180,
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
    documentVersions: const <String, String>{},
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
  test('without retrieval, deferred medication remains incomplete and untyped', () {
    const adapter = PlantaoValidationShadowAdapter();
    final snapshot = adapter.observeWithoutRetrieval(
      request: request(),
      finalization: finalization(),
    );
    expect(snapshot.status, PlantaoValidationShadowStatus.incompleteEvidence);
    expect(snapshot.medications, isEmpty);
    expect(snapshot.strictModeCompatible, isFalse);
    expect(snapshot.provenance.validatedDose, isFalse);
    expect(
      snapshot.routePlan.attempts.map((item) => item.provider.name).toList(),
      const <String>['gptPaid', 'geminiPaid'],
    );
  });

  test('typed candidate and exact evidence generate validated provenance', () {
    const adapter = PlantaoValidationShadowAdapter();
    final snapshot = adapter.validate(
      request: request(),
      finalization: finalization(),
      evidenceBundle: evidence(),
      candidates: const <PlantaoMedicationCandidate>[
        PlantaoMedicationCandidate(
          drugName: 'Ticagrelor',
          relation: PlantaoDrugRelationType.concomitant,
          indication: 'Síndrome coronariana aguda',
          dose: 180,
          unit: 'mg',
          route: 'VO',
          frequency: 'dose de ataque',
        ),
      ],
    );
    expect(snapshot.status, PlantaoValidationShadowStatus.validated);
    expect(snapshot.medications, hasLength(1));
    expect(snapshot.provenance.validatedDose, isTrue);
    expect(snapshot.provenance.matchedDrugDocumentIds, ['drug-ticagrelor-v1']);
    expect(snapshot.provenance.documentVersions['drug-ticagrelor-v1'], '1.0.0');
    expect(snapshot.strictModeCompatible, isTrue);
  });
}
