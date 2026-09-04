import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_provenance.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_request.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_identity_provenance_binding_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_provenance_persistence_payload_parity_gate_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_provenance_persistence_payload_shadow_adapter.dart';
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

void main() {
  const adapter = PlantaoDrugProvenanceSemanticEqualityGateShadowAdapter();

  test('verifies complete provenance semantic equality', () {
    final snapshot = adapter.verify(
      request: request('req-semantic'),
      baseFuturePersistenceEligible: false,
      preparedPayload: prepared('req-semantic'),
      parity: parity('req-semantic'),
      binding: binding('req-semantic'),
    );

    expect(
      snapshot.status,
      PlantaoDrugProvenanceSemanticEqualityStatus.semanticEqualityVerified,
    );
    expect(snapshot.semanticEqualityVerified, isTrue);
    expect(snapshot.mismatchPaths, isEmpty);
    expect(
      snapshot.comparedProvenanceKeys,
      containsAll(<String>[
        'provider',
        'model',
        'sourceMode',
        'matchedClinicalDocumentIds',
        'matchedDrugDocumentIds',
        'validatedDose',
        'validatorReason',
        'usedExternalGrounding',
        'continuationType',
        'documentVersions',
      ]),
    );
  });

  test('rejects a wrong source mode despite structural parity', () {
    final good = prepared('req-source-mode');
    final provenance = Map<String, Object?>.from(
      good.payload['provenance']! as Map,
    )..['sourceMode'] = 'mixed';
    final mutated = PlantaoDrugProvenancePersistencePayloadShadowSnapshot(
      requestId: 'req-source-mode',
      status: PlantaoDrugProvenancePersistencePayloadStatus.payloadPrepared,
      payload: <String, Object?>{...good.payload, 'provenance': provenance},
      baseFuturePersistenceEligible: false,
      reasons: good.reasons,
      observedAt: DateTime.utc(2026, 7, 27),
    );

    final snapshot = adapter.verify(
      request: request('req-source-mode'),
      baseFuturePersistenceEligible: false,
      preparedPayload: mutated,
      parity: parity('req-source-mode'),
      binding: binding('req-source-mode'),
    );

    expect(
      snapshot.status,
      PlantaoDrugProvenanceSemanticEqualityStatus.semanticMismatch,
    );
    expect(snapshot.mismatchPaths, contains('provenance.sourceMode'));
  });

  test('rejects a wrong validator reason', () {
    final good = prepared('req-reason');
    final provenance = Map<String, Object?>.from(
      good.payload['provenance']! as Map,
    )..['validatorReason'] = 'incorrect_reason';
    final mutated = PlantaoDrugProvenancePersistencePayloadShadowSnapshot(
      requestId: 'req-reason',
      status: PlantaoDrugProvenancePersistencePayloadStatus.payloadPrepared,
      payload: <String, Object?>{...good.payload, 'provenance': provenance},
      baseFuturePersistenceEligible: false,
      reasons: good.reasons,
      observedAt: DateTime.utc(2026, 7, 27),
    );

    final snapshot = adapter.verify(
      request: request('req-reason'),
      baseFuturePersistenceEligible: false,
      preparedPayload: mutated,
      parity: parity('req-reason'),
      binding: binding('req-reason'),
    );

    expect(
      snapshot.status,
      PlantaoDrugProvenanceSemanticEqualityStatus.semanticMismatch,
    );
    expect(snapshot.mismatchPaths, contains('provenance.validatorReason'));
  });

  test('rejects missing canonical document version', () {
    final good = prepared('req-version');
    final provenance = Map<String, Object?>.from(
      good.payload['provenance']! as Map,
    );
    final versions = Map<String, Object?>.from(
      provenance['documentVersions']! as Map,
    )..remove('furosemida');
    provenance['documentVersions'] = versions;
    final mutated = PlantaoDrugProvenancePersistencePayloadShadowSnapshot(
      requestId: 'req-version',
      status: PlantaoDrugProvenancePersistencePayloadStatus.payloadPrepared,
      payload: <String, Object?>{...good.payload, 'provenance': provenance},
      baseFuturePersistenceEligible: false,
      reasons: good.reasons,
      observedAt: DateTime.utc(2026, 7, 27),
    );

    final snapshot = adapter.verify(
      request: request('req-version'),
      baseFuturePersistenceEligible: false,
      preparedPayload: mutated,
      parity: parity('req-version'),
      binding: binding('req-version'),
    );

    expect(
      snapshot.status,
      PlantaoDrugProvenanceSemanticEqualityStatus.semanticMismatch,
    );
    expect(
      snapshot.mismatchPaths,
      contains('provenance.documentVersions.furosemida:missing'),
    );
  });

  test('parity failure blocks semantic approval', () {
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

    final snapshot = adapter.verify(
      request: request('req-parity-blocked'),
      baseFuturePersistenceEligible: false,
      preparedPayload: prepared('req-parity-blocked'),
      parity: blockedParity,
      binding: binding('req-parity-blocked'),
    );

    expect(
      snapshot.status,
      PlantaoDrugProvenanceSemanticEqualityStatus.parityNotVerified,
    );
    expect(snapshot.semanticEqualityVerified, isFalse);
  });
}
