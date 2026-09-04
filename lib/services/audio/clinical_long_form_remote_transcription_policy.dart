final class ClinicalLongFormRemoteAudioConsent {
  const ClinicalLongFormRemoteAudioConsent({
    required this.disclosureVersion,
    required this.acceptedAtUtc,
    required this.remoteTranscriptionAccepted,
    this.revokedAtUtc,
  });

  final String disclosureVersion;
  final DateTime acceptedAtUtc;
  final bool remoteTranscriptionAccepted;
  final DateTime? revokedAtUtc;

  bool get isActive => remoteTranscriptionAccepted && revokedAtUtc == null;

  void validate() {
    if (disclosureVersion.trim().isEmpty || disclosureVersion.length > 80) {
      throw ArgumentError.value(
        disclosureVersion,
        'disclosureVersion',
      );
    }

    if (!remoteTranscriptionAccepted) {
      throw StateError(
        'Remote audio transcription requires explicit user consent.',
      );
    }

    if (revokedAtUtc != null) {
      throw StateError(
        'Remote audio transcription consent has been revoked.',
      );
    }
  }
}

final class ClinicalLongFormRemoteTranscriptionPolicy {
  const ClinicalLongFormRemoteTranscriptionPolicy._();

  static const String fileTranscriptionModel = 'gpt-transcribe';
  static const String transcriptionEndpoint = '/v1/audio/transcriptions';

  /// Current documented Audio Transcriptions file limit.
  static const int maxFileBytes = 25 * 1024 * 1024;

  static const String requiredMediaExtension = '.m4a';

  /// Endpoint-specific retention evidence was verified against OpenAI's
  /// public "Data controls in the OpenAI platform" documentation on
  /// 2026-08-20. This is NOT an assertion that the MedCases organization
  /// has Zero Data Retention or Modified Abuse Monitoring provisioned.
  static const String endpointRetentionEvidenceSource =
      'https://developers.openai.com/api/docs/guides/your-data';
  static const String endpointRetentionEvidenceVerifiedAtUtc =
      '2026-08-20T18:10:00Z';

  static const bool audioTranscriptionsEndpointRetentionProfileVerified = true;
  static const bool audioTranscriptionsAbuseMonitoringRetentionExpected = false;
  static const bool audioTranscriptionsApplicationStateRetentionExpected =
      false;
  static const bool audioTranscriptionsZeroDataRetentionEligible = true;

  static const bool organizationZeroDataRetentionProvisioned = false;
  static const bool organizationModifiedAbuseMonitoringProvisioned = false;

  /// Keep these false: endpoint-specific retention evidence must never be
  /// misrepresented as organization-level ZDR.
  static const bool thirdPartyZeroDataRetentionVerified = false;
  static const bool thirdPartyRetentionMayBeAssumedZero = false;

  /// Product-engineering decision:
  /// normal API transcription may continue for synthetic/non-sensitive
  /// certification without organization-level ZDR. Real clinical audio stays
  /// blocked until purpose-specific consent UI and physical validation close.
  static const bool endpointSpecificRetentionEvidenceAcceptedForEngineering =
      true;
  static const bool normalApiSyntheticAudioCertificationAllowed = true;
  static const bool realPatientAudioAllowed = false;

  static const bool currentProductionDisclosureCompatible = false;
  static const bool remoteAudioTransmissionEnabledInProduction = false;

  static const bool explicitPurposeSpecificConsentRequired = true;
  static const bool consentRevocationRequired = true;
  static const bool consentDefaultEnabled = false;

  static const bool transientEncryptedTransmissionRequired = true;
  static const bool medCasesBackendDurableAudioPersistenceAllowed = false;
  static const bool cloudAudioPersistenceAllowed = false;

  static const bool appStorePrivacyMetadataReviewed = false;
  static const bool directOpenAiCredentialInFlutterAllowed = false;

  static void validateSegment({
    required String segmentPath,
    required int fileBytes,
  }) {
    if (!segmentPath.toLowerCase().endsWith(requiredMediaExtension)) {
      throw StateError(
        'Remote batch sandbox accepts only M4A long-form segments.',
      );
    }

    if (fileBytes < 1) {
      throw StateError('Audio segment is empty.');
    }

    if (fileBytes > maxFileBytes) {
      throw StateError(
        'Audio segment exceeds file-transcription size limit.',
      );
    }
  }

  static String iso639LanguageFromLocale(String locale) {
    final normalized = locale.trim().toLowerCase();
    if (normalized.startsWith('pt')) {
      return 'pt';
    }
    if (normalized.startsWith('es')) {
      return 'es';
    }
    throw ArgumentError.value(
      locale,
      'locale',
      'Remote sandbox currently allows PT/ES only.',
    );
  }
}
