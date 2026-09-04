import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_provenance.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_request.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_identity_provenance_binding_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_provenance_persistence_payload_parity_gate_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_provenance_persistence_payload_shadow_adapter.dart';

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

PlantaoDrugProvenancePersistencePayloadShadowSnapshot prepared(String id) {
  return const PlantaoDrugProvenancePersistencePayloadShadowAdapter().prepare(
    request: request(id),
    basePersistencePayload: basePayload(id),
    baseFuturePersistenceEligible: false,
    binding: binding(id),
  );
}

void main() {
  const adapter =
      PlantaoDrugProvenancePersistencePayloadParityGateShadowAdapter();

  test('verifies provenance-only enrichment and preserves eligibility', () {
    final snapshot = adapter.verify(
      request: request('req-parity'),
      basePersistencePayload: basePayload('req-parity'),
      baseFuturePersistenceEligible: false,
      preparedPayload: prepared('req-parity'),
      binding: binding('req-parity'),
    );

    expect(
      snapshot.status,
      PlantaoDrugProvenancePersistencePayloadParityStatus.parityVerified,
    );
    expect(snapshot.parityVerified, isTrue);
    expect(snapshot.changedTopLevelKeys, ['provenance']);
    expect(
      snapshot.changedProvenanceKeys,
      containsAll(<String>[
        'sourceMode',
        'matchedDrugDocumentIds',
        'validatorReason',
        'documentVersions',
      ]),
    );
    expect(snapshot.unexpectedPaths, isEmpty);
    expect(snapshot.baseFuturePersistenceEligible, isFalse);
  });

  test('top-level clinical mutation is rejected', () {
    final good = prepared('req-mutated');
    final mutated = PlantaoDrugProvenancePersistencePayloadShadowSnapshot(
      requestId: 'req-mutated',
      status: PlantaoDrugProvenancePersistencePayloadStatus.payloadPrepared,
      payload: <String, Object?>{
        ...good.payload,
        'status': 'ready',
        'sanitizedText': 'Texto alterado',
      },
      baseFuturePersistenceEligible: false,
      reasons: good.reasons,
      observedAt: DateTime.utc(2026, 7, 27),
    );

    final snapshot = adapter.verify(
      request: request('req-mutated'),
      basePersistencePayload: basePayload('req-mutated'),
      baseFuturePersistenceEligible: false,
      preparedPayload: mutated,
      binding: binding('req-mutated'),
    );

    expect(
      snapshot.status,
      PlantaoDrugProvenancePersistencePayloadParityStatus.unexpectedMutation,
    );
    expect(snapshot.unexpectedPaths, contains('topLevel:status'));
    expect(snapshot.unexpectedPaths, contains('topLevel:sanitizedText'));
  });

  test('validated dose mutation is rejected even inside provenance', () {
    final good = prepared('req-dose');
    final provenance = Map<String, Object?>.from(
      good.payload['provenance']! as Map,
    )..['validatedDose'] = true;
    final mutated = PlantaoDrugProvenancePersistencePayloadShadowSnapshot(
      requestId: 'req-dose',
      status: PlantaoDrugProvenancePersistencePayloadStatus.payloadPrepared,
      payload: <String, Object?>{...good.payload, 'provenance': provenance},
      baseFuturePersistenceEligible: false,
      reasons: good.reasons,
      observedAt: DateTime.utc(2026, 7, 27),
    );

    final snapshot = adapter.verify(
      request: request('req-dose'),
      basePersistencePayload: basePayload('req-dose'),
      baseFuturePersistenceEligible: false,
      preparedPayload: mutated,
      binding: binding('req-dose'),
    );

    expect(
      snapshot.status,
      PlantaoDrugProvenancePersistencePayloadParityStatus.unexpectedMutation,
    );
    expect(snapshot.unexpectedPaths, contains('provenance:validatedDose'));
  });

  test('eligibility mismatch is rejected', () {
    final good = prepared('req-eligibility');
    final mutated = PlantaoDrugProvenancePersistencePayloadShadowSnapshot(
      requestId: 'req-eligibility',
      status: PlantaoDrugProvenancePersistencePayloadStatus.payloadPrepared,
      payload: good.payload,
      baseFuturePersistenceEligible: true,
      reasons: good.reasons,
      observedAt: DateTime.utc(2026, 7, 27),
    );

    final snapshot = adapter.verify(
      request: request('req-eligibility'),
      basePersistencePayload: basePayload('req-eligibility'),
      baseFuturePersistenceEligible: false,
      preparedPayload: mutated,
      binding: binding('req-eligibility'),
    );

    expect(
      snapshot.status,
      PlantaoDrugProvenancePersistencePayloadParityStatus.unexpectedMutation,
    );
    expect(
      snapshot.unexpectedPaths,
      contains('eligibility:futurePersistenceEligible'),
    );
  });
}
