import '../contracts/plantao_evidence_bundle.dart';
import '../contracts/plantao_provenance.dart';
import '../contracts/plantao_request.dart';
import '../contracts/plantao_drug_relation.dart';
import '../ports/plantao_provider_port.dart';
import 'plantao_deterministic_drug_validator.dart';
import 'plantao_finalization_shadow_snapshot.dart';

enum PlantaoValidationShadowStatus {
  notEvaluated,
  validated,
  incompleteEvidence,
  blocked,
  failed,
}

class PlantaoValidationShadowSnapshot {
  PlantaoValidationShadowSnapshot({
    required this.requestId,
    required this.status,
    required this.routePlan,
    required this.provenance,
    required Iterable<PlantaoMedicationItem> medications,
    required Iterable<String> reasons,
    required this.strictModeCompatible,
    required this.observedAt,
  }) : medications = List<PlantaoMedicationItem>.unmodifiable(medications),
       reasons = List<String>.unmodifiable(reasons);

  static const bool productiveExecutionEnabled = false;
  static const bool providerConnected = false;
  static const bool renderingEnabled = false;
  static const bool persistenceEnabled = false;
  static const bool ragConnected = false;

  final String requestId;
  final PlantaoValidationShadowStatus status;
  final PlantaoProviderRoutePlan routePlan;
  final PlantaoProvenance provenance;
  final List<PlantaoMedicationItem> medications;
  final List<String> reasons;
  final bool strictModeCompatible;
  final DateTime observedAt;
}

class PlantaoValidationShadowAdapter {
  const PlantaoValidationShadowAdapter();

  PlantaoValidationShadowSnapshot observeWithoutRetrieval({
    required PlantaoRequest request,
    required PlantaoFinalizationShadowSnapshot finalization,
  }) {
    return validate(
      request: request,
      finalization: finalization,
      evidenceBundle: PlantaoEvidenceBundle.empty(
        missingRequirements: const <String>[
          'phase3e_retrieval_not_connected',
          'typed_medication_candidates_not_extracted',
        ],
      ),
      candidates: const <PlantaoMedicationCandidate>[],
    );
  }

  PlantaoValidationShadowSnapshot validate({
    required PlantaoRequest request,
    required PlantaoFinalizationShadowSnapshot finalization,
    required PlantaoEvidenceBundle evidenceBundle,
    Iterable<PlantaoMedicationCandidate> candidates =
        const <PlantaoMedicationCandidate>[],
    PlantaoProviderRoutePlan? routePlan,
  }) {
    request.ensureValid();
    final resolvedRoute =
        routePlan ?? PlantaoProviderRoutePlan.currentPlantaoPaidFirst();
    final candidateList = List<PlantaoMedicationCandidate>.unmodifiable(
      candidates,
    );
    final validation = PlantaoDeterministicDrugValidator.validate(
      candidates: candidateList,
      evidenceBundle: evidenceBundle,
    );

    var status = _mapStatus(validation.status);
    final reasons = <String>{
      ...validation.reasons,
      ...evidenceBundle.missingRequirements,
    }.toList();
    final containsSensitivePharmacology =
        candidateList.isNotEmpty || finalization.deferredMedicationCount > 0;

    if (candidateList.isEmpty &&
        finalization.deferredMedicationCount > 0 &&
        !evidenceBundle.hasDeterministicDrugEvidence) {
      status = PlantaoValidationShadowStatus.incompleteEvidence;
      reasons.add('deferred_medications_without_deterministic_evidence');
    }

    final provenance = PlantaoProvenance(
      provider: 'shadow_route_plan_not_executed',
      model: 'unexecuted',
      sourceMode: _sourceMode(evidenceBundle),
      matchedClinicalDocumentIds: <String>{
        ...evidenceBundle.clinicalDocuments.map((item) => item.documentId),
        ...evidenceBundle.protocolDocuments.map((item) => item.documentId),
      },
      matchedDrugDocumentIds: validation.matchedDrugDocumentIds,
      validatedDose: validation.validatedDose,
      validatorReason: reasons.join(';'),
      usedExternalGrounding: evidenceBundle.externalGrounding.isNotEmpty,
      continuationType: request.continuationType,
      documentVersions: _documentVersions(evidenceBundle),
    );

    final strictModeCompatible =
        !request.strictClinicalMode ||
        provenance.isStrictModeCompatible(
          containsSensitivePharmacology: containsSensitivePharmacology,
        );

    if (!strictModeCompatible &&
        status == PlantaoValidationShadowStatus.notEvaluated) {
      status = PlantaoValidationShadowStatus.incompleteEvidence;
      reasons.add('strict_mode_model_native_pharmacology_not_compatible');
    }

    return PlantaoValidationShadowSnapshot(
      requestId: request.requestId,
      status: status,
      routePlan: resolvedRoute,
      provenance: PlantaoProvenance(
        provider: provenance.provider,
        model: provenance.model,
        sourceMode: provenance.sourceMode,
        matchedClinicalDocumentIds: provenance.matchedClinicalDocumentIds,
        matchedDrugDocumentIds: provenance.matchedDrugDocumentIds,
        validatedDose: provenance.validatedDose,
        validatorReason: reasons.join(';'),
        usedExternalGrounding: provenance.usedExternalGrounding,
        continuationType: provenance.continuationType,
        documentVersions: provenance.documentVersions,
      ),
      medications: validation.medications,
      reasons: reasons,
      strictModeCompatible: strictModeCompatible,
      observedAt: DateTime.now().toUtc(),
    );
  }

  static PlantaoValidationShadowStatus _mapStatus(
    PlantaoDeterministicValidationStatus status,
  ) {
    switch (status) {
      case PlantaoDeterministicValidationStatus.notEvaluated:
        return PlantaoValidationShadowStatus.notEvaluated;
      case PlantaoDeterministicValidationStatus.validated:
        return PlantaoValidationShadowStatus.validated;
      case PlantaoDeterministicValidationStatus.incompleteEvidence:
        return PlantaoValidationShadowStatus.incompleteEvidence;
      case PlantaoDeterministicValidationStatus.blocked:
        return PlantaoValidationShadowStatus.blocked;
    }
  }

  static PlantaoSourceMode _sourceMode(PlantaoEvidenceBundle bundle) {
    if (bundle.isEmpty) return PlantaoSourceMode.modelNative;
    if (bundle.externalGrounding.isNotEmpty &&
        (bundle.clinicalDocuments.isNotEmpty ||
            bundle.drugDocuments.isNotEmpty ||
            bundle.protocolDocuments.isNotEmpty)) {
      return PlantaoSourceMode.mixed;
    }
    if (bundle.externalGrounding.isNotEmpty) {
      return PlantaoSourceMode.externalGrounding;
    }
    return PlantaoSourceMode.localRag;
  }

  static Map<String, String> _documentVersions(PlantaoEvidenceBundle bundle) {
    final versions = <String, String>{...bundle.documentVersions};
    final documents = <PlantaoEvidenceDocument>[
      ...bundle.clinicalDocuments,
      ...bundle.drugDocuments,
      ...bundle.protocolDocuments,
      ...bundle.patientFacts,
      ...bundle.caseEvidence,
      ...bundle.externalGrounding,
    ];
    for (final document in documents) {
      versions.putIfAbsent(document.documentId, () => document.version);
    }
    return versions;
  }
}
