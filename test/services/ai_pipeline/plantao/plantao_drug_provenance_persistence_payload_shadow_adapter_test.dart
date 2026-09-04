import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_provenance.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_request.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_identity_provenance_binding_shadow_adapter.dart';
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

void main() {
  const adapter = PlantaoDrugProvenancePersistencePayloadShadowAdapter();

  test('prepares an enriched copy without promoting eligibility', () {
    final base = basePayload('req-payload');
    final originalProvenance = base['provenance'];

    final snapshot = adapter.prepare(
      request: request('req-payload'),
      basePersistencePayload: base,
      baseFuturePersistenceEligible: false,
      binding: binding('req-payload'),
    );

    expect(
      snapshot.status,
      PlantaoDrugProvenancePersistencePayloadStatus.payloadPrepared,
    );
    expect(snapshot.baseFuturePersistenceEligible, isFalse);
    expect(snapshot.payload['status'], 'blocked');

    final provenance = snapshot.payload['provenance']! as Map<Object?, Object?>;
    expect(provenance['matchedDrugDocumentIds'], ['furosemida']);
    expect(provenance['validatedDose'], isFalse);
    expect(
      (provenance['documentVersions']! as Map<Object?, Object?>)['furosemida'],
      'clinical-data-v1-test',
    );

    expect(base['provenance'], same(originalProvenance));
    expect(
      (base['provenance']! as Map<String, Object?>)['matchedDrugDocumentIds'],
      isEmpty,
    );
  });

  test('true base eligibility is preserved but never created by binding', () {
    final snapshot = adapter.prepare(
      request: request('req-eligible'),
      basePersistencePayload: basePayload('req-eligible'),
      baseFuturePersistenceEligible: true,
      binding: binding('req-eligible'),
    );

    expect(snapshot.baseFuturePersistenceEligible, isTrue);
    expect(
      PlantaoDrugProvenancePersistencePayloadShadowSnapshot
          .persistenceEligibilityPromoted,
      isFalse,
    );
  });

  test('request mismatch keeps the base payload untouched', () {
    final base = basePayload('req-current');
    final snapshot = adapter.prepare(
      request: request('req-current'),
      basePersistencePayload: base,
      baseFuturePersistenceEligible: false,
      binding: binding('req-old'),
    );

    expect(
      snapshot.status,
      PlantaoDrugProvenancePersistencePayloadStatus.stale,
    );
    final provenance = snapshot.payload['provenance']! as Map<Object?, Object?>;
    expect(provenance['matchedDrugDocumentIds'], isEmpty);
  });
}
