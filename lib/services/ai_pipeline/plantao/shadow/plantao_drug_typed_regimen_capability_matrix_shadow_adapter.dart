import '../contracts/plantao_request.dart';
import 'plantao_drug_evidence_finalization_join_shadow_adapter.dart';
import 'plantao_drug_identity_provenance_binding_shadow_adapter.dart';
import 'plantao_drug_persistence_cutover_blocker_audit_shadow_adapter.dart';

enum PlantaoDrugTypedRegimenCapabilityMatrixStatus {
  capabilityMatrixRecorded,
  blockerAuditNotRecorded,
  joinNotReady,
  stale,
  bindingMismatch,
  failed,
}

class PlantaoDrugTypedRegimenCapabilityEntry {
  PlantaoDrugTypedRegimenCapabilityEntry({
    required this.documentId,
    required this.documentVersion,
    required this.completeness,
    required this.supportsMedicationMaterialization,
    required this.boundAsCanonicalIdentity,
    required this.boundAsTypedRegimen,
    required Iterable<String> gaps,
  }) : gaps = List<String>.unmodifiable(gaps);

  final String documentId;
  final String documentVersion;
  final String completeness;
  final bool supportsMedicationMaterialization;
  final bool boundAsCanonicalIdentity;
  final bool boundAsTypedRegimen;
  final List<String> gaps;
}

class PlantaoDrugTypedRegimenCapabilityMatrixShadowSnapshot {
  PlantaoDrugTypedRegimenCapabilityMatrixShadowSnapshot({
    required this.requestId,
    required this.status,
    required Iterable<PlantaoDrugTypedRegimenCapabilityEntry> entries,
    required Iterable<String> unresolvedGaps,
    required Iterable<String> reasons,
    required this.observedAt,
  }) : entries = List<PlantaoDrugTypedRegimenCapabilityEntry>.unmodifiable(
         entries,
       ),
       unresolvedGaps = List<String>.unmodifiable(unresolvedGaps),
       reasons = List<String>.unmodifiable(reasons);

  static const bool freeTextDoseExtractionEnabled = false;
  static const bool freeTextRouteExtractionEnabled = false;
  static const bool freeTextFrequencyExtractionEnabled = false;
  static const bool inferredTypedRegimenEnabled = false;
  static const bool firestoreConnected = false;
  static const bool writeExecuted = false;
  static const bool writeEligible = false;
  static const bool cutoverReadinessGranted = false;
  static const bool cutoverAuthorized = false;
  static const bool persistenceOwnerReplaced = false;
  static const bool persistenceEligibilityPromoted = false;
  static const bool medicationMaterializationEnabled = false;
  static const bool productiveRenderingConnected = false;

  final String requestId;
  final PlantaoDrugTypedRegimenCapabilityMatrixStatus status;
  final List<PlantaoDrugTypedRegimenCapabilityEntry> entries;
  final List<String> unresolvedGaps;
  final List<String> reasons;
  final DateTime observedAt;

  bool get capabilityMatrixRecorded =>
      status ==
      PlantaoDrugTypedRegimenCapabilityMatrixStatus.capabilityMatrixRecorded;

  int get canonicalDocumentCount => entries.length;

  int get typedRegimenCapableCount =>
      entries.where((entry) => entry.supportsMedicationMaterialization).length;

  int get typedRegimenBoundCount =>
      entries.where((entry) => entry.boundAsTypedRegimen).length;
}

class PlantaoDrugTypedRegimenCapabilityMatrixShadowAdapter {
  const PlantaoDrugTypedRegimenCapabilityMatrixShadowAdapter();

  PlantaoDrugTypedRegimenCapabilityMatrixShadowSnapshot audit({
    required PlantaoRequest request,
    required PlantaoDrugEvidenceFinalizationJoinShadowSnapshot join,
    required PlantaoDrugIdentityProvenanceBindingShadowSnapshot binding,
    required PlantaoDrugPersistenceCutoverBlockerAuditShadowSnapshot
    cutoverBlockerAudit,
  }) {
    request.ensureValid();

    if (join.requestId != request.requestId ||
        binding.requestId != request.requestId ||
        cutoverBlockerAudit.requestId != request.requestId) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugTypedRegimenCapabilityMatrixStatus.stale,
        reasons: const <String>[
          'typed_regimen_capability_matrix_request_id_mismatch',
        ],
      );
    }

    if (!cutoverBlockerAudit.blockersRecorded) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugTypedRegimenCapabilityMatrixStatus
            .blockerAuditNotRecorded,
        reasons: <String>{
          'typed_regimen_capability_matrix_blocker_audit_not_recorded',
          ...cutoverBlockerAudit.reasons,
        },
      );
    }

    if (join.status != PlantaoDrugEvidenceFinalizationJoinStatus.ready ||
        join.drugEvidence == null ||
        join.evidenceDocumentIds.isEmpty) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugTypedRegimenCapabilityMatrixStatus.joinNotReady,
        reasons: <String>{
          'typed_regimen_capability_matrix_join_not_ready',
          ...join.reasons,
        },
      );
    }

    try {
      final documents = join.drugEvidence!.evidence.documents;
      final documentIds = documents
          .map((document) => document.documentId)
          .toSet();
      final evidenceIds = join.evidenceDocumentIds.toSet();
      final canonicalIds = binding.canonicalDocumentIds.toSet();
      final typedRegimenIds = binding.typedRegimenDocumentIds.toSet();

      if (!_setEquals(documentIds, evidenceIds) ||
          !canonicalIds.containsAll(evidenceIds) ||
          !documentIds.containsAll(typedRegimenIds)) {
        return _snapshot(
          requestId: request.requestId,
          status: PlantaoDrugTypedRegimenCapabilityMatrixStatus.bindingMismatch,
          reasons: const <String>[
            'typed_regimen_capability_matrix_binding_mismatch',
          ],
        );
      }

      final entries = <PlantaoDrugTypedRegimenCapabilityEntry>[];
      final unresolvedGaps = <String>[];

      for (final document in documents) {
        final documentId = document.documentId;
        final documentVersion =
            join.documentVersions[documentId] ??
            binding.documentVersions[documentId] ??
            '';
        final supportsMaterialization =
            document.supportsMedicationMaterialization;
        final boundAsTypedRegimen = typedRegimenIds.contains(documentId);
        final gaps = <String>[
          if (!canonicalIds.contains(documentId))
            'canonical_identity_binding_absent',
          if (documentVersion.trim().isEmpty) 'document_version_absent',
          if (!supportsMaterialization) 'typed_regimen_contract_unavailable',
          if (supportsMaterialization && !boundAsTypedRegimen)
            'typed_regimen_binding_absent',
          if (!supportsMaterialization && boundAsTypedRegimen)
            'typed_regimen_binding_inconsistent',
        ];

        entries.add(
          PlantaoDrugTypedRegimenCapabilityEntry(
            documentId: documentId,
            documentVersion: documentVersion,
            completeness: document.completeness.name,
            supportsMedicationMaterialization: supportsMaterialization,
            boundAsCanonicalIdentity: canonicalIds.contains(documentId),
            boundAsTypedRegimen: boundAsTypedRegimen,
            gaps: gaps,
          ),
        );
        unresolvedGaps.addAll(gaps.map((gap) => '$documentId:$gap'));
      }

      entries.sort(
        (left, right) => left.documentId.compareTo(right.documentId),
      );
      unresolvedGaps.sort();

      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugTypedRegimenCapabilityMatrixStatus
            .capabilityMatrixRecorded,
        entries: entries,
        unresolvedGaps: unresolvedGaps,
        reasons: <String>{
          'canonical_drug_typed_regimen_capability_matrix_recorded',
          if (unresolvedGaps.isEmpty)
            'typed_regimen_capability_complete'
          else
            'typed_regimen_capability_gaps_present',
          'free_text_regimen_inference_not_authorized',
          'persistence_write_not_authorized',
        },
      );
    } catch (error) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugTypedRegimenCapabilityMatrixStatus.failed,
        reasons: <String>[
          'typed_regimen_capability_matrix_failure:${error.runtimeType}',
        ],
      );
    }
  }

  static PlantaoDrugTypedRegimenCapabilityMatrixShadowSnapshot _snapshot({
    required String requestId,
    required PlantaoDrugTypedRegimenCapabilityMatrixStatus status,
    Iterable<PlantaoDrugTypedRegimenCapabilityEntry> entries =
        const <PlantaoDrugTypedRegimenCapabilityEntry>[],
    Iterable<String> unresolvedGaps = const <String>[],
    Iterable<String> reasons = const <String>[],
  }) {
    return PlantaoDrugTypedRegimenCapabilityMatrixShadowSnapshot(
      requestId: requestId,
      status: status,
      entries: entries,
      unresolvedGaps: unresolvedGaps,
      reasons: reasons,
      observedAt: DateTime.now().toUtc(),
    );
  }
}

bool _setEquals(Set<String> left, Set<String> right) {
  return left.length == right.length && left.containsAll(right);
}
