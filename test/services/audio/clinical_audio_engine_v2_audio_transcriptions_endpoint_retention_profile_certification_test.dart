import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_long_form_remote_transcription_policy.dart';

void main() {
  test('audio transcription endpoint retention profile is certified', () {
    expect(
      ClinicalLongFormRemoteTranscriptionPolicy
          .audioTranscriptionsEndpointRetentionProfileVerified,
      isTrue,
    );
    expect(
      ClinicalLongFormRemoteTranscriptionPolicy
          .audioTranscriptionsAbuseMonitoringRetentionExpected,
      isFalse,
    );
    expect(
      ClinicalLongFormRemoteTranscriptionPolicy
          .audioTranscriptionsApplicationStateRetentionExpected,
      isFalse,
    );
    expect(
      ClinicalLongFormRemoteTranscriptionPolicy
          .audioTranscriptionsZeroDataRetentionEligible,
      isTrue,
    );
    expect(
      ClinicalLongFormRemoteTranscriptionPolicy.transcriptionEndpoint,
      '/v1/audio/transcriptions',
    );
  });

  test('endpoint retention evidence is not misrepresented as org-level ZDR',
      () {
    expect(
      ClinicalLongFormRemoteTranscriptionPolicy
          .organizationZeroDataRetentionProvisioned,
      isFalse,
    );
    expect(
      ClinicalLongFormRemoteTranscriptionPolicy
          .organizationModifiedAbuseMonitoringProvisioned,
      isFalse,
    );
    expect(
      ClinicalLongFormRemoteTranscriptionPolicy
          .thirdPartyZeroDataRetentionVerified,
      isFalse,
    );
    expect(
      ClinicalLongFormRemoteTranscriptionPolicy
          .thirdPartyRetentionMayBeAssumedZero,
      isFalse,
    );
  });

  test(
      'normal API engineering may continue while real clinical audio stays blocked',
      () {
    expect(
      ClinicalLongFormRemoteTranscriptionPolicy
          .endpointSpecificRetentionEvidenceAcceptedForEngineering,
      isTrue,
    );
    expect(
      ClinicalLongFormRemoteTranscriptionPolicy
          .normalApiSyntheticAudioCertificationAllowed,
      isTrue,
    );
    expect(
      ClinicalLongFormRemoteTranscriptionPolicy.realPatientAudioAllowed,
      isFalse,
    );
    expect(
      ClinicalLongFormRemoteTranscriptionPolicy
          .remoteAudioTransmissionEnabledInProduction,
      isFalse,
    );
  });

  test(
      'privacy PT and ES describe endpoint-specific retention without claiming ZDR',
      () async {
    final source = await File('lib/screens/legal_screen.dart').readAsString();

    expect(source, contains('/v1/audio/transcriptions'));
    final normalizedSource = source.replaceAll(
      RegExp(r"'\s*'"),
      '',
    );

    expect(
      normalizedSource,
      contains(
        'Essa verificação é específica do endpoint e não significa que a organização do MedCases Pro esteja provisionada com Zero Data Retention.',
      ),
    );
    expect(
      normalizedSource,
      contains(
        'Esta verificación es específica del endpoint y no significa que la organización de MedCases Pro tenga provisionado Zero Data Retention.',
      ),
    );
  });

  test('production owners remain unwired to normal API audio cutover',
      () async {
    final owners = <String>[
      'lib/main.dart',
      'lib/screens/clinical_recorder_sheet.dart',
      'lib/screens/history_screen.dart',
      'lib/services/clinical_recorder_service.dart',
      'lib/services/audio/clinical_long_form_staging_to_backend_sandbox_adapter.dart',
    ];

    for (final path in owners) {
      final source = await File(path).readAsString();
      expect(
        source,
        isNot(contains('normalApiSyntheticAudioCertificationAllowed')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('realPatientAudioAllowed')),
        reason: path,
      );
    }
  });
}
