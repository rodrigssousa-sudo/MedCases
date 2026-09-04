import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_canonical_drug_evidence.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_request.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_evidence_finalization_join_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_evidence_request_observer.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_evidence_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_explicit_typed_regimen_evidence_projection_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_original_input_identity_extractor.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_typed_regimen_capability_matrix_shadow_adapter.dart';

const version = 'clinical-data-v1-projection-test';
const bundleSha =
    '9999999999999999999999999999999999999999999999999999999999999999';

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

PlantaoCanonicalDrugEvidenceDocument document({
  bool explicitTypedRegimen = false,
  bool stringDose = false,
}) {
  return PlantaoCanonicalDrugEvidenceDocument.fromJson(<String, Object?>{
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
    if (explicitTypedRegimen)
      'aiRegimens': <Object?>[
        <String, Object?>{
          'dose': stringDose ? '40' : 40,
          'unit': 'mg',
          'route': 'VO',
          'frequency': '1x/dia',
        },
      ],
  }, manifest: manifest());
}

PlantaoDrugEvidenceFinalizationJoinShadowSnapshot join(
  String id,
  PlantaoCanonicalDrugEvidenceDocument drugDocument,
) {
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
    documents: <PlantaoCanonicalDrugEvidenceDocument>[drugDocument],
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

PlantaoDrugTypedRegimenCapabilityMatrixShadowSnapshot matrix(
  String id, {
  required bool supportsMaterialization,
  required bool boundAsTypedRegimen,
  PlantaoDrugTypedRegimenCapabilityMatrixStatus status =
      PlantaoDrugTypedRegimenCapabilityMatrixStatus.capabilityMatrixRecorded,
}) {
  return PlantaoDrugTypedRegimenCapabilityMatrixShadowSnapshot(
    requestId: id,
    status: status,
    entries:
        status ==
            PlantaoDrugTypedRegimenCapabilityMatrixStatus
                .capabilityMatrixRecorded
        ? <PlantaoDrugTypedRegimenCapabilityEntry>[
            PlantaoDrugTypedRegimenCapabilityEntry(
              documentId: 'furosemida',
              documentVersion: version,
              completeness: 'richClinical',
              supportsMedicationMaterialization: supportsMaterialization,
              boundAsCanonicalIdentity: true,
              boundAsTypedRegimen: boundAsTypedRegimen,
              gaps: supportsMaterialization
                  ? const <String>[]
                  : const <String>['typed_regimen_contract_unavailable'],
            ),
          ]
        : const <PlantaoDrugTypedRegimenCapabilityEntry>[],
    unresolvedGaps: supportsMaterialization
        ? const <String>[]
        : const <String>['furosemida:typed_regimen_contract_unavailable'],
    reasons: const <String>[
      'canonical_drug_typed_regimen_capability_matrix_recorded',
    ],
    observedAt: DateTime.utc(2026, 7, 27),
  );
}

void main() {
  const adapter =
      PlantaoDrugExplicitTypedRegimenEvidenceProjectionShadowAdapter();

  test('raw clinical dose text is never projected', () {
    final snapshot = adapter.project(
      request: request('req-raw'),
      join: join('req-raw', document()),
      capabilityMatrix: matrix(
        'req-raw',
        supportsMaterialization: false,
        boundAsTypedRegimen: false,
      ),
    );

    expect(
      snapshot.status,
      PlantaoDrugExplicitTypedRegimenEvidenceProjectionStatus
          .projectionRecorded,
    );
    expect(snapshot.projectedDocuments, isEmpty);
    expect(snapshot.unavailableDocumentIds, ['furosemida']);
    expect(snapshot.rejectedEntries, isEmpty);
    expect(snapshot.reasons, contains('typed_regimen_contract_unavailable'));
  });

  test('explicit numeric aiRegimen is projected exactly', () {
    final snapshot = adapter.project(
      request: request('req-typed'),
      join: join('req-typed', document(explicitTypedRegimen: true)),
      capabilityMatrix: matrix(
        'req-typed',
        supportsMaterialization: true,
        boundAsTypedRegimen: true,
      ),
    );

    expect(snapshot.projectionRecorded, isTrue);
    expect(snapshot.projectedRegimenCount, 1);
    expect(snapshot.projectedCanonicalDocumentIds, {'furosemida'});
    expect(snapshot.unavailableDocumentIds, isEmpty);
    expect(snapshot.rejectedEntries, isEmpty);

    final projected = snapshot.projectedDocuments.single;
    expect(projected.documentId, 'furosemida');
    expect(projected.version, version);
    expect(projected.drugName, 'Furosemida');
    expect(projected.dose, 40);
    expect(projected.unit, 'mg');
    expect(projected.route, 'VO');
    expect(projected.frequency, '1x/dia');
    expect(projected.metadata['regimenSource'], 'aiRegimens');
    expect(projected.metadata['regimenIndex'], 0);
  });

  test('a string dose cannot masquerade as a typed regimen', () {
    final snapshot = adapter.project(
      request: request('req-string'),
      join: join(
        'req-string',
        document(explicitTypedRegimen: true, stringDose: true),
      ),
      capabilityMatrix: matrix(
        'req-string',
        supportsMaterialization: true,
        boundAsTypedRegimen: true,
      ),
    );

    expect(
      snapshot.status,
      PlantaoDrugExplicitTypedRegimenEvidenceProjectionStatus.matrixMismatch,
    );
    expect(snapshot.projectedDocuments, isEmpty);
  });

  test('an unrecorded capability matrix blocks projection', () {
    final snapshot = adapter.project(
      request: request('req-unrecorded'),
      join: join('req-unrecorded', document()),
      capabilityMatrix: matrix(
        'req-unrecorded',
        supportsMaterialization: false,
        boundAsTypedRegimen: false,
        status: PlantaoDrugTypedRegimenCapabilityMatrixStatus.joinNotReady,
      ),
    );

    expect(
      snapshot.status,
      PlantaoDrugExplicitTypedRegimenEvidenceProjectionStatus
          .capabilityMatrixNotRecorded,
    );
    expect(snapshot.projectedDocuments, isEmpty);
  });

  test('a stale request chain is rejected', () {
    final snapshot = adapter.project(
      request: request('req-current'),
      join: join('req-old', document()),
      capabilityMatrix: matrix(
        'req-old',
        supportsMaterialization: false,
        boundAsTypedRegimen: false,
      ),
    );

    expect(
      snapshot.status,
      PlantaoDrugExplicitTypedRegimenEvidenceProjectionStatus.stale,
    );
  });
}
