/// PHASE3I-J2F7: controlled visual integration readiness contract.
///
/// This contract can only authorize a controlled visual integration test.
/// It never authorizes productive cutover, legacy removal, pharmacological
/// identity inference, dose validation or clinical content mutation.
enum ClinicalTreatmentVisualReadinessState {
  blocked,
  readyForControlledVisualIntegrationTest,
}

enum ClinicalTreatmentVisualReadinessBlocker {
  typedPresentationAbsent,
  legacyFallbackAbsent,
  contentLossDetected,
  duplicationDetected,
  languageMixDetected,
  narrowWidthOverflowDetected,
  safetySeparationMissing,
  canonicalIdentityAuthorityDetected,
  doseValidationAuthorityDetected,
}

final class ClinicalTreatmentVisualReadinessInput {
  const ClinicalTreatmentVisualReadinessInput({
    required this.typedPresentationPresent,
    required this.legacyFallbackAvailable,
    required this.contentLossDetected,
    required this.duplicationDetected,
    required this.languageMixDetected,
    required this.narrowWidthOverflowDetected,
    required this.safetySeparationPreserved,
    required this.canonicalIdentityAuthorityDetected,
    required this.doseValidationAuthorityDetected,
  });

  final bool typedPresentationPresent;
  final bool legacyFallbackAvailable;
  final bool contentLossDetected;
  final bool duplicationDetected;
  final bool languageMixDetected;
  final bool narrowWidthOverflowDetected;
  final bool safetySeparationPreserved;
  final bool canonicalIdentityAuthorityDetected;
  final bool doseValidationAuthorityDetected;
}

final class ClinicalTreatmentVisualReadinessReport {
  ClinicalTreatmentVisualReadinessReport._({
    required this.state,
    required List<ClinicalTreatmentVisualReadinessBlocker> blockers,
  }) : blockers = List.unmodifiable(blockers);

  final ClinicalTreatmentVisualReadinessState state;
  final List<ClinicalTreatmentVisualReadinessBlocker> blockers;

  bool get isReadyForControlledVisualIntegrationTest =>
      state ==
          ClinicalTreatmentVisualReadinessState
              .readyForControlledVisualIntegrationTest &&
      blockers.isEmpty;

  bool get authorizesProductiveCutover => false;
  bool get authorizesLegacyRemoval => false;
  bool get authorizesCanonicalDrugIdentity => false;
  bool get authorizesDoseValidationOrRepair => false;
}

abstract final class ClinicalTreatmentVisualReadinessEvaluator {
  static ClinicalTreatmentVisualReadinessReport evaluate(
    ClinicalTreatmentVisualReadinessInput input,
  ) {
    final blockers = <ClinicalTreatmentVisualReadinessBlocker>[
      if (!input.typedPresentationPresent)
        ClinicalTreatmentVisualReadinessBlocker.typedPresentationAbsent,
      if (!input.legacyFallbackAvailable)
        ClinicalTreatmentVisualReadinessBlocker.legacyFallbackAbsent,
      if (input.contentLossDetected)
        ClinicalTreatmentVisualReadinessBlocker.contentLossDetected,
      if (input.duplicationDetected)
        ClinicalTreatmentVisualReadinessBlocker.duplicationDetected,
      if (input.languageMixDetected)
        ClinicalTreatmentVisualReadinessBlocker.languageMixDetected,
      if (input.narrowWidthOverflowDetected)
        ClinicalTreatmentVisualReadinessBlocker.narrowWidthOverflowDetected,
      if (!input.safetySeparationPreserved)
        ClinicalTreatmentVisualReadinessBlocker.safetySeparationMissing,
      if (input.canonicalIdentityAuthorityDetected)
        ClinicalTreatmentVisualReadinessBlocker
            .canonicalIdentityAuthorityDetected,
      if (input.doseValidationAuthorityDetected)
        ClinicalTreatmentVisualReadinessBlocker.doseValidationAuthorityDetected,
    ];

    return ClinicalTreatmentVisualReadinessReport._(
      state: blockers.isEmpty
          ? ClinicalTreatmentVisualReadinessState
              .readyForControlledVisualIntegrationTest
          : ClinicalTreatmentVisualReadinessState.blocked,
      blockers: blockers,
    );
  }
}
