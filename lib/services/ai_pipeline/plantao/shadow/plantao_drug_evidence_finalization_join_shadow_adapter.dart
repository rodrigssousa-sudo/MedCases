import 'dart:async';

import '../contracts/plantao_request.dart';
import 'plantao_drug_evidence_request_observer.dart';
import 'plantao_finalization_shadow_snapshot.dart';

enum PlantaoDrugEvidenceFinalizationJoinStatus {
  ready,
  notEvaluated,
  empty,
  ambiguous,
  missing,
  timedOut,
  stale,
  failed,
}

class PlantaoDrugEvidenceFinalizationJoinShadowSnapshot {
  PlantaoDrugEvidenceFinalizationJoinShadowSnapshot({
    required this.requestId,
    required this.status,
    required this.drugEvidence,
    required Iterable<String> candidateDocumentIds,
    required Iterable<String> evidenceDocumentIds,
    required Map<String, String> documentVersions,
    required Iterable<String> reasons,
    required this.observedAt,
  }) : candidateDocumentIds = List<String>.unmodifiable(candidateDocumentIds),
       evidenceDocumentIds = List<String>.unmodifiable(evidenceDocumentIds),
       documentVersions = Map<String, String>.unmodifiable(documentVersions),
       reasons = List<String>.unmodifiable(reasons);

  static const bool productiveValidationConnected = false;
  static const bool productiveProvenanceConnected = false;
  static const bool productivePersistenceConnected = false;
  static const bool productiveRenderingConnected = false;
  static const bool medicationMaterializationEnabled = false;

  final String requestId;
  final PlantaoDrugEvidenceFinalizationJoinStatus status;
  final PlantaoDrugEvidenceRequestSnapshot? drugEvidence;
  final List<String> candidateDocumentIds;
  final List<String> evidenceDocumentIds;
  final Map<String, String> documentVersions;
  final List<String> reasons;
  final DateTime observedAt;

  bool get isReady =>
      status == PlantaoDrugEvidenceFinalizationJoinStatus.ready &&
      drugEvidence?.hasCanonicalEvidence == true;
}

class PlantaoDrugEvidenceFinalizationJoinShadowAdapter {
  const PlantaoDrugEvidenceFinalizationJoinShadowAdapter({
    this.maximumWait = const Duration(seconds: 2),
  });

  final Duration maximumWait;

  Future<PlantaoDrugEvidenceFinalizationJoinShadowSnapshot> join({
    required PlantaoRequest request,
    required PlantaoFinalizationShadowSnapshot finalization,
    required Future<PlantaoDrugEvidenceRequestSnapshot>? drugEvidenceFuture,
  }) async {
    request.ensureValid();

    if (finalization.requestId != request.requestId) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugEvidenceFinalizationJoinStatus.stale,
        reasons: const <String>['finalization_request_id_mismatch'],
      );
    }

    if (drugEvidenceFuture == null) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugEvidenceFinalizationJoinStatus.missing,
        reasons: const <String>['drug_evidence_future_missing'],
      );
    }

    try {
      final drugEvidence = await drugEvidenceFuture.timeout(maximumWait);
      if (drugEvidence.requestId != request.requestId) {
        return _snapshot(
          requestId: request.requestId,
          status: PlantaoDrugEvidenceFinalizationJoinStatus.stale,
          drugEvidence: drugEvidence,
          reasons: <String>[
            'drug_evidence_request_id_mismatch:${drugEvidence.requestId}',
          ],
        );
      }

      final evidence = drugEvidence.evidence;
      final versions = <String, String>{
        for (final document in evidence.documents)
          document.documentId: document.dataVersion,
      };

      return _snapshot(
        requestId: request.requestId,
        status: _joinStatus(drugEvidence.status),
        drugEvidence: drugEvidence,
        candidateDocumentIds: drugEvidence.evidence.candidates.map(
          (candidate) => candidate.documentId,
        ),
        evidenceDocumentIds: evidence.documents.map(
          (document) => document.documentId,
        ),
        documentVersions: versions,
        reasons: <String>{
          'request_scoped_drug_evidence_join_completed',
          ...drugEvidence.reasons,
        },
      );
    } on TimeoutException {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugEvidenceFinalizationJoinStatus.timedOut,
        reasons: <String>[
          'drug_evidence_join_timeout_ms:${maximumWait.inMilliseconds}',
        ],
      );
    } catch (error) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugEvidenceFinalizationJoinStatus.failed,
        reasons: <String>['drug_evidence_join_failure:${error.runtimeType}'],
      );
    }
  }

  static PlantaoDrugEvidenceFinalizationJoinStatus _joinStatus(
    PlantaoDrugEvidenceRequestStatus status,
  ) {
    switch (status) {
      case PlantaoDrugEvidenceRequestStatus.ready:
        return PlantaoDrugEvidenceFinalizationJoinStatus.ready;
      case PlantaoDrugEvidenceRequestStatus.notEvaluated:
        return PlantaoDrugEvidenceFinalizationJoinStatus.notEvaluated;
      case PlantaoDrugEvidenceRequestStatus.empty:
        return PlantaoDrugEvidenceFinalizationJoinStatus.empty;
      case PlantaoDrugEvidenceRequestStatus.ambiguous:
        return PlantaoDrugEvidenceFinalizationJoinStatus.ambiguous;
      case PlantaoDrugEvidenceRequestStatus.failed:
        return PlantaoDrugEvidenceFinalizationJoinStatus.failed;
    }
  }

  static PlantaoDrugEvidenceFinalizationJoinShadowSnapshot _snapshot({
    required String requestId,
    required PlantaoDrugEvidenceFinalizationJoinStatus status,
    PlantaoDrugEvidenceRequestSnapshot? drugEvidence,
    Iterable<String> candidateDocumentIds = const <String>[],
    Iterable<String> evidenceDocumentIds = const <String>[],
    Map<String, String> documentVersions = const <String, String>{},
    Iterable<String> reasons = const <String>[],
  }) {
    return PlantaoDrugEvidenceFinalizationJoinShadowSnapshot(
      requestId: requestId,
      status: status,
      drugEvidence: drugEvidence,
      candidateDocumentIds: candidateDocumentIds,
      evidenceDocumentIds: evidenceDocumentIds,
      documentVersions: documentVersions,
      reasons: reasons,
      observedAt: DateTime.now().toUtc(),
    );
  }
}
