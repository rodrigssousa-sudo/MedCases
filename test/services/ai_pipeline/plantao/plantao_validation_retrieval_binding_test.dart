import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_evidence_bundle.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_request.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_finalization_shadow_snapshot.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_validation_shadow_adapter.dart';

void main() {
  test('protocol evidence reaches provenance as matched clinical evidence', () {
    final request = PlantaoRequest(
      requestId: 'req-protocol-binding',
      sessionId: 'session-protocol-binding',
      question: 'Conduta no IAM com supra',
      language: PlantaoLanguage.ptBr,
      trigger: PlantaoRequestTrigger.userInput,
      continuationType: PlantaoContinuationType.initial,
      requestedSections: const [],
      strictClinicalMode: true,
    );
    final finalization = PlantaoFinalizationShadowSnapshot(
      requestId: request.requestId,
      status: PlantaoFinalizationShadowStatus.structured,
      rawText: 'Resposta observada',
      sanitizedText: 'Resposta observada',
      canonicalStatus: 'ready',
      usedBackendStructuredOutput: false,
      usedLocalClinicalAdapter: true,
      usedPlantaoParser: true,
      deferredMedicationCount: 0,
      missingRequestedSections: const [],
      observedAt: DateTime.utc(2026, 7, 27),
    );
    final protocol = PlantaoEvidenceDocument(
      documentId: 'protocol:iam_congestao',
      version: 'legacy_protocols_database_v1',
      kind: PlantaoEvidenceKind.protocol,
      excerpt: 'Síndrome Coronariana Aguda',
    );
    final evidence = PlantaoEvidenceBundle(
      clinicalDocuments: const [],
      drugDocuments: const [],
      protocolDocuments: [protocol],
      patientFacts: const [],
      caseEvidence: const [],
      externalGrounding: const [],
      documentVersions: const {
        'protocol:iam_congestao': 'legacy_protocols_database_v1',
      },
      coverage: const PlantaoEvidenceCoverage(
        hasClinical: false,
        hasDrug: false,
        hasProtocol: true,
        hasPatientFacts: false,
      ),
      missingRequirements: const ['drug_retrieval_not_connected'],
      retrievalStatus: PlantaoRetrievalStatus.partial,
    );

    const adapter = PlantaoValidationShadowAdapter();
    final snapshot = adapter.validate(
      request: request,
      finalization: finalization,
      evidenceBundle: evidence,
    );

    expect(snapshot.provenance.sourceMode.name, 'localRag');
    expect(snapshot.provenance.matchedClinicalDocumentIds, [
      'protocol:iam_congestao',
    ]);
    expect(snapshot.provenance.matchedDrugDocumentIds, isEmpty);
    expect(snapshot.reasons, contains('drug_retrieval_not_connected'));
    expect(
      snapshot.provenance.validatorReason,
      contains('drug_retrieval_not_connected'),
    );
    expect(
      snapshot.provenance.documentVersions['protocol:iam_congestao'],
      'legacy_protocols_database_v1',
    );
    expect(snapshot.strictModeCompatible, isTrue);
  });
}
