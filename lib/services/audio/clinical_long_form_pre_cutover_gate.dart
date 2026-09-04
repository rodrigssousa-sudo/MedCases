enum ClinicalLongFormPreCutoverRequirement {
  localEngineCertified,
  remoteContractCertified,
  localSensitiveAtRestArchitectureCertified,
  localSensitiveAtRestPlatformEnforcementCertified,
  pcmPhysicalHomologated,
  longFormPhysicalHomologated,
  realBackendTransportImplemented,
  realBackendTransportSandboxCertified,
  realBackendGrantProviderCertified,
  realNoRetentionVerifierCertified,
  privacyDisclosureRemoteCompatible,
  explicitRemoteAudioConsentUiCertified,
  openAiStandardKeyAbsentFromFlutter,
  productionOwnersRemainUnwired,
}

enum ClinicalLongFormPreCutoverDecision {
  blocked,
  eligible,
}

final class ClinicalLongFormPreCutoverEvidence {
  const ClinicalLongFormPreCutoverEvidence({
    required this.localEngineCertified,
    required this.remoteContractCertified,
    required this.localSensitiveAtRestArchitectureCertified,
    required this.localSensitiveAtRestPlatformEnforcementCertified,
    required this.pcmPhysicalHomologated,
    required this.longFormPhysicalHomologated,
    required this.realBackendTransportImplemented,
    required this.realBackendTransportSandboxCertified,
    required this.realBackendGrantProviderCertified,
    required this.realNoRetentionVerifierCertified,
    required this.privacyDisclosureRemoteCompatible,
    required this.explicitRemoteAudioConsentUiCertified,
    required this.openAiStandardKeyAbsentFromFlutter,
    required this.productionOwnersRemainUnwired,
  });

  factory ClinicalLongFormPreCutoverEvidence.currentCertifiedFoundation() {
    return const ClinicalLongFormPreCutoverEvidence(
      localEngineCertified: true,
      remoteContractCertified: true,
      localSensitiveAtRestArchitectureCertified: true,
      localSensitiveAtRestPlatformEnforcementCertified: true,
      pcmPhysicalHomologated: true,
      longFormPhysicalHomologated: true,
      realBackendTransportImplemented: true,
      realBackendTransportSandboxCertified: true,
      realBackendGrantProviderCertified: true,
      realNoRetentionVerifierCertified: true,
      privacyDisclosureRemoteCompatible: true,
      explicitRemoteAudioConsentUiCertified: true,
      openAiStandardKeyAbsentFromFlutter: true,
      productionOwnersRemainUnwired: true,
    );
  }

  final bool localEngineCertified;
  final bool remoteContractCertified;
  final bool localSensitiveAtRestArchitectureCertified;
  final bool localSensitiveAtRestPlatformEnforcementCertified;
  final bool pcmPhysicalHomologated;
  final bool longFormPhysicalHomologated;
  final bool realBackendTransportImplemented;
  final bool realBackendTransportSandboxCertified;
  final bool realBackendGrantProviderCertified;
  final bool realNoRetentionVerifierCertified;
  final bool privacyDisclosureRemoteCompatible;
  final bool explicitRemoteAudioConsentUiCertified;
  final bool openAiStandardKeyAbsentFromFlutter;
  final bool productionOwnersRemainUnwired;
}

final class ClinicalLongFormPreCutoverAssessment {
  const ClinicalLongFormPreCutoverAssessment({
    required this.decision,
    required this.blockers,
  });

  final ClinicalLongFormPreCutoverDecision decision;
  final List<ClinicalLongFormPreCutoverRequirement> blockers;

  bool get eligible =>
      decision == ClinicalLongFormPreCutoverDecision.eligible &&
      blockers.isEmpty;
}

final class ClinicalLongFormPreCutoverGate {
  const ClinicalLongFormPreCutoverGate();

  static const bool productionCutoverEnabled = false;
  static const bool gateMaySelfActivateProduction = false;
  static const bool physicalEvidenceMayBeAssumed = false;
  static const bool privacyCompatibilityMayBeAssumed = false;
  static const bool realTransportMayBeAssumed = false;
  static const bool atRestPlatformEnforcementMayBeAssumed = false;

  ClinicalLongFormPreCutoverAssessment evaluate(
    ClinicalLongFormPreCutoverEvidence evidence,
  ) {
    final blockers = <ClinicalLongFormPreCutoverRequirement>[];

    void require(
      bool satisfied,
      ClinicalLongFormPreCutoverRequirement requirement,
    ) {
      if (!satisfied) {
        blockers.add(requirement);
      }
    }

    require(
      evidence.localEngineCertified,
      ClinicalLongFormPreCutoverRequirement.localEngineCertified,
    );
    require(
      evidence.remoteContractCertified,
      ClinicalLongFormPreCutoverRequirement.remoteContractCertified,
    );
    require(
      evidence.localSensitiveAtRestArchitectureCertified,
      ClinicalLongFormPreCutoverRequirement
          .localSensitiveAtRestArchitectureCertified,
    );
    require(
      evidence.localSensitiveAtRestPlatformEnforcementCertified,
      ClinicalLongFormPreCutoverRequirement
          .localSensitiveAtRestPlatformEnforcementCertified,
    );
    require(
      evidence.pcmPhysicalHomologated,
      ClinicalLongFormPreCutoverRequirement.pcmPhysicalHomologated,
    );
    require(
      evidence.longFormPhysicalHomologated,
      ClinicalLongFormPreCutoverRequirement.longFormPhysicalHomologated,
    );
    require(
      evidence.realBackendTransportImplemented,
      ClinicalLongFormPreCutoverRequirement.realBackendTransportImplemented,
    );
    require(
      evidence.realBackendTransportSandboxCertified,
      ClinicalLongFormPreCutoverRequirement
          .realBackendTransportSandboxCertified,
    );
    require(
      evidence.realBackendGrantProviderCertified,
      ClinicalLongFormPreCutoverRequirement.realBackendGrantProviderCertified,
    );
    require(
      evidence.realNoRetentionVerifierCertified,
      ClinicalLongFormPreCutoverRequirement.realNoRetentionVerifierCertified,
    );
    require(
      evidence.privacyDisclosureRemoteCompatible,
      ClinicalLongFormPreCutoverRequirement.privacyDisclosureRemoteCompatible,
    );
    require(
      evidence.explicitRemoteAudioConsentUiCertified,
      ClinicalLongFormPreCutoverRequirement
          .explicitRemoteAudioConsentUiCertified,
    );
    require(
      evidence.openAiStandardKeyAbsentFromFlutter,
      ClinicalLongFormPreCutoverRequirement.openAiStandardKeyAbsentFromFlutter,
    );
    require(
      evidence.productionOwnersRemainUnwired,
      ClinicalLongFormPreCutoverRequirement.productionOwnersRemainUnwired,
    );

    return ClinicalLongFormPreCutoverAssessment(
      decision: blockers.isEmpty
          ? ClinicalLongFormPreCutoverDecision.eligible
          : ClinicalLongFormPreCutoverDecision.blocked,
      blockers: List<ClinicalLongFormPreCutoverRequirement>.unmodifiable(
        blockers,
      ),
    );
  }
}
