import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_canonical_drug_evidence.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_request.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_evidence_finalization_join_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_evidence_request_observer.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_evidence_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_original_input_identity_extractor.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_finalization_shadow_snapshot.dart';

const version = 'clinical-data-v1-join-test';
const bundleSha =
    '2222222222222222222222222222222222222222222222222222222222222222';

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

PlantaoFinalizationShadowSnapshot finalization(String id) =>
    PlantaoFinalizationShadowSnapshot(
      requestId: id,
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

PlantaoDrugEvidenceRequestSnapshot evidence(String id) {
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
  final shadow = PlantaoDrugEvidenceShadowSnapshot(
    status: PlantaoDrugEvidenceShadowStatus.complete,
    manifest: manifest,
    candidates: <PlantaoCanonicalDrugCandidate>[
      const PlantaoCanonicalDrugCandidate(
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
    evidence: shadow,
    reasons: shadow.reasons,
    observedAt: DateTime.utc(2026, 7, 27),
  );
}

void main() {
  test(
    'joins canonical evidence and finalization only for the same request',
    () async {
      const adapter = PlantaoDrugEvidenceFinalizationJoinShadowAdapter();
      final snapshot = await adapter.join(
        request: request('req-join'),
        finalization: finalization('req-join'),
        drugEvidenceFuture: Future.value(evidence('req-join')),
      );

      expect(snapshot.status, PlantaoDrugEvidenceFinalizationJoinStatus.ready);
      expect(snapshot.isReady, isTrue);
      expect(snapshot.candidateDocumentIds, ['furosemida']);
      expect(snapshot.evidenceDocumentIds, ['furosemida']);
      expect(snapshot.documentVersions['furosemida'], version);
      expect(
        PlantaoDrugEvidenceFinalizationJoinShadowSnapshot
            .productiveValidationConnected,
        isFalse,
      );
    },
  );

  test('stale evidence from another request is never joined', () async {
    const adapter = PlantaoDrugEvidenceFinalizationJoinShadowAdapter();
    final snapshot = await adapter.join(
      request: request('req-current'),
      finalization: finalization('req-current'),
      drugEvidenceFuture: Future.value(evidence('req-old')),
    );

    expect(snapshot.status, PlantaoDrugEvidenceFinalizationJoinStatus.stale);
    expect(snapshot.isReady, isFalse);
  });

  test('timeout is explicit and does not block indefinitely', () async {
    final completer = Completer<PlantaoDrugEvidenceRequestSnapshot>();
    const adapter = PlantaoDrugEvidenceFinalizationJoinShadowAdapter(
      maximumWait: Duration(milliseconds: 5),
    );
    final snapshot = await adapter.join(
      request: request('req-timeout'),
      finalization: finalization('req-timeout'),
      drugEvidenceFuture: completer.future,
    );

    expect(snapshot.status, PlantaoDrugEvidenceFinalizationJoinStatus.timedOut);
    expect(snapshot.reasons.single, contains('drug_evidence_join_timeout_ms'));
  });
}
