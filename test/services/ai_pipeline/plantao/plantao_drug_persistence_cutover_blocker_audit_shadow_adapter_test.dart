import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_provenance.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_request.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_identity_provenance_binding_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_persistence_cutover_blocker_audit_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_provenance_persistence_review_envelope_shadow_adapter.dart';

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

PlantaoDrugIdentityProvenanceBindingShadowSnapshot binding(
  String id, {
  bool typedRegimenAvailable = false,
  bool validatedDose = false,
}) {
  final provenance = PlantaoProvenance(
    provider: 'shadow_route_plan_not_executed',
    model: 'unexecuted',
    sourceMode: PlantaoSourceMode.localRag,
    matchedClinicalDocumentIds: const <String>['protocol:icfer'],
    matchedDrugDocumentIds: const <String>['furosemida'],
    validatedDose: validatedDose,
    validatorReason: typedRegimenAvailable
        ? 'canonical_drug_identity_provenance_bound'
        : 'canonical_drug_identity_provenance_bound;typed_regimen_unavailable',
    usedExternalGrounding: false,
    continuationType: PlantaoContinuationType.initial,
    documentVersions: const <String, String>{
      'protocol:icfer': 'legacy_protocols_database_v1',
      'furosemida': 'clinical-data-v1-test',
    },
  );
  return PlantaoDrugIdentityProvenanceBindingShadowSnapshot(
    requestId: id,
    status: PlantaoDrugIdentityProvenanceBindingStatus.identityEvidenceBound,
    provenance: provenance,
    canonicalDocumentIds: const <String>['furosemida'],
    typedRegimenDocumentIds: typedRegimenAvailable
        ? const <String>['furosemida']
        : const <String>[],
    documentVersions: const <String, String>{
      'furosemida': 'clinical-data-v1-test',
    },
    reasons: typedRegimenAvailable
        ? const <String>['canonical_drug_identity_provenance_bound']
        : const <String>[
            'canonical_drug_identity_provenance_bound',
            'typed_regimen_unavailable',
          ],
    observedAt: DateTime.utc(2026, 7, 27),
  );
}

PlantaoDrugProvenancePersistenceReviewEnvelopeShadowSnapshot reviewEnvelope(
  String id, {
  bool baseEligible = false,
  bool validatedDose = false,
  bool materializedMedication = false,
  bool recordReady = false,
}) {
  return PlantaoDrugProvenancePersistenceReviewEnvelopeShadowSnapshot(
    requestId: id,
    status: PlantaoDrugProvenancePersistenceReviewEnvelopeStatus
        .reviewEnvelopePrepared,
    payload: <String, Object?>{
      'requestId': id,
      'status': recordReady ? 'ready' : 'blocked',
      'medications': materializedMedication
          ? <Object?>[
              <String, Object?>{'drugName': 'furosemida'},
            ]
          : <Object?>[],
      'provenance': <String, Object?>{
        'matchedDrugDocumentIds': <Object?>['furosemida'],
        'validatedDose': validatedDose,
      },
    },
    baseFuturePersistenceEligible: baseEligible,
    reasons: const <String>[
      'canonical_drug_provenance_review_envelope_prepared',
    ],
    observedAt: DateTime.utc(2026, 7, 27),
  );
}

void main() {
  const adapter = PlantaoDrugPersistenceCutoverBlockerAuditShadowAdapter();

  test('records the current canonical pharmacology cutover blockers', () {
    final snapshot = adapter.audit(
      request: request('req-blockers'),
      baseFuturePersistenceEligible: false,
      reviewEnvelope: reviewEnvelope('req-blockers'),
      binding: binding('req-blockers'),
    );

    expect(
      snapshot.status,
      PlantaoDrugPersistenceCutoverBlockerAuditStatus.blockersRecorded,
    );
    expect(snapshot.blockersRecorded, isTrue);
    expect(snapshot.hasCanonicalDrugEvidence, isTrue);
    expect(snapshot.hasTypedRegimenEvidence, isFalse);
    expect(snapshot.validatedDose, isFalse);
    expect(snapshot.hasMaterializedMedications, isFalse);
    expect(snapshot.persistenceRecordReady, isFalse);
    expect(
      snapshot.blockers,
      containsAll(<String>[
        'base_persistence_not_eligible',
        'typed_regimen_evidence_absent',
        'dose_not_deterministically_validated',
        'medication_materialization_absent',
        'persistence_record_not_ready',
        'productive_cutover_not_authorized',
      ]),
    );
  });

  test('even complete observed preconditions never authorize cutover', () {
    final snapshot = adapter.audit(
      request: request('req-complete'),
      baseFuturePersistenceEligible: true,
      reviewEnvelope: reviewEnvelope(
        'req-complete',
        baseEligible: true,
        validatedDose: true,
        materializedMedication: true,
        recordReady: true,
      ),
      binding: binding(
        'req-complete',
        typedRegimenAvailable: true,
        validatedDose: true,
      ),
    );

    expect(snapshot.blockers, ['productive_cutover_not_authorized']);
    expect(snapshot.hasTypedRegimenEvidence, isTrue);
    expect(snapshot.validatedDose, isTrue);
    expect(snapshot.hasMaterializedMedications, isTrue);
    expect(snapshot.persistenceRecordReady, isTrue);
    expect(
      PlantaoDrugPersistenceCutoverBlockerAuditShadowSnapshot
          .cutoverReadinessGranted,
      isFalse,
    );
    expect(
      PlantaoDrugPersistenceCutoverBlockerAuditShadowSnapshot.cutoverAuthorized,
      isFalse,
    );
  });

  test('unprepared review envelope blocks the audit', () {
    final unprepared =
        PlantaoDrugProvenancePersistenceReviewEnvelopeShadowSnapshot(
          requestId: 'req-unprepared',
          status: PlantaoDrugProvenancePersistenceReviewEnvelopeStatus
              .semanticEqualityNotVerified,
          payload: const <String, Object?>{},
          baseFuturePersistenceEligible: false,
          reasons: const <String>[
            'drug_provenance_review_envelope_semantic_equality_not_verified',
          ],
          observedAt: DateTime.utc(2026, 7, 27),
        );

    final snapshot = adapter.audit(
      request: request('req-unprepared'),
      baseFuturePersistenceEligible: false,
      reviewEnvelope: unprepared,
      binding: binding('req-unprepared'),
    );

    expect(
      snapshot.status,
      PlantaoDrugPersistenceCutoverBlockerAuditStatus.reviewEnvelopeNotPrepared,
    );
    expect(snapshot.blockers, isEmpty);
  });

  test('stale request chain is rejected', () {
    final snapshot = adapter.audit(
      request: request('req-current'),
      baseFuturePersistenceEligible: false,
      reviewEnvelope: reviewEnvelope('req-old'),
      binding: binding('req-old'),
    );

    expect(
      snapshot.status,
      PlantaoDrugPersistenceCutoverBlockerAuditStatus.stale,
    );
  });

  test('binding mismatch is rejected', () {
    final mismatchedBinding =
        PlantaoDrugIdentityProvenanceBindingShadowSnapshot(
          requestId: 'req-binding',
          status:
              PlantaoDrugIdentityProvenanceBindingStatus.identityEvidenceBound,
          provenance: PlantaoProvenance(
            provider: 'shadow_route_plan_not_executed',
            model: 'unexecuted',
            sourceMode: PlantaoSourceMode.localRag,
            matchedClinicalDocumentIds: const <String>[],
            matchedDrugDocumentIds: const <String>['outro-farmaco'],
            validatedDose: false,
            validatorReason: 'canonical_drug_identity_provenance_bound',
            usedExternalGrounding: false,
            continuationType: PlantaoContinuationType.initial,
            documentVersions: const <String, String>{},
          ),
          canonicalDocumentIds: const <String>['outro-farmaco'],
          typedRegimenDocumentIds: const <String>[],
          documentVersions: const <String, String>{},
          reasons: const <String>['canonical_drug_identity_provenance_bound'],
          observedAt: DateTime.utc(2026, 7, 27),
        );

    final snapshot = adapter.audit(
      request: request('req-binding'),
      baseFuturePersistenceEligible: false,
      reviewEnvelope: reviewEnvelope('req-binding'),
      binding: mismatchedBinding,
    );

    expect(
      snapshot.status,
      PlantaoDrugPersistenceCutoverBlockerAuditStatus.bindingMismatch,
    );
  });
}
