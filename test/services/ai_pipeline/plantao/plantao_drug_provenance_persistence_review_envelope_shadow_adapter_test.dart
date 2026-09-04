import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_provenance.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_request.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_identity_provenance_binding_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_provenance_persistence_payload_parity_gate_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_provenance_persistence_payload_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_provenance_persistence_review_envelope_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_provenance_semantic_equality_gate_shadow_adapter.dart';

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

PlantaoDrugIdentityProvenanceBindingShadowSnapshot binding(String id) {
  final provenance = PlantaoProvenance(
    provider: 'shadow_route_plan_not_executed',
    model: 'unexecuted',
    sourceMode: PlantaoSourceMode.localRag,
    matchedClinicalDocumentIds: const <String>['protocol:icfer'],
    matchedDrugDocumentIds: const <String>['furosemida'],
    validatedDose: false,
    validatorReason:
        'canonical_drug_identity_provenance_bound;typed_regimen_unavailable',
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
    typedRegimenDocumentIds: const <String>[],
    documentVersions: const <String, String>{
      'furosemida': 'clinical-data-v1-test',
    },
    reasons: const <String>[
      'canonical_drug_identity_provenance_bound',
      'typed_regimen_unavailable',
    ],
    observedAt: DateTime.utc(2026, 7, 27),
  );
}

Map<String, Object?> basePayload(String id) => <String, Object?>{
  'schemaVersion': 1,
  'requestId': id,
  'sessionId': 'session-$id',
  'status': 'blocked',
  'validationStatus': 'notEvaluated',
  'rawText': 'Resposta observada',
  'sanitizedText': 'Resposta observada',
  'structure': null,
  'medications': <Object?>[],
  'provenance': <String, Object?>{
    'provider': 'shadow_route_plan_not_executed',
    'model': 'unexecuted',
    'sourceMode': 'modelNative',
    'matchedClinicalDocumentIds': <Object?>['protocol:icfer'],
    'matchedDrugDocumentIds': <Object?>[],
    'validatedDose': false,
    'validatorReason': 'typed_medication_candidates_absent',
    'usedExternalGrounding': false,
    'continuationType': 'initial',
    'documentVersions': <String, Object?>{
      'protocol:icfer': 'legacy_protocols_database_v1',
    },
  },
  'reasons': <Object?>['typed_medication_candidates_absent'],
  'observedAt': '2026-07-27T00:00:00.000Z',
};

PlantaoDrugProvenancePersistencePayloadShadowSnapshot prepared(String id) =>
    const PlantaoDrugProvenancePersistencePayloadShadowAdapter().prepare(
      request: request(id),
      basePersistencePayload: basePayload(id),
      baseFuturePersistenceEligible: false,
      binding: binding(id),
    );

PlantaoDrugProvenancePersistencePayloadParityShadowSnapshot parity(String id) =>
    const PlantaoDrugProvenancePersistencePayloadParityGateShadowAdapter()
        .verify(
          request: request(id),
          basePersistencePayload: basePayload(id),
          baseFuturePersistenceEligible: false,
          preparedPayload: prepared(id),
          binding: binding(id),
        );

PlantaoDrugProvenanceSemanticEqualityShadowSnapshot semantic(String id) =>
    const PlantaoDrugProvenanceSemanticEqualityGateShadowAdapter().verify(
      request: request(id),
      baseFuturePersistenceEligible: false,
      preparedPayload: prepared(id),
      parity: parity(id),
      binding: binding(id),
    );

void main() {
  const adapter = PlantaoDrugProvenancePersistenceReviewEnvelopeShadowAdapter();

  test('prepares an immutable review envelope without write eligibility', () {
    final snapshot = adapter.prepare(
      request: request('req-review'),
      baseFuturePersistenceEligible: false,
      preparedPayload: prepared('req-review'),
      parity: parity('req-review'),
      semanticEquality: semantic('req-review'),
    );

    expect(
      snapshot.status,
      PlantaoDrugProvenancePersistenceReviewEnvelopeStatus
          .reviewEnvelopePrepared,
    );
    expect(snapshot.reviewEnvelopePrepared, isTrue);
    expect(snapshot.baseFuturePersistenceEligible, isFalse);
    expect(snapshot.payload['requestId'], 'req-review');
    expect(
      PlantaoDrugProvenancePersistenceReviewEnvelopeShadowSnapshot
          .writeEligible,
      isFalse,
    );
    expect(() => snapshot.payload['status'] = 'ready', throwsUnsupportedError);
    final provenance = snapshot.payload['provenance']! as Map<Object?, Object?>;
    expect(() => provenance['sourceMode'] = 'mixed', throwsUnsupportedError);
  });

  test('semantic mismatch blocks the review envelope', () {
    final blockedSemantic = PlantaoDrugProvenanceSemanticEqualityShadowSnapshot(
      requestId: 'req-semantic-blocked',
      status: PlantaoDrugProvenanceSemanticEqualityStatus.semanticMismatch,
      baseFuturePersistenceEligible: false,
      comparedProvenanceKeys: const <String>['sourceMode'],
      mismatchPaths: const <String>['provenance.sourceMode'],
      reasons: const <String>['canonical_drug_provenance_semantic_mismatch'],
      observedAt: DateTime.utc(2026, 7, 27),
    );

    final snapshot = adapter.prepare(
      request: request('req-semantic-blocked'),
      baseFuturePersistenceEligible: false,
      preparedPayload: prepared('req-semantic-blocked'),
      parity: parity('req-semantic-blocked'),
      semanticEquality: blockedSemantic,
    );

    expect(
      snapshot.status,
      PlantaoDrugProvenancePersistenceReviewEnvelopeStatus
          .semanticEqualityNotVerified,
    );
    expect(snapshot.reviewEnvelopePrepared, isFalse);
    expect(snapshot.payload, isEmpty);
  });

  test('parity failure blocks the review envelope', () {
    final blockedParity =
        PlantaoDrugProvenancePersistencePayloadParityShadowSnapshot(
          requestId: 'req-parity-blocked',
          status: PlantaoDrugProvenancePersistencePayloadParityStatus
              .unexpectedMutation,
          baseFuturePersistenceEligible: false,
          changedTopLevelKeys: const <String>['status'],
          changedProvenanceKeys: const <String>[],
          unexpectedPaths: const <String>['topLevel:status'],
          reasons: const <String>[
            'canonical_drug_provenance_payload_unexpected_mutation',
          ],
          observedAt: DateTime.utc(2026, 7, 27),
        );

    final snapshot = adapter.prepare(
      request: request('req-parity-blocked'),
      baseFuturePersistenceEligible: false,
      preparedPayload: prepared('req-parity-blocked'),
      parity: blockedParity,
      semanticEquality: semantic('req-parity-blocked'),
    );

    expect(
      snapshot.status,
      PlantaoDrugProvenancePersistenceReviewEnvelopeStatus.parityNotVerified,
    );
    expect(snapshot.payload, isEmpty);
  });

  test('eligibility mismatch blocks the review envelope', () {
    final snapshot = adapter.prepare(
      request: request('req-eligibility'),
      baseFuturePersistenceEligible: true,
      preparedPayload: prepared('req-eligibility'),
      parity: parity('req-eligibility'),
      semanticEquality: semantic('req-eligibility'),
    );

    expect(
      snapshot.status,
      PlantaoDrugProvenancePersistenceReviewEnvelopeStatus.eligibilityMismatch,
    );
    expect(snapshot.payload, isEmpty);
  });

  test('stale request chain is rejected', () {
    final snapshot = adapter.prepare(
      request: request('req-current'),
      baseFuturePersistenceEligible: false,
      preparedPayload: prepared('req-old'),
      parity: parity('req-old'),
      semanticEquality: semantic('req-old'),
    );

    expect(
      snapshot.status,
      PlantaoDrugProvenancePersistenceReviewEnvelopeStatus.stale,
    );
    expect(snapshot.payload, isEmpty);
  });
}
