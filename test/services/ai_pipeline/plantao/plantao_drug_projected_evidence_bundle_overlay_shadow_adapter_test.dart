import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_evidence_bundle.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_request.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_explicit_typed_regimen_evidence_projection_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_projected_evidence_bundle_overlay_shadow_adapter.dart';

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

PlantaoEvidenceDocument protocolDocument() => PlantaoEvidenceDocument(
  documentId: 'protocol:icfer',
  version: 'legacy_protocols_database_v1',
  kind: PlantaoEvidenceKind.protocol,
  excerpt: 'Protocolo clínico retido',
);

PlantaoDrugEvidenceDocument projectedDocument({
  String version = 'clinical-data-v1-test',
  num dose = 40,
}) => PlantaoDrugEvidenceDocument(
  documentId: 'furosemida',
  version: version,
  excerpt: 'explicit_ai_regimen',
  drugName: 'Furosemida',
  dose: dose,
  unit: 'mg',
  route: 'VO',
  frequency: '1x/dia',
  metadata: const <String, Object?>{
    'regimenSource': 'aiRegimens',
    'regimenIndex': 0,
  },
);

PlantaoEvidenceBundle baseBundle({
  Iterable<PlantaoDrugEvidenceDocument> drugDocuments =
      const <PlantaoDrugEvidenceDocument>[],
  Map<String, String> documentVersions = const <String, String>{
    'protocol:icfer': 'legacy_protocols_database_v1',
  },
  bool includeRichEvidence = false,
}) => PlantaoEvidenceBundle(
  requestId: includeRichEvidence ? 'overlay-rich-request' : '',
  sessionIdHash: includeRichEvidence ? 'overlay-rich-session' : '',
  locale: includeRichEvidence ? 'es' : 'pt',
  queryFingerprint: includeRichEvidence ? 'overlay-rich-query' : '',
  protocolEvidence: includeRichEvidence
      ? <PlantaoEvidenceItem>[
    PlantaoEvidenceItem(
      kind: 'protocol',
      sourceId: 'overlay-rich-protocol',
      sourceVersion: 'overlay-rich-protocol-v1',
      documentId: 'protocol:overlay-rich-protocol',
      contentHash: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      boundedExcerpt: 'overlay-rich-protocol-boundedExcerpt',
    ),
        ]
      : const <PlantaoEvidenceItem>[],
  drugEvidence: includeRichEvidence
      ? <PlantaoEvidenceItem>[
    PlantaoEvidenceItem(
      kind: 'protocol',
      sourceId: 'overlay-rich-drug',
      sourceVersion: 'overlay-rich-drug-v1',
      documentId: 'protocol:overlay-rich-drug',
      contentHash: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      boundedExcerpt: 'overlay-rich-drug-boundedExcerpt',
    ),
        ]
      : const <PlantaoEvidenceItem>[],
  validationStatus: includeRichEvidence
      ? PlantaoEvidenceValidationStatus.validated
      : PlantaoEvidenceValidationStatus.unavailable,
  bundleHash: includeRichEvidence ? 'overlay-rich-bundle-hash' : '',
  createdAtEpochMs: includeRichEvidence ? 123456789 : 0,
  limitations: includeRichEvidence
      ? const <String>['overlay-rich-limitation']
      : const <String>[],
  clinicalDocuments: const <PlantaoEvidenceDocument>[],
  drugDocuments: drugDocuments,
  protocolDocuments: <PlantaoEvidenceDocument>[protocolDocument()],
  patientFacts: const <PlantaoEvidenceDocument>[],
  caseEvidence: const <PlantaoEvidenceDocument>[],
  externalGrounding: const <PlantaoEvidenceDocument>[],
  documentVersions: documentVersions,
  coverage: PlantaoEvidenceCoverage(
    hasClinical: false,
    hasDrug: drugDocuments.isNotEmpty,
    hasProtocol: true,
    hasPatientFacts: false,
  ),
  missingRequirements: const <String>[
    'typed_medication_candidates_not_extracted',
  ],
  retrievalStatus: PlantaoRetrievalStatus.complete,
);

PlantaoDrugExplicitTypedRegimenEvidenceProjectionShadowSnapshot projection(
  String id, {
  Iterable<PlantaoDrugEvidenceDocument> projectedDocuments =
      const <PlantaoDrugEvidenceDocument>[],
  PlantaoDrugExplicitTypedRegimenEvidenceProjectionStatus status =
      PlantaoDrugExplicitTypedRegimenEvidenceProjectionStatus
          .projectionRecorded,
}) => PlantaoDrugExplicitTypedRegimenEvidenceProjectionShadowSnapshot(
  requestId: id,
  status: status,
  projectedDocuments: projectedDocuments,
  unavailableDocumentIds: const <String>[],
  rejectedEntries: const <String>[],
  reasons: const <String>[
    'canonical_drug_explicit_typed_regimen_projection_recorded',
  ],
  observedAt: DateTime.utc(2026, 7, 27),
);

void main() {
  const adapter = PlantaoDrugProjectedEvidenceBundleOverlayShadowAdapter();

  test('prepares an immutable candidate overlay and preserves the base', () {
    final base = baseBundle(
      includeRichEvidence: true,
);
    final snapshot = adapter.prepare(
      request: request('req-overlay'),
      baseEvidenceBundle: base,
      projection: projection(
        'req-overlay',
        projectedDocuments: <PlantaoDrugEvidenceDocument>[projectedDocument()],
      ),
    );

    expect(snapshot.overlayPrepared, isTrue);
    expect(snapshot.candidateDrugDocumentCount, 1);
    expect(snapshot.addedRegimenKeys, hasLength(1));
    expect(snapshot.duplicateRegimenKeys, isEmpty);

    final candidate = snapshot.candidateBundle!;
    final preservedRichEvidenceBundle = candidate;
    expect(base.protocolEvidence, isNotEmpty);
    expect(base.drugEvidence, isNotEmpty);
    expect(preservedRichEvidenceBundle.requestId, base.requestId);
    expect(preservedRichEvidenceBundle.sessionIdHash, base.sessionIdHash);
    expect(preservedRichEvidenceBundle.locale, base.locale);
    expect(preservedRichEvidenceBundle.queryFingerprint, base.queryFingerprint);
    expect(preservedRichEvidenceBundle.protocolEvidence, same(base.protocolEvidence));
    expect(preservedRichEvidenceBundle.drugEvidence, same(base.drugEvidence));
    expect(preservedRichEvidenceBundle.validationStatus, base.validationStatus);
    expect(preservedRichEvidenceBundle.bundleHash, base.bundleHash);
    expect(preservedRichEvidenceBundle.createdAtEpochMs, base.createdAtEpochMs);
    expect(preservedRichEvidenceBundle.limitations, same(base.limitations));
    expect(candidate.protocolDocuments, orderedEquals(base.protocolDocuments));
    expect(candidate.protocolDocuments.single.documentId, 'protocol:icfer');
    expect(candidate.drugDocuments.single.documentId, 'furosemida');
    expect(candidate.coverage.hasDrug, isTrue);
    expect(candidate.retrievalStatus, base.retrievalStatus);
    expect(candidate.missingRequirements, base.missingRequirements);
    expect(candidate.documentVersions['furosemida'], 'clinical-data-v1-test');

    expect(base.drugDocuments, isEmpty);
    expect(base.coverage.hasDrug, isFalse);
    expect(base.documentVersions.containsKey('furosemida'), isFalse);
    expect(
      () => candidate.drugDocuments.add(projectedDocument(dose: 80)),
      throwsUnsupportedError,
    );
    expect(
      () => candidate.documentVersions['furosemida'] = 'other',
      throwsUnsupportedError,
    );
  });

  test('deduplicates an exact regimen without mutating the base', () {
    final retained = projectedDocument();
    final base = baseBundle(
      drugDocuments: <PlantaoDrugEvidenceDocument>[retained],
      documentVersions: const <String, String>{
        'protocol:icfer': 'legacy_protocols_database_v1',
        'furosemida': 'clinical-data-v1-test',
      },
    );

    final snapshot = adapter.prepare(
      request: request('req-duplicate'),
      baseEvidenceBundle: base,
      projection: projection(
        'req-duplicate',
        projectedDocuments: <PlantaoDrugEvidenceDocument>[retained],
      ),
    );

    expect(snapshot.overlayPrepared, isTrue);
    expect(snapshot.candidateDrugDocumentCount, 1);
    expect(snapshot.addedRegimenKeys, isEmpty);
    expect(snapshot.duplicateRegimenKeys, hasLength(1));
    expect(base.drugDocuments, hasLength(1));
  });

  test('rejects a canonical document version conflict', () {
    final base = baseBundle(
      documentVersions: const <String, String>{
        'protocol:icfer': 'legacy_protocols_database_v1',
        'furosemida': 'clinical-data-v1-old',
      },
    );

    final snapshot = adapter.prepare(
      request: request('req-version'),
      baseEvidenceBundle: base,
      projection: projection(
        'req-version',
        projectedDocuments: <PlantaoDrugEvidenceDocument>[
          projectedDocument(version: 'clinical-data-v1-new'),
        ],
      ),
    );

    expect(
      snapshot.status,
      PlantaoDrugProjectedEvidenceBundleOverlayStatus.versionMismatch,
    );
    expect(snapshot.candidateBundle, isNull);
    expect(base.documentVersions['furosemida'], 'clinical-data-v1-old');
  });

  test('missing base evidence prevents an overlay', () {
    final snapshot = adapter.prepare(
      request: request('req-no-base'),
      baseEvidenceBundle: null,
      projection: projection('req-no-base'),
    );

    expect(
      snapshot.status,
      PlantaoDrugProjectedEvidenceBundleOverlayStatus.baseEvidenceUnavailable,
    );
    expect(snapshot.candidateBundle, isNull);
  });

  test('an unrecorded projection blocks the overlay', () {
    final snapshot = adapter.prepare(
      request: request('req-unrecorded'),
      baseEvidenceBundle: baseBundle(),
      projection: projection(
        'req-unrecorded',
        status: PlantaoDrugExplicitTypedRegimenEvidenceProjectionStatus
            .joinNotReady,
      ),
    );

    expect(
      snapshot.status,
      PlantaoDrugProjectedEvidenceBundleOverlayStatus.projectionNotRecorded,
    );
    expect(snapshot.candidateBundle, isNull);
  });

  test('a stale projection is rejected', () {
    final snapshot = adapter.prepare(
      request: request('req-current'),
      baseEvidenceBundle: baseBundle(),
      projection: projection('req-old'),
    );

    expect(
      snapshot.status,
      PlantaoDrugProjectedEvidenceBundleOverlayStatus.stale,
    );
  });
}
