import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/screens/legal_screen.dart';
import 'package:medcases/services/audio/clinical_long_form_remote_audio_consent_store.dart';
import 'package:medcases/services/audio/clinical_long_form_remote_transcription_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('purpose-specific remote audio consent is default off', () async {
    const store = ClinicalLongFormRemoteAudioConsentStore();

    expect(
      ClinicalLongFormRemoteAudioConsentStore.defaultConsentEnabled,
      isFalse,
    );
    expect(
      ClinicalLongFormRemoteAudioConsentStore.purposeSpecificConsent,
      isTrue,
    );
    expect(
      ClinicalLongFormRemoteAudioConsentStore.consentRevocable,
      isTrue,
    );
    expect(
      ClinicalLongFormRemoteAudioConsentStore.productionCallsiteWired,
      isFalse,
    );
    expect(await store.hasActiveConsent(), isFalse);
    expect(await store.activeConsentOrNull(), isNull);
  });

  test('accept creates auditable validated PT consent', () async {
    const store = ClinicalLongFormRemoteAudioConsentStore();
    final acceptedAt = DateTime.utc(2026, 8, 20, 12);

    await store.accept(
      language: 'pt',
      acceptedAtUtc: acceptedAt,
    );

    expect(await store.hasActiveConsent(), isTrue);

    final consent = await store.activeConsentOrNull();
    expect(consent, isNotNull);
    expect(consent!.acceptedAtUtc, acceptedAt);
    expect(consent.isActive, isTrue);
    expect(
      consent.disclosureVersion,
      ClinicalLongFormRemoteAudioConsentStore.disclosureVersion,
    );

    final audit = await store.auditInfo();
    expect(audit['accepted'], 'true');
    expect(audit['language'], 'pt');
    expect(
      audit['disclosureVersion'],
      ClinicalLongFormRemoteAudioConsentStore.disclosureVersion,
    );
    expect(audit['revokedAt'], isNull);
  });

  test('revocation disables future remote consent immediately', () async {
    const store = ClinicalLongFormRemoteAudioConsentStore();

    await store.accept(
      language: 'es',
      acceptedAtUtc: DateTime.utc(2026, 8, 20, 12),
    );

    final revokedAt = DateTime.utc(2026, 8, 20, 13);
    await store.revoke(revokedAtUtc: revokedAt);

    expect(await store.hasActiveConsent(), isFalse);
    expect(await store.activeConsentOrNull(), isNull);

    final audit = await store.auditInfo();
    expect(audit['accepted'], 'false');
    expect(audit['revokedAt'], revokedAt.toIso8601String());
  });

  test('revoked consent object is rejected by provider contract', () {
    final consent = ClinicalLongFormRemoteAudioConsent(
      disclosureVersion:
          ClinicalLongFormRemoteAudioConsentStore.disclosureVersion,
      acceptedAtUtc: DateTime.utc(2026, 8, 20, 12),
      remoteTranscriptionAccepted: true,
      revokedAtUtc: DateTime.utc(2026, 8, 20, 13),
    );

    expect(consent.isActive, isFalse);
    expect(consent.validate, throwsStateError);
  });

  test('general legal consent was materially versioned forward', () async {
    final source = await File('lib/screens/legal_screen.dart').readAsString();

    expect(
      source,
      contains("const _kTermsVersion = 'v2.1-2026-remote-audio'"),
    );
    expect(
      RegExp(
        r"static const\s+_kConsentKey\s*=\s*'consent_v3';",
      ).hasMatch(source),
      isTrue,
    );

    expect(await ConsentGate.hasConsented(), isFalse);
  });

  test('privacy policy PT and ES disclose optional remote audio processing',
      () async {
    final source = await File('lib/screens/legal_screen.dart').readAsString();

    expect(source, contains('Transcrição remota de áudio'));
    expect(source, contains('Transcripción remota de audio'));
    expect(source, contains('provedor externo de IA/transcrição'));
    expect(source, contains('proveedor externo de IA/transcripción'));
    expect(source, contains('revogar o consentimento específico'));
    expect(source, contains('revocar el consentimiento específico'));
    final normalizedSource = source.replaceAll(
      RegExp(r"'\s*'"),
      '',
    );

    expect(
      normalizedSource,
      contains(
        'endpoint /v1/audio/transcriptions não mantém conteúdo do cliente em retenção de monitoramento de abuso nem em estado de aplicação.',
      ),
    );
    expect(
      normalizedSource,
      contains(
        '/v1/audio/transcriptions no conserva contenido del cliente en retención de monitoreo de abuso ni en estado de aplicación.',
      ),
    );
    expect(
      normalizedSource,
      contains(
        'não significa que a organização do MedCases Pro esteja provisionada com Zero Data Retention.',
      ),
    );
    expect(
      normalizedSource,
      contains(
        'no significa que la organización de MedCases Pro tenga provisionado Zero Data Retention.',
      ),
    );
  });

  test('iOS purpose strings no longer make absolute local-only claim',
      () async {
    final files = <String>[
      'ios/Runner/Info.plist',
      'ios/Runner/en.lproj/InfoPlist.strings',
      'ios/Runner/es.lproj/InfoPlist.strings',
      'ios/Runner/pt-BR.lproj/InfoPlist.strings',
    ];

    for (final path in files) {
      final source = await File(path).readAsString();

      expect(
        source,
        isNot(contains(
          'never stored, transmitted, or shared with external servers',
        )),
        reason: path,
      );
      expect(
        source,
        isNot(contains(
          'nunca se almacena, transmite ni comparte con servidores externos',
        )),
        reason: path,
      );
      expect(
        source,
        isNot(contains(
          'nunca é armazenado, transmitido ou compartilhado com servidores externos',
        )),
        reason: path,
      );
    }
  });

  test('remote policy stays production-blocked pending retention and UI gates',
      () {
    expect(
      ClinicalLongFormRemoteTranscriptionPolicy
          .currentProductionDisclosureCompatible,
      isFalse,
    );
    expect(
      ClinicalLongFormRemoteTranscriptionPolicy
          .remoteAudioTransmissionEnabledInProduction,
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
    expect(
      ClinicalLongFormRemoteTranscriptionPolicy.appStorePrivacyMetadataReviewed,
      isFalse,
    );
    expect(
      ClinicalLongFormRemoteTranscriptionPolicy
          .explicitPurposeSpecificConsentRequired,
      isTrue,
    );
    expect(
      ClinicalLongFormRemoteTranscriptionPolicy.consentRevocationRequired,
      isTrue,
    );
  });

  test('new purpose-specific store remains unwired from production owners',
      () async {
    final owners = <String>[
      'lib/main.dart',
      'lib/screens/pre_login_screen.dart',
      'lib/screens/clinical_recorder_sheet.dart',
      'lib/screens/history_screen.dart',
      'lib/services/clinical_recorder_service.dart',
      'lib/services/audio/clinical_long_form_remote_batch_sandbox_provider.dart',
      'lib/services/audio/clinical_long_form_staging_to_backend_sandbox_adapter.dart',
    ];

    for (final path in owners) {
      final source = await File(path).readAsString();
      expect(
        source,
        isNot(contains('ClinicalLongFormRemoteAudioConsentStore')),
        reason: path,
      );
      expect(
        source,
        isNot(contains(
          'clinical_long_form_remote_audio_consent_store.dart',
        )),
        reason: path,
      );
    }
  });
}
