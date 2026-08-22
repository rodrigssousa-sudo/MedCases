import '../contracts/plantao_evidence_bundle.dart';
import '../contracts/plantao_request.dart';
import 'plantao_drug_explicit_typed_regimen_evidence_projection_shadow_adapter.dart';

enum PlantaoDrugProjectedEvidenceBundleOverlayStatus {
  overlayPrepared,
  projectionNotRecorded,
  baseEvidenceUnavailable,
  stale,
  versionMismatch,
  failed,
}

class PlantaoDrugProjectedEvidenceBundleOverlayShadowSnapshot {
  PlantaoDrugProjectedEvidenceBundleOverlayShadowSnapshot({
    required this.requestId,
    required this.status,
    required this.candidateBundle,
    required Iterable<String> addedRegimenKeys,
    required Iterable<String> duplicateRegimenKeys,
    required Iterable<String> reasons,
    required this.observedAt,
  }) : addedRegimenKeys = List<String>.unmodifiable(addedRegimenKeys),
       duplicateRegimenKeys = List<String>.unmodifiable(duplicateRegimenKeys),
       reasons = List<String>.unmodifiable(reasons);

  static const bool baseEvidenceBundleMutated = false;
  static const bool validationConnected = false;
  static const bool validationReexecuted = false;
  static const bool productiveEvidenceOwnerReplaced = false;
  static const bool promptConnected = false;
  static const bool rendererConnected = false;
  static const bool firestoreConnected = false;
  static const bool writeExecuted = false;
  static const bool writeEligible = false;
  static const bool cutoverReadinessGranted = false;
  static const bool cutoverAuthorized = false;
  static const bool persistenceOwnerReplaced = false;
  static const bool persistenceEligibilityPromoted = false;
  static const bool medicationMaterializationEnabled = false;

  final String requestId;
  final PlantaoDrugProjectedEvidenceBundleOverlayStatus status;
  final PlantaoEvidenceBundle? candidateBundle;
  final List<String> addedRegimenKeys;
  final List<String> duplicateRegimenKeys;
  final List<String> reasons;
  final DateTime observedAt;

  bool get overlayPrepared =>
      status ==
          PlantaoDrugProjectedEvidenceBundleOverlayStatus.overlayPrepared &&
      candidateBundle != null;

  int get candidateDrugDocumentCount =>
      candidateBundle?.drugDocuments.length ?? 0;
}

class PlantaoDrugProjectedEvidenceBundleOverlayShadowAdapter {
  const PlantaoDrugProjectedEvidenceBundleOverlayShadowAdapter();

  PlantaoDrugProjectedEvidenceBundleOverlayShadowSnapshot prepare({
    required PlantaoRequest request,
    required PlantaoEvidenceBundle? baseEvidenceBundle,
    required PlantaoDrugExplicitTypedRegimenEvidenceProjectionShadowSnapshot
    projection,
  }) {
    request.ensureValid();

    if (projection.requestId != request.requestId) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProjectedEvidenceBundleOverlayStatus.stale,
        reasons: const <String>[
          'projected_evidence_bundle_overlay_request_id_mismatch',
        ],
      );
    }

    if (!projection.projectionRecorded) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProjectedEvidenceBundleOverlayStatus
            .projectionNotRecorded,
        reasons: <String>{
          'projected_evidence_bundle_overlay_projection_not_recorded',
          ...projection.reasons,
        },
      );
    }

    if (baseEvidenceBundle == null) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProjectedEvidenceBundleOverlayStatus
            .baseEvidenceUnavailable,
        reasons: const <String>[
          'projected_evidence_bundle_overlay_base_unavailable',
        ],
      );
    }

    try {
      final versions = <String, String>{...baseEvidenceBundle.documentVersions};
      final mergedDrugDocuments = <PlantaoDrugEvidenceDocument>[
        ...baseEvidenceBundle.drugDocuments,
      ];

      for (final retained in mergedDrugDocuments) {
        final recordedVersion = versions[retained.documentId];
        if (recordedVersion != null && recordedVersion != retained.version) {
          return _snapshot(
            requestId: request.requestId,
            status:
                PlantaoDrugProjectedEvidenceBundleOverlayStatus.versionMismatch,
            reasons: <String>[
              'projected_evidence_bundle_overlay_base_version_mismatch:'
                  '${retained.documentId}',
            ],
          );
        }
        versions.putIfAbsent(retained.documentId, () => retained.version);
      }

      final regimenKeys = <String>{...mergedDrugDocuments.map(_regimenKey)};
      final added = <String>[];
      final duplicates = <String>[];

      for (final projected in projection.projectedDocuments) {
        final retainedVersion = versions[projected.documentId];
        if (retainedVersion != null && retainedVersion != projected.version) {
          return _snapshot(
            requestId: request.requestId,
            status:
                PlantaoDrugProjectedEvidenceBundleOverlayStatus.versionMismatch,
            reasons: <String>[
              'projected_evidence_bundle_overlay_version_mismatch:'
                  '${projected.documentId}',
            ],
          );
        }

        versions[projected.documentId] = projected.version;
        final regimenKey = _regimenKey(projected);
        if (!regimenKeys.add(regimenKey)) {
          duplicates.add(regimenKey);
          continue;
        }
        mergedDrugDocuments.add(projected);
        added.add(regimenKey);
      }

      added.sort();
      duplicates.sort();

      final candidateBundle = PlantaoEvidenceBundle(
        requestId: baseEvidenceBundle.requestId,
        sessionIdHash: baseEvidenceBundle.sessionIdHash,
        locale: baseEvidenceBundle.locale,
        queryFingerprint: baseEvidenceBundle.queryFingerprint,
        protocolEvidence: baseEvidenceBundle.protocolEvidence,
        drugEvidence: baseEvidenceBundle.drugEvidence,
        validationStatus: baseEvidenceBundle.validationStatus,
        bundleHash: baseEvidenceBundle.bundleHash,
        createdAtEpochMs: baseEvidenceBundle.createdAtEpochMs,
        limitations: baseEvidenceBundle.limitations,
        clinicalDocuments: baseEvidenceBundle.clinicalDocuments,
        drugDocuments: mergedDrugDocuments,
        protocolDocuments: baseEvidenceBundle.protocolDocuments,
        patientFacts: baseEvidenceBundle.patientFacts,
        caseEvidence: baseEvidenceBundle.caseEvidence,
        externalGrounding: baseEvidenceBundle.externalGrounding,
        documentVersions: versions,
        coverage: PlantaoEvidenceCoverage(
          hasClinical: baseEvidenceBundle.coverage.hasClinical,
          hasDrug: mergedDrugDocuments.isNotEmpty,
          hasProtocol: baseEvidenceBundle.coverage.hasProtocol,
          hasPatientFacts: baseEvidenceBundle.coverage.hasPatientFacts,
        ),
        missingRequirements: baseEvidenceBundle.missingRequirements,
        retrievalStatus: baseEvidenceBundle.retrievalStatus,
      );

      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProjectedEvidenceBundleOverlayStatus.overlayPrepared,
        candidateBundle: candidateBundle,
        addedRegimenKeys: added,
        duplicateRegimenKeys: duplicates,
        reasons: <String>{
          'canonical_drug_projected_evidence_bundle_overlay_prepared',
          if (added.isEmpty)
            'projected_evidence_bundle_overlay_no_new_regimens'
          else
            'projected_evidence_bundle_overlay_regimens_added',
          if (duplicates.isNotEmpty)
            'projected_evidence_bundle_overlay_duplicates_deduplicated',
          'base_evidence_bundle_preserved',
          'validation_connection_not_authorized',
          'persistence_write_not_authorized',
        },
      );
    } catch (error) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugProjectedEvidenceBundleOverlayStatus.failed,
        reasons: <String>[
          'projected_evidence_bundle_overlay_failure:${error.runtimeType}',
        ],
      );
    }
  }

  static PlantaoDrugProjectedEvidenceBundleOverlayShadowSnapshot _snapshot({
    required String requestId,
    required PlantaoDrugProjectedEvidenceBundleOverlayStatus status,
    PlantaoEvidenceBundle? candidateBundle,
    Iterable<String> addedRegimenKeys = const <String>[],
    Iterable<String> duplicateRegimenKeys = const <String>[],
    Iterable<String> reasons = const <String>[],
  }) {
    return PlantaoDrugProjectedEvidenceBundleOverlayShadowSnapshot(
      requestId: requestId,
      status: status,
      candidateBundle: candidateBundle,
      addedRegimenKeys: addedRegimenKeys,
      duplicateRegimenKeys: duplicateRegimenKeys,
      reasons: reasons,
      observedAt: DateTime.now().toUtc(),
    );
  }
}

String _regimenKey(PlantaoDrugEvidenceDocument document) {
  return <Object?>[
    document.documentId,
    document.version,
    _normalize(document.drugName),
    document.dose,
    _normalize(document.unit),
    _normalize(document.route),
    _normalize(document.frequency),
  ].join('|');
}

String _normalize(String value) {
  return value.trim().toLowerCase();
}
