import 'package:shared_preferences/shared_preferences.dart';

import 'clinical_long_form_remote_transcription_policy.dart';

final class ClinicalLongFormRemoteAudioConsentStore {
  const ClinicalLongFormRemoteAudioConsentStore();

  static const String disclosureVersion = 'remote_audio_v1_2026_08_20';

  static const bool defaultConsentEnabled = false;
  static const bool purposeSpecificConsent = true;
  static const bool consentRevocable = true;
  static const bool productionCallsiteWired = false;
  static const bool productionRemoteAudioEnabled = false;

  static const String _acceptedKey = 'remote_audio_consent_v1_accepted';
  static const String _acceptedAtKey = 'remote_audio_consent_v1_accepted_at';
  static const String _disclosureVersionKey =
      'remote_audio_consent_v1_disclosure_version';
  static const String _languageKey = 'remote_audio_consent_v1_language';
  static const String _revokedAtKey = 'remote_audio_consent_v1_revoked_at';

  Future<bool> hasActiveConsent() async {
    final preferences = await SharedPreferences.getInstance();

    final accepted = preferences.getBool(_acceptedKey) ?? false;
    final version = preferences.getString(_disclosureVersionKey);
    final acceptedAt = preferences.getString(_acceptedAtKey);
    final revokedAt = preferences.getString(_revokedAtKey);

    return accepted &&
        version == disclosureVersion &&
        acceptedAt != null &&
        acceptedAt.isNotEmpty &&
        (revokedAt == null || revokedAt.isEmpty);
  }

  Future<void> accept({
    required String language,
    DateTime? acceptedAtUtc,
  }) async {
    final normalized = language.trim().toLowerCase();
    if (normalized != 'pt' && normalized != 'es') {
      throw ArgumentError.value(
        language,
        'language',
        'Remote audio consent currently supports PT/ES only.',
      );
    }

    final preferences = await SharedPreferences.getInstance();
    final timestamp =
        (acceptedAtUtc ?? DateTime.now().toUtc()).toIso8601String();

    await Future.wait(<Future<bool>>[
      preferences.setBool(_acceptedKey, true),
      preferences.setString(_acceptedAtKey, timestamp),
      preferences.setString(
        _disclosureVersionKey,
        disclosureVersion,
      ),
      preferences.setString(_languageKey, normalized),
      preferences.remove(_revokedAtKey),
    ]);
  }

  Future<void> revoke({DateTime? revokedAtUtc}) async {
    final preferences = await SharedPreferences.getInstance();
    final timestamp =
        (revokedAtUtc ?? DateTime.now().toUtc()).toIso8601String();

    await Future.wait(<Future<bool>>[
      preferences.setBool(_acceptedKey, false),
      preferences.setString(_revokedAtKey, timestamp),
    ]);
  }

  Future<ClinicalLongFormRemoteAudioConsent?> activeConsentOrNull() async {
    if (!await hasActiveConsent()) {
      return null;
    }

    final preferences = await SharedPreferences.getInstance();
    final acceptedAtRaw = preferences.getString(_acceptedAtKey);
    if (acceptedAtRaw == null) {
      return null;
    }

    final acceptedAtUtc = DateTime.tryParse(acceptedAtRaw)?.toUtc();
    if (acceptedAtUtc == null) {
      return null;
    }

    final consent = ClinicalLongFormRemoteAudioConsent(
      disclosureVersion: disclosureVersion,
      acceptedAtUtc: acceptedAtUtc,
      remoteTranscriptionAccepted: true,
    );
    consent.validate();
    return consent;
  }

  Future<Map<String, String?>> auditInfo() async {
    final preferences = await SharedPreferences.getInstance();
    return <String, String?>{
      'accepted': (preferences.getBool(_acceptedKey) ?? false).toString(),
      'acceptedAt': preferences.getString(_acceptedAtKey),
      'disclosureVersion': preferences.getString(_disclosureVersionKey),
      'language': preferences.getString(_languageKey),
      'revokedAt': preferences.getString(_revokedAtKey),
    };
  }
}
