import '../contracts/plantao_canonical_drug_evidence.dart';
import '../contracts/plantao_provenance.dart';
import '../contracts/plantao_request.dart';
import 'plantao_drug_evidence_finalization_join_shadow_adapter.dart';

enum PlantaoDrugIdentityProvenanceBindingStatus {
  identityEvidenceBound,
  notEvaluated,
  empty,
  ambiguous,
  missing,
  timedOut,
  stale,
  failed,
}

class PlantaoDrugIdentityProvenanceBindingShadowSnapshot {
  PlantaoDrugIdentityProvenanceBindingShadowSnapshot({
    required this.requestId,
    required this.status,
    required this.provenance,
    required Iterable<String> canonicalDocumentIds,
    required Iterable<String> typedRegimenDocumentIds,
    required Map<String, String> documentVersions,
    required Iterable<String> reasons,
    required this.observedAt,
  }) : canonicalDocumentIds = List<String>.unmodifiable(canonicalDocumentIds),
       typedRegimenDocumentIds = List<String>.unmodifiable(
         typedRegimenDocumentIds,
       ),
       documentVersions = Map<String, String>.unmodifiable(documentVersions),
       reasons = List<String>.unmodifiable(reasons);

  static const bool baseValidationModified = false;
  static const bool validatedDoseUpgraded = false;
  static const bool medicationCandidateBound = false;
  static const bool medicationMaterializationEnabled = false;
  static const bool productivePersistenceConnected = false;
  static const bool productiveRenderingConnected = false;

  final String requestId;
  final PlantaoDrugIdentityProvenanceBindingStatus status;
  final PlantaoProvenance provenance;
  final List<String> canonicalDocumentIds;
  final List<String> typedRegimenDocumentIds;
  final Map<String, String> documentVersions;
  final List<String> reasons;
  final DateTime observedAt;

  bool get identityEvidenceBound =>
      status ==
          PlantaoDrugIdentityProvenanceBindingStatus.identityEvidenceBound &&
      canonicalDocumentIds.isNotEmpty;
}

class PlantaoDrugIdentityProvenanceBindingShadowAdapter {
  const PlantaoDrugIdentityProvenanceBindingShadowAdapter();

  PlantaoDrugIdentityProvenanceBindingShadowSnapshot bind({
    required PlantaoRequest request,
    required String validationRequestId,
    required PlantaoProvenance validationProvenance,
    required PlantaoDrugEvidenceFinalizationJoinShadowSnapshot join,
  }) {
    request.ensureValid();

    if (validationRequestId != request.requestId ||
        join.requestId != request.requestId) {
      return _snapshot(
        requestId: request.requestId,
        status: PlantaoDrugIdentityProvenanceBindingStatus.stale,
        provenance: validationProvenance,
        reasons: const <String>['drug_identity_provenance_request_id_mismatch'],
      );
    }

    if (join.status != PlantaoDrugEvidenceFinalizationJoinStatus.ready ||
        join.evidenceDocumentIds.isEmpty) {
      return _snapshot(
        requestId: request.requestId,
        status: _status(join.status),
        provenance: validationProvenance,
        canonicalDocumentIds: join.evidenceDocumentIds,
        documentVersions: join.documentVersions,
        reasons: <String>{
          'drug_identity_provenance_not_bound',
          ...join.reasons,
        },
      );
    }

    final documents =
        join.drugEvidence?.evidence.documents ??
        const <PlantaoCanonicalDrugEvidenceDocument>[];
    final typedRegimenDocumentIds = documents
        .where((document) => document.supportsMedicationMaterialization)
        .map((document) => document.documentId)
        .toList(growable: false);

    final canonicalDocumentIds = <String>{
      ...validationProvenance.matchedDrugDocumentIds,
      ...join.evidenceDocumentIds,
    }.toList(growable: false);
    final versions = <String, String>{
      ...validationProvenance.documentVersions,
      ...join.documentVersions,
    };
    final reasons = <String>{
      if (validationProvenance.validatorReason.trim().isNotEmpty)
        validationProvenance.validatorReason,
      'canonical_drug_identity_provenance_bound',
      'drug_identity_evidence_not_used_for_dose_validation',
      if (typedRegimenDocumentIds.isEmpty) 'typed_regimen_unavailable',
      ...join.reasons,
    };

    final provenance = PlantaoProvenance(
      provider: validationProvenance.provider,
      model: validationProvenance.model,
      sourceMode: _sourceMode(validationProvenance.sourceMode),
      matchedClinicalDocumentIds:
          validationProvenance.matchedClinicalDocumentIds,
      matchedDrugDocumentIds: canonicalDocumentIds,
      validatedDose: validationProvenance.validatedDose,
      validatorReason: reasons.join(';'),
      usedExternalGrounding: validationProvenance.usedExternalGrounding,
      continuationType: validationProvenance.continuationType,
      documentVersions: versions,
    );

    return _snapshot(
      requestId: request.requestId,
      status: PlantaoDrugIdentityProvenanceBindingStatus.identityEvidenceBound,
      provenance: provenance,
      canonicalDocumentIds: canonicalDocumentIds,
      typedRegimenDocumentIds: typedRegimenDocumentIds,
      documentVersions: versions,
      reasons: reasons,
    );
  }

  static PlantaoSourceMode _sourceMode(PlantaoSourceMode current) {
    switch (current) {
      case PlantaoSourceMode.modelNative:
        return PlantaoSourceMode.localRag;
      case PlantaoSourceMode.firestoreRag:
      case PlantaoSourceMode.externalGrounding:
        return PlantaoSourceMode.mixed;
      case PlantaoSourceMode.localRag:
      case PlantaoSourceMode.mixed:
        return current;
    }
  }

  static PlantaoDrugIdentityProvenanceBindingStatus _status(
    PlantaoDrugEvidenceFinalizationJoinStatus status,
  ) {
    switch (status) {
      case PlantaoDrugEvidenceFinalizationJoinStatus.ready:
        return PlantaoDrugIdentityProvenanceBindingStatus.empty;
      case PlantaoDrugEvidenceFinalizationJoinStatus.notEvaluated:
        return PlantaoDrugIdentityProvenanceBindingStatus.notEvaluated;
      case PlantaoDrugEvidenceFinalizationJoinStatus.empty:
        return PlantaoDrugIdentityProvenanceBindingStatus.empty;
      case PlantaoDrugEvidenceFinalizationJoinStatus.ambiguous:
        return PlantaoDrugIdentityProvenanceBindingStatus.ambiguous;
      case PlantaoDrugEvidenceFinalizationJoinStatus.missing:
        return PlantaoDrugIdentityProvenanceBindingStatus.missing;
      case PlantaoDrugEvidenceFinalizationJoinStatus.timedOut:
        return PlantaoDrugIdentityProvenanceBindingStatus.timedOut;
      case PlantaoDrugEvidenceFinalizationJoinStatus.stale:
        return PlantaoDrugIdentityProvenanceBindingStatus.stale;
      case PlantaoDrugEvidenceFinalizationJoinStatus.failed:
        return PlantaoDrugIdentityProvenanceBindingStatus.failed;
    }
  }

  static PlantaoDrugIdentityProvenanceBindingShadowSnapshot _snapshot({
    required String requestId,
    required PlantaoDrugIdentityProvenanceBindingStatus status,
    required PlantaoProvenance provenance,
    Iterable<String> canonicalDocumentIds = const <String>[],
    Iterable<String> typedRegimenDocumentIds = const <String>[],
    Map<String, String> documentVersions = const <String, String>{},
    Iterable<String> reasons = const <String>[],
  }) {
    return PlantaoDrugIdentityProvenanceBindingShadowSnapshot(
      requestId: requestId,
      status: status,
      provenance: provenance,
      canonicalDocumentIds: canonicalDocumentIds,
      typedRegimenDocumentIds: typedRegimenDocumentIds,
      documentVersions: documentVersions,
      reasons: reasons,
      observedAt: DateTime.now().toUtc(),
    );
  }
}
