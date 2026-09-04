import '../contracts/plantao_request.dart';
import 'plantao_drug_identity_provenance_binding_shadow_adapter.dart';
import 'plantao_drug_provenance_persistence_review_envelope_shadow_adapter.dart';

enum PlantaoDrugPersistenceCutoverBlockerAuditStatus {
  blockersRecorded,
  reviewEnvelopeNotPrepared,
  stale,
  eligibilityMismatch,
  bindingMismatch,
  failed,
}

class PlantaoDrugPersistenceCutoverBlockerAuditShadowSnapshot {
  PlantaoDrugPersistenceCutoverBlockerAuditShadowSnapshot({
    required this.requestId,
    required this.status,
    required this.baseFuturePersistenceEligible,
    required this.hasCanonicalDrugEvidence,
    required this.hasTypedRegimenEvidence,
    required this.validatedDose,
    required this.hasMaterializedMedications,
    required this.persistenceRecordReady,
    required Iterable<String> blockers,
    required Iterable<String> reasons,
    required this.observedAt,
  }) : blockers = List<String>.unmodifiable(blockers),
       reasons = List<String>.unmodifiable(reasons);

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
  final PlantaoDrugPersistenceCutoverBlockerAuditStatus status;
  final bool baseFuturePersistenceEligible;
  final bool hasCanonicalDrugEvidence;
  final bool hasTypedRegimenEvidence;
  final bool validatedDose;
  final bool hasMaterializedMedications;
  final bool persistenceRecordReady;
  final List<String> blockers;
  final List<String> reasons;
  final DateTime observedAt;

  bool get blockersRecorded =>
      status ==
      PlantaoDrugPersistenceCutoverBlockerAuditStatus.blockersRecorded;
}

class PlantaoDrugPersistenceCutoverBlockerAuditShadowAdapter {
  const PlantaoDrugPersistenceCutoverBlockerAuditShadowAdapter();

  PlantaoDrugPersistenceCutoverBlockerAuditShadowSnapshot audit({
    required PlantaoRequest request,
    required bool baseFuturePersistenceEligible,
    required PlantaoDrugProvenancePersistenceReviewEnvelopeShadowSnapshot
    reviewEnvelope,
    required PlantaoDrugIdentityProvenanceBindingShadowSnapshot binding,
  }) {
    request.ensureValid();

    if (reviewEnvelope.requestId != request.requestId ||
        binding.requestId != request.requestId) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugPersistenceCutoverBlockerAuditStatus.stale,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: const <String>[
          'drug_persistence_cutover_blocker_audit_request_id_mismatch',
        ],
      );
    }

    if (!reviewEnvelope.reviewEnvelopePrepared) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugPersistenceCutoverBlockerAuditStatus
            .reviewEnvelopeNotPrepared,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: <String>{
          'drug_persistence_cutover_blocker_audit_review_not_prepared',
          ...reviewEnvelope.reasons,
        },
      );
    }

    if (reviewEnvelope.baseFuturePersistenceEligible !=
        baseFuturePersistenceEligible) {
      return _snapshot(
        requestId: request.requestId,
        status:
            PlantaoDrugPersistenceCutoverBlockerAuditStatus.eligibilityMismatch,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: const <String>[
          'drug_persistence_cutover_blocker_audit_eligibility_mismatch',
        ],
      );
    }

    try {
      final provenance = _stringObjectMap(reviewEnvelope.payload['provenance']);
      final payloadDrugIds = _stringSet(provenance?['matchedDrugDocumentIds']);
      final bindingDrugIds = binding.provenance.matchedDrugDocumentIds.toSet();
      final typedRegimenIds = binding.typedRegimenDocumentIds.toSet();

      if (!_setEquals(payloadDrugIds, bindingDrugIds) ||
          !bindingDrugIds.containsAll(binding.canonicalDocumentIds) ||
          !bindingDrugIds.containsAll(typedRegimenIds)) {
        return _snapshot(
          requestId: request.requestId,
          status:
              PlantaoDrugPersistenceCutoverBlockerAuditStatus.bindingMismatch,
          baseFuturePersistenceEligible: baseFuturePersistenceEligible,
          reasons: const <String>[
            'drug_persistence_cutover_blocker_audit_binding_mismatch',
          ],
        );
      }

      final hasCanonicalDrugEvidence =
          binding.identityEvidenceBound &&
          binding.canonicalDocumentIds.isNotEmpty;
      final hasTypedRegimenEvidence = typedRegimenIds.isNotEmpty;
      final validatedDose = provenance?['validatedDose'] == true;
      final medications = reviewEnvelope.payload['medications'];
      final hasMaterializedMedications =
          medications is Iterable && medications.isNotEmpty;
      final persistenceRecordReady =
          reviewEnvelope.payload['status'] == 'ready';

      final blockers = <String>[
        if (!baseFuturePersistenceEligible) 'base_persistence_not_eligible',
        if (!hasCanonicalDrugEvidence) 'canonical_drug_evidence_absent',
        if (!hasTypedRegimenEvidence) 'typed_regimen_evidence_absent',
        if (!validatedDose) 'dose_not_deterministically_validated',
        if (!hasMaterializedMedications) 'medication_materialization_absent',
        if (!persistenceRecordReady) 'persistence_record_not_ready',
        'productive_cutover_not_authorized',
      ];

      return _snapshot(
        requestId: request.requestId,
        status:
            PlantaoDrugPersistenceCutoverBlockerAuditStatus.blockersRecorded,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        hasCanonicalDrugEvidence: hasCanonicalDrugEvidence,
        hasTypedRegimenEvidence: hasTypedRegimenEvidence,
        validatedDose: validatedDose,
        hasMaterializedMedications: hasMaterializedMedications,
        persistenceRecordReady: persistenceRecordReady,
        blockers: blockers,
        reasons: const <String>[
          'canonical_drug_persistence_cutover_blockers_recorded',
          'manual_productive_cutover_review_required',
          'persistence_write_not_authorized',
        ],
      );
    } catch (error) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugPersistenceCutoverBlockerAuditStatus.failed,
        baseFuturePersistenceEligible: baseFuturePersistenceEligible,
        reasons: <String>[
          'drug_persistence_cutover_blocker_audit_failure:${error.runtimeType}',
        ],
      );
    }
  }

  static PlantaoDrugPersistenceCutoverBlockerAuditShadowSnapshot _snapshot({
    required String requestId,
    required PlantaoDrugPersistenceCutoverBlockerAuditStatus status,
    required bool baseFuturePersistenceEligible,
    bool hasCanonicalDrugEvidence = false,
    bool hasTypedRegimenEvidence = false,
    bool validatedDose = false,
    bool hasMaterializedMedications = false,
    bool persistenceRecordReady = false,
    Iterable<String> blockers = const <String>[],
    Iterable<String> reasons = const <String>[],
  }) {
    return PlantaoDrugPersistenceCutoverBlockerAuditShadowSnapshot(
      requestId: requestId,
      status: status,
      baseFuturePersistenceEligible: baseFuturePersistenceEligible,
      hasCanonicalDrugEvidence: hasCanonicalDrugEvidence,
      hasTypedRegimenEvidence: hasTypedRegimenEvidence,
      validatedDose: validatedDose,
      hasMaterializedMedications: hasMaterializedMedications,
      persistenceRecordReady: persistenceRecordReady,
      blockers: blockers,
      reasons: reasons,
      observedAt: DateTime.now().toUtc(),
    );
  }
}

Map<String, Object?>? _stringObjectMap(Object? value) {
  if (value is! Map) return null;
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) return null;
    result[entry.key as String] = entry.value;
  }
  return result;
}

Set<String> _stringSet(Object? value) {
  if (value is! Iterable) return const <String>{};
  return value.whereType<String>().toSet();
}

bool _setEquals(Set<String> left, Set<String> right) {
  return left.length == right.length && left.containsAll(right);
}
