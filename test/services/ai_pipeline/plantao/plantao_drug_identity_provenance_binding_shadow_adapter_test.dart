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

const version = 'clinical-data-v1-provenance-test';
const bundleSha =
    '3333333333333333333333333333333333333333333333333333333333333333';

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

PlantaoProvenance baseProvenance({
  PlantaoSourceMode sourceMode = PlantaoSourceMode.modelNative,
}) => PlantaoProvenance(
  provider: 'shadow_route_plan_not_executed',
  model: 'unexecuted',
  sourceMode: sourceMode,
  matchedClinicalDocumentIds: const <String>['protocol:icfer'],
  matchedDrugDocumentIds: const <String>[],
  validatedDose: false,
  validatorReason: 'typed_medication_candidates_absent',
  usedExternalGrounding: false,
  continuationType: PlantaoContinuationType.initial,
  documentVersions: const <String, String>{
    'protocol:icfer': 'legacy_protocols_database_v1',
  },
);

PlantaoDrugEvidenceRequestSnapshot drugRequest(String id) {
  final manifest = PlantaoDrugEvidenceManifest.fromJson(<String, Object?>{
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
  final document = PlantaoCanonicalDrugEvidenceDocument.fromJson(
    <String, Object?>{
      'id': 'furosemida',
      'category': 'cardio',
      'name': <String, Object?>{'pt': 'Furosemida', 'es': 'Furosemida'},
      'keywords': <Object?>['furosemida'],
      'dataVersion': version,
      'clinicalContentSha256': bundleSha,
      'source': 'medcases-calculadora',
      'schema': 'premium-v1',
      'sourceModule': 'cardio.js',
      'pt': <String, Object?>{'dose': '20–40 mg'},
      'es': <String, Object?>{'dose': '20–40 mg'},
    },
    manifest: manifest,
  );
  final evidence = PlantaoDrugEvidenceShadowSnapshot(
    status: PlantaoDrugEvidenceShadowStatus.complete,
    manifest: manifest,
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
    documents: <PlantaoCanonicalDrugEvidenceDocument>[document],
    reasons: const <String>['canonical_identity_resolved'],
    observedAt: DateTime.utc(2026, 7, 27),
  );
  return PlantaoDrugEvidenceRequestSnapshot(
    requestId: id,
    status: PlantaoDrugEvidenceRequestStatus.ready,
    intent: PlantaoDrugOriginalInputIntent.dosage,
    evidence: evidence,
    reasons: evidence.reasons,
    observedAt: DateTime.utc(2026, 7, 27),
  );
}

PlantaoDrugEvidenceFinalizationJoinShadowSnapshot join(String id) =>
    PlantaoDrugEvidenceFinalizationJoinShadowSnapshot(
      requestId: id,
      status: PlantaoDrugEvidenceFinalizationJoinStatus.ready,
      drugEvidence: drugRequest(id),
      candidateDocumentIds: const <String>['furosemida'],
      evidenceDocumentIds: const <String>['furosemida'],
      documentVersions: const <String, String>{'furosemida': version},
      reasons: const <String>['request_scoped_drug_evidence_join_completed'],
      observedAt: DateTime.utc(2026, 7, 27),
    );

void main() {
  const adapter = PlantaoDrugIdentityProvenanceBindingShadowAdapter();

  test('binds canonical drug IDs and versions without validating dose', () {
    final base = baseProvenance();
    final snapshot = adapter.bind(
      request: request('req-provenance'),
      validationRequestId: 'req-provenance',
      validationProvenance: base,
      join: join('req-provenance'),
    );

    expect(
      snapshot.status,
      PlantaoDrugIdentityProvenanceBindingStatus.identityEvidenceBound,
    );
    expect(snapshot.canonicalDocumentIds, ['furosemida']);
    expect(snapshot.typedRegimenDocumentIds, isEmpty);
    expect(snapshot.provenance.matchedDrugDocumentIds, ['furosemida']);
    expect(snapshot.provenance.documentVersions['furosemida'], version);
    expect(snapshot.provenance.sourceMode, PlantaoSourceMode.localRag);
    expect(snapshot.provenance.validatedDose, isFalse);
    expect(
      snapshot.reasons,
      contains('drug_identity_evidence_not_used_for_dose_validation'),
    );
    expect(snapshot.reasons, contains('typed_regimen_unavailable'));

    expect(base.matchedDrugDocumentIds, isEmpty);
    expect(base.validatedDose, isFalse);
  });

  test('firestore RAG becomes mixed when canonical identity is added', () {
    final base = baseProvenance(sourceMode: PlantaoSourceMode.firestoreRag);
    final snapshot = adapter.bind(
      request: request('req-firestore-rag'),
      validationRequestId: 'req-firestore-rag',
      validationProvenance: base,
      join: join('req-firestore-rag'),
    );

    expect(
      snapshot.status,
      PlantaoDrugIdentityProvenanceBindingStatus.identityEvidenceBound,
    );
    expect(snapshot.provenance.sourceMode, PlantaoSourceMode.mixed);
    expect(snapshot.provenance.validatedDose, isFalse);
    expect(snapshot.typedRegimenDocumentIds, isEmpty);
  });

  test('stale request never enriches provenance', () {
    final base = baseProvenance();
    final snapshot = adapter.bind(
      request: request('req-current'),
      validationRequestId: 'req-current',
      validationProvenance: base,
      join: join('req-old'),
    );

    expect(snapshot.status, PlantaoDrugIdentityProvenanceBindingStatus.stale);
    expect(snapshot.provenance.matchedDrugDocumentIds, isEmpty);
    expect(snapshot.canonicalDocumentIds, isEmpty);
  });

  test('non-ready join preserves base provenance', () {
    final base = baseProvenance();
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

    final snapshot = adapter.bind(
      request: request('req-empty'),
      validationRequestId: 'req-empty',
      validationProvenance: base,
      join: emptyJoin,
    );

    expect(snapshot.status, PlantaoDrugIdentityProvenanceBindingStatus.empty);
    expect(snapshot.provenance.matchedDrugDocumentIds, isEmpty);
    expect(snapshot.provenance.sourceMode, PlantaoSourceMode.modelNative);
  });
}
