import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:medcases/services/audio/clinical_long_form_backend_auth_contract.dart';
import 'package:medcases/services/audio/clinical_long_form_batch_transcription_provider.dart';
import 'package:medcases/services/audio/clinical_long_form_remote_audio_consent_store.dart';
import 'package:medcases/services/audio/clinical_long_form_remote_synthetic_callsite.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _SyntheticSessionTokenProvider
    implements ClinicalLongFormBackendSessionAccessTokenProvider {
  const _SyntheticSessionTokenProvider();

  @override
  Future<String> acquireSessionAccessToken() async =>
      'synthetic_firebase_session_token_not_for_network';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('callsite refuses construction without explicit remote consent',
      () async {
    final client = http.Client();
    addTearDown(client.close);

    await expectLater(
      () => ClinicalLongFormRemoteSyntheticCallsite.create(
        backendBaseUri: Uri.parse('https://medcasespro.com/'),
        client: client,
        sessionAccessTokenProvider: const _SyntheticSessionTokenProvider(),
        trustedAttestationPublicKeysById: <String, List<int>>{
          'synthetic-key': List<int>.filled(32, 1),
        },
        medicalKeywords: const <String>['ceftriaxona'],
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'remote_audio_consent_required',
        ),
      ),
    );
  });

  test('certified components assemble after purpose-specific consent',
      () async {
    const store = ClinicalLongFormRemoteAudioConsentStore();
    await store.accept(
      language: 'pt',
      acceptedAtUtc: DateTime.utc(2026, 8, 21, 1),
    );

    final client = http.Client();
    addTearDown(client.close);

    final callsite = await ClinicalLongFormRemoteSyntheticCallsite.create(
      backendBaseUri: Uri.parse('https://medcasespro.com/'),
      client: client,
      sessionAccessTokenProvider: const _SyntheticSessionTokenProvider(),
      trustedAttestationPublicKeysById: <String, List<int>>{
        'synthetic-key': List<int>.filled(32, 7),
      },
      medicalKeywords: const <String>[
        'ceftriaxona',
        'creatinina',
      ],
    );

    expect(callsite, isNotNull);
    expect(
      ClinicalLongFormRemoteSyntheticCallsite.syntheticWiringCertified,
      isTrue,
    );
    expect(
      ClinicalLongFormRemoteSyntheticCallsite.productionCallsiteWired,
      isFalse,
    );
    expect(
      ClinicalLongFormRemoteSyntheticCallsite.productionRemoteAudioEnabled,
      isFalse,
    );
    expect(
      ClinicalLongFormRemoteSyntheticCallsite.realPatientAudioEnabled,
      isFalse,
    );
    expect(
      ClinicalLongFormRemoteSyntheticCallsite.productionCutoverEnabled,
      isFalse,
    );
  });

  test('hard guard rejects non-synthetic session before network', () async {
    const store = ClinicalLongFormRemoteAudioConsentStore();
    await store.accept(language: 'pt');

    final client = http.Client();
    addTearDown(client.close);

    final callsite = await ClinicalLongFormRemoteSyntheticCallsite.create(
      backendBaseUri: Uri.parse('https://medcasespro.com/'),
      client: client,
      sessionAccessTokenProvider: const _SyntheticSessionTokenProvider(),
      trustedAttestationPublicKeysById: <String, List<int>>{
        'synthetic-key': List<int>.filled(32, 9),
      },
      medicalKeywords: const <String>['ceftriaxona'],
    );

    const request = ClinicalLongFormBatchTranscriptionRequest(
      sessionId: 'patient_or_unknown_001',
      locale: 'pt-BR',
      segmentIndex: 0,
      segmentPath: '/tmp/never_read.m4a',
      deduplicationKey: 'patient_or_unknown_001:segment:0',
    );

    expect(
      () => callsite.transcribeSyntheticSegment(
        request,
        syntheticAudioConfirmed: true,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'real_or_unclassified_audio_forbidden',
        ),
      ),
    );
  });

  test('explicit synthetic confirmation is mandatory', () async {
    const store = ClinicalLongFormRemoteAudioConsentStore();
    await store.accept(language: 'es');

    final client = http.Client();
    addTearDown(client.close);

    final callsite = await ClinicalLongFormRemoteSyntheticCallsite.create(
      backendBaseUri: Uri.parse('https://medcasespro.com/'),
      client: client,
      sessionAccessTokenProvider: const _SyntheticSessionTokenProvider(),
      trustedAttestationPublicKeysById: <String, List<int>>{
        'synthetic-key': List<int>.filled(32, 11),
      },
      medicalKeywords: const <String>['creatinina'],
    );

    const request = ClinicalLongFormBatchTranscriptionRequest(
      sessionId: 'synthetic_wiring_001',
      locale: 'es-AR',
      segmentIndex: 0,
      segmentPath: '/tmp/never_read.m4a',
      deduplicationKey: 'synthetic_wiring_001:segment:0',
    );

    expect(
      () => callsite.transcribeSyntheticSegment(
        request,
        syntheticAudioConfirmed: false,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'synthetic_audio_confirmation_required',
        ),
      ),
    );
  });

  test('production UI and recorder owners remain unwired', () {
    final main = File('lib/main.dart').readAsStringSync();
    final recorder =
        File('lib/services/clinical_recorder_service.dart').readAsStringSync();
    final sheet =
        File('lib/screens/clinical_recorder_sheet.dart').readAsStringSync();
    final history = File('lib/screens/history_screen.dart').readAsStringSync();

    for (final source in <String>[
      main,
      recorder,
      sheet,
      history,
    ]) {
      expect(
        source,
        isNot(contains('ClinicalLongFormRemoteSyntheticCallsite')),
      );
    }
  });

  test('source contains real MedCases backend component assembly only', () {
    final source = File(
      'lib/services/audio/'
      'clinical_long_form_remote_synthetic_callsite.dart',
    ).readAsStringSync();

    for (final required in <String>[
      'ClinicalLongFormHttpsBackendGrantProvider',
      'ClinicalLongFormHttpsBackendProxyTransport',
      'ClinicalLongFormEd25519NoRetentionAttestationVerifier',
      'ClinicalLongFormBackendProxyGatewaySandbox',
      'ClinicalLongFormRemoteBatchSandboxProvider',
      '/api/ai/audio/grant',
      '/api/ai/audio/transcriptions',
      'activeConsentOrNull',
      "requiredSyntheticSessionPrefix = 'synthetic_'",
      'realPatientAudioEnabled = false',
      'productionCutoverEnabled = false',
    ]) {
      expect(source, contains(required), reason: required);
    }

    for (final forbidden in <String>[
      'OPENAI_API_KEY',
      'api.openai.com',
      'productionCallsiteWired = true',
      'productionRemoteAudioEnabled = true',
      'realPatientAudioEnabled = true',
      'productionCutoverEnabled = true',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}
