import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_canonical_drug_evidence.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_provenance.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_request.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_evidence_finalization_join_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_evidence_request_observer.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_evidence_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_identity_provenance_binding_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_original_input_identity_extractor.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_persistence_cutover_blocker_audit_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_typed_regimen_capability_matrix_shadow_adapter.dart';

const version = 'clinical-data-v1-regimen-matrix-test';
const bundleSha =
    '8888888888888888888888888888888888888888888888888888888888888888';

PlantaoRequest request(String id) => PlantaoRequest(
  requestId: id,
  sessionId: 'session-$id',
  question: 'Qual a dose da furosemida?',
  language: PlantaoLanguage.ptBr,
  trigger: PlantaoRequestTrigger.userInput,
  continuationType: PlantaoContinuationType.initial,
  requestedSections: const [],
  strictClinicalMode: true,
);

PlantaoDrugEvidenceManifest manifest() =>
    PlantaoDrugEvidenceManifest.fromJson(<String, Object?>{
      'version': version,
      'contentSha256': bundleSha,
      'identitySchema': 'clinical-source-content-v1',
      'drugCount': 1,
      'interactionCount': 0,
      'collisionCount': 0,
      'exportErrors': 0,
      'endpoints': <String, Object?>{
        'manifest': '/data/manifest.json',
        'drugsIndex': '/data/drugs_index.json',
        'drugById': '/data/drugs/{id}.json',
      },
    });

PlantaoCanonicalDrugEvidenceDocument rawDocument() =>
    PlantaoCanonicalDrugEvidenceDocument.fromJson(<String, Object?>{
      'id': 'furosemida',
      'category': 'cardio',
      'name': <String, Object?>{'pt': 'Furosemida', 'es': 'Furosemida'},
      'keywords': <Object?>['furosemida'],
      'dataVersion': version,
      'clinicalContentSha256': bundleSha,
      'source': 'medcases-calculadora',
      'schema': 'premium-v1',
      'sourceModule': 'cardio.js',
      'pt': <String, Object?>{'dose': '20–40 mg em texto clínico'},
      'es': <String, Object?>{'dose': '20–40 mg en texto clínico'},
    }, manifest: manifest());

PlantaoDrugEvidenceFinalizationJoinShadowSnapshot readyJoin(String id) {
  final evidence = PlantaoDrugEvidenceShadowSnapshot(
    status: PlantaoDrugEvidenceShadowStatus.complete,
    manifest: manifest(),
    candidates: const <PlantaoCanonicalDrugCandidate>[
      PlantaoCanonicalDrugCandidate(
        documentId: 'furosemida',
        canonicalName: 'Furosemida',
        matchedValue: 'furosemida',
        matchKind: PlantaoDrugIdentityMatchKind.exactId,
        schema: PlantaoCanonicalDrugSchema.premiumV1,
        sourceModule: 'cardio.js',
        hasContextVariants: false,
      ),
    ],
    documents: <PlantaoCanonicalDrugEvidenceDocument>[rawDocument()],
    reasons: const <String>['canonical_identity_resolved'],
    observedAt: DateTime.utc(2026, 7, 27),
  );
  final requestSnapshot = PlantaoDrugEvidenceRequestSnapshot(
    requestId: id,
    status: PlantaoDrugEvidenceRequestStatus.ready,
    intent: PlantaoDrugOriginalInputIntent.dosage,
    evidence: evidence,
    reasons: evidence.reasons,
    observedAt: DateTime.utc(2026, 7, 27),
  );
  return PlantaoDrugEvidenceFinalizationJoinShadowSnapshot(
    requestId: id,
    status: PlantaoDrugEvidenceFinalizationJoinStatus.ready,
    drugEvidence: requestSnapshot,
    candidateDocumentIds: const <String>['furosemida'],
    evidenceDocumentIds: const <String>['furosemida'],
    documentVersions: const <String, String>{'furosemida': version},
    reasons: const <String>['request_scoped_drug_evidence_join_completed'],
    observedAt: DateTime.utc(2026, 7, 27),
  );
}

PlantaoDrugIdentityProvenanceBindingShadowSnapshot binding(
  String id,
) => PlantaoDrugIdentityProvenanceBindingShadowSnapshot(
  requestId: id,
  status: PlantaoDrugIdentityProvenanceBindingStatus.identityEvidenceBound,
  provenance: PlantaoProvenance(
    provider: 'shadow_route_plan_not_executed',
    model: 'unexecuted',
    sourceMode: PlantaoSourceMode.localRag,
    matchedClinicalDocumentIds: const <String>[],
    matchedDrugDocumentIds: const <String>['furosemida'],
    validatedDose: false,
    validatorReason:
        'canonical_drug_identity_provenance_bound;typed_regimen_unavailable',
    usedExternalGrounding: false,
    continuationType: PlantaoContinuationType.initial,
    documentVersions: const <String, String>{'furosemida': version},
  ),
  canonicalDocumentIds: const <String>['furosemida'],
  typedRegimenDocumentIds: const <String>[],
  documentVersions: const <String, String>{'furosemida': version},
  reasons: const <String>[
    'canonical_drug_identity_provenance_bound',
    'typed_regimen_unavailable',
  ],
  observedAt: DateTime.utc(2026, 7, 27),
);

PlantaoDrugPersistenceCutoverBlockerAuditShadowSnapshot blockerAudit(
  String id,
) => PlantaoDrugPersistenceCutoverBlockerAuditShadowSnapshot(
  requestId: id,
  status: PlantaoDrugPersistenceCutoverBlockerAuditStatus.blockersRecorded,
  baseFuturePersistenceEligible: false,
  hasCanonicalDrugEvidence: true,
  hasTypedRegimenEvidence: false,
  validatedDose: false,
  hasMaterializedMedications: false,
  persistenceRecordReady: false,
  blockers: const <String>[
    'typed_regimen_evidence_absent',
    'productive_cutover_not_authorized',
  ],
  reasons: const <String>[
    'canonical_drug_persistence_cutover_blockers_recorded',
  ],
  observedAt: DateTime.utc(2026, 7, 27),
);

void main() {
  const adapter = PlantaoDrugTypedRegimenCapabilityMatrixShadowAdapter();

  test('records the raw canonical document as non-materializable', () {
    final snapshot = adapter.audit(
      request: request('req-matrix'),
      join: readyJoin('req-matrix'),
      binding: binding('req-matrix'),
      cutoverBlockerAudit: blockerAudit('req-matrix'),
    );

    expect(
      snapshot.status,
      PlantaoDrugTypedRegimenCapabilityMatrixStatus.capabilityMatrixRecorded,
    );
    expect(snapshot.capabilityMatrixRecorded, isTrue);
    expect(snapshot.canonicalDocumentCount, 1);
    expect(snapshot.typedRegimenCapableCount, 0);
    expect(snapshot.typedRegimenBoundCount, 0);

    final entry = snapshot.entries.single;
    expect(entry.documentId, 'furosemida');
    expect(entry.documentVersion, version);
    expect(entry.boundAsCanonicalIdentity, isTrue);
    expect(entry.boundAsTypedRegimen, isFalse);
    expect(entry.supportsMedicationMaterialization, isFalse);
    expect(entry.gaps, contains('typed_regimen_contract_unavailable'));
    expect(
      snapshot.unresolvedGaps,
      contains('furosemida:typed_regimen_contract_unavailable'),
    );
  });

  test('an unrecorded blocker audit prevents the matrix', () {
    final unrecorded = PlantaoDrugPersistenceCutoverBlockerAuditShadowSnapshot(
      requestId: 'req-unrecorded',
      status: PlantaoDrugPersistenceCutoverBlockerAuditStatus
          .reviewEnvelopeNotPrepared,
      baseFuturePersistenceEligible: false,
      hasCanonicalDrugEvidence: false,
      hasTypedRegimenEvidence: false,
      validatedDose: false,
      hasMaterializedMedications: false,
      persistenceRecordReady: false,
      blockers: const <String>[],
      reasons: const <String>[
        'drug_persistence_cutover_blocker_audit_review_not_prepared',
      ],
      observedAt: DateTime.utc(2026, 7, 27),
    );

    final snapshot = adapter.audit(
      request: request('req-unrecorded'),
      join: readyJoin('req-unrecorded'),
      binding: binding('req-unrecorded'),
      cutoverBlockerAudit: unrecorded,
    );

    expect(
      snapshot.status,
      PlantaoDrugTypedRegimenCapabilityMatrixStatus.blockerAuditNotRecorded,
    );
    expect(snapshot.entries, isEmpty);
  });

  test('a non-ready join prevents the matrix', () {
    final emptyJoin = PlantaoDrugEvidenceFinalizationJoinShadowSnapshot(
      requestId: 'req-empty',
      status: PlantaoDrugEvidenceFinalizationJoinStatus.empty,
      drugEvidence: null,
      candidateDocumentIds: const <String>[],
      evidenceDocumentIds: const <String>[],
      documentVersions: const <String, String>{},
      reasons: const <String>['canonical_drug_identity_not_found'],
      observedAt: DateTime.utc(2026, 7, 27),
    );

    final snapshot = adapter.audit(
      request: request('req-empty'),
      join: emptyJoin,
      binding: binding('req-empty'),
      cutoverBlockerAudit: blockerAudit('req-empty'),
    );

    expect(
      snapshot.status,
      PlantaoDrugTypedRegimenCapabilityMatrixStatus.joinNotReady,
    );
    expect(snapshot.entries, isEmpty);
  });

  test('a stale request chain is rejected', () {
    final snapshot = adapter.audit(
      request: request('req-current'),
      join: readyJoin('req-old'),
      binding: binding('req-old'),
      cutoverBlockerAudit: blockerAudit('req-old'),
    );

    expect(
      snapshot.status,
      PlantaoDrugTypedRegimenCapabilityMatrixStatus.stale,
    );
  });

  test('typed regimen inference and cutover remain disabled', () {
    expect(
      PlantaoDrugTypedRegimenCapabilityMatrixShadowSnapshot
          .freeTextDoseExtractionEnabled,
      isFalse,
    );
    expect(
      PlantaoDrugTypedRegimenCapabilityMatrixShadowSnapshot
          .freeTextRouteExtractionEnabled,
      isFalse,
    );
    expect(
      PlantaoDrugTypedRegimenCapabilityMatrixShadowSnapshot
          .freeTextFrequencyExtractionEnabled,
      isFalse,
    );
    expect(
      PlantaoDrugTypedRegimenCapabilityMatrixShadowSnapshot
          .inferredTypedRegimenEnabled,
      isFalse,
    );
    expect(
      PlantaoDrugTypedRegimenCapabilityMatrixShadowSnapshot.cutoverAuthorized,
      isFalse,
    );
  });
}
