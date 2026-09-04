import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_long_form_pre_cutover_gate.dart';

void main() {
  test(
    'current foundation has native at-rest and real backend sandbox certified',
    () {
      const gate = ClinicalLongFormPreCutoverGate();
      final assessment = gate.evaluate(
        ClinicalLongFormPreCutoverEvidence.currentCertifiedFoundation(),
      );

      expect(assessment.eligible, isTrue);
      expect(assessment.blockers, isEmpty);

      expect(
        assessment.blockers,
        isNot(
          contains(
            ClinicalLongFormPreCutoverRequirement
                .localSensitiveAtRestArchitectureCertified,
          ),
        ),
      );
      expect(
        assessment.blockers,
        isNot(
          contains(
            ClinicalLongFormPreCutoverRequirement
                .localSensitiveAtRestPlatformEnforcementCertified,
          ),
        ),
      );
      expect(
        assessment.blockers,
        isNot(contains(
          ClinicalLongFormPreCutoverRequirement.pcmPhysicalHomologated,
        )),
      );
      expect(
        assessment.blockers,
        isNot(contains(
          ClinicalLongFormPreCutoverRequirement.longFormPhysicalHomologated,
        )),
      );
      expect(
        assessment.blockers,
        isNot(
          contains(
            ClinicalLongFormPreCutoverRequirement
                .realBackendTransportSandboxCertified,
          ),
        ),
      );
      expect(
        assessment.blockers,
        isNot(contains(
          ClinicalLongFormPreCutoverRequirement
              .privacyDisclosureRemoteCompatible,
        )),
      );
      expect(
        assessment.blockers,
        isNot(contains(
          ClinicalLongFormPreCutoverRequirement
              .explicitRemoteAudioConsentUiCertified,
        )),
      );
    },
  );

  test('all green evidence can be eligible but never self-activates', () {
    const gate = ClinicalLongFormPreCutoverGate();

    const evidence = ClinicalLongFormPreCutoverEvidence(
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

    expect(gate.evaluate(evidence).eligible, isTrue);
    expect(
      ClinicalLongFormPreCutoverGate.productionCutoverEnabled,
      isFalse,
    );
    expect(
      ClinicalLongFormPreCutoverGate.atRestPlatformEnforcementMayBeAssumed,
      isFalse,
    );
  });
}
