import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:medcases/services/audio/clinical_long_form_backend_auth_contract.dart';
import 'package:medcases/services/audio/clinical_long_form_batch_transcription_provider.dart';
import 'package:medcases/services/audio/clinical_long_form_backend_no_retention_attestation.dart';
import 'package:medcases/services/audio/clinical_long_form_backend_proxy_gateway_sandbox.dart';
import 'package:medcases/services/audio/clinical_long_form_ed25519_no_retention_attestation_verifier.dart';
import 'package:medcases/services/audio/clinical_long_form_https_backend_grant_provider.dart';
import 'package:medcases/services/audio/clinical_long_form_https_backend_proxy_transport.dart';
import 'package:medcases/services/audio/clinical_long_form_native_at_rest_platform_bridge.dart';
import 'package:medcases/services/audio/clinical_long_form_native_secure_persistence_adapters.dart';
import 'package:medcases/services/audio/clinical_long_form_no_retention_attestation_canonical_payload.dart';
import 'package:medcases/services/audio/clinical_long_form_remote_batch_sandbox_provider.dart';
import 'package:medcases/services/audio/clinical_long_form_remote_transcription_policy.dart';
import 'package:medcases/services/audio/clinical_long_form_secure_plaintext_staging_lifecycle.dart';
import 'package:medcases/services/audio/clinical_long_form_staging_to_backend_sandbox_adapter.dart';
import 'package:medcases/services/audio/file_clinical_long_form_local_audio_inspector.dart';

final class _SessionAccessTokenProvider
    implements ClinicalLongFormBackendSessionAccessTokenProvider {
  const _SessionAccessTokenProvider();

  @override
  Future<String> acquireSessionAccessToken() async =>
      'medcases_synthetic_app_session_token_1234567890';
}

final class _InMemoryHttpClient extends http.BaseClient {
  _InMemoryHttpClient({
    required this.statusCode,
    required this.responseBody,
  });

  final int statusCode;
  final String responseBody;

  int calls = 0;
  http.BaseRequest? lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    lastRequest = request;

    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(responseBody)),
      statusCode,
      headers: const <String, String>{
        'content-type': 'application/json',
      },
    );
  }
}

String _grantResponse({
  required String sessionId,
  required String deduplicationKey,
  required DateTime nowUtc,
}) {
  return jsonEncode(<String, Object?>{
    'sessionId': sessionId,
    'deduplicationKey': deduplicationKey,
    'scope': ClinicalLongFormBackendTranscriptionGrant.requiredScope,
    'accessToken': 'medcases_synthetic_backend_grant_abcdef1234567890',
    'issuedAtUtc':
        nowUtc.subtract(const Duration(minutes: 1)).toIso8601String(),
    'expiresAtUtc': nowUtc.add(const Duration(minutes: 10)).toIso8601String(),
  });
}

ClinicalLongFormBackendNoRetentionAttestation _attestation({
  required String idempotencyKey,
  required String token,
  required DateTime nowUtc,
}) {
  final received = nowUtc;
  final completed = received.add(const Duration(seconds: 2));
  final deleted = completed.add(const Duration(seconds: 1));

  return ClinicalLongFormBackendNoRetentionAttestation(
    schemaVersion: ClinicalLongFormBackendNoRetentionAttestation.currentSchema,
    idempotencyKey: idempotencyKey,
    requestReceivedAtUtc: received,
    upstreamCompletedAtUtc: completed,
    temporaryAudioDeletedAtUtc: deleted,
    temporaryAudioDeleted: true,
    persistedAudioBytes: 0,
    sensitivePayloadLogged: false,
    attestationToken: token,
  );
}

Future<String> _signedTransportResponse({
  required String idempotencyKey,
  required String keyId,
  required KeyPair keyPair,
  required DateTime nowUtc,
  bool tamperSignature = false,
}) async {
  final draft = _attestation(
    idempotencyKey: idempotencyKey,
    token: 'placeholder_attestation_token_1234567890',
    nowUtc: nowUtc,
  );

  final payload = ClinicalLongFormNoRetentionAttestationCanonicalPayload.encode(
    attestation: draft,
    keyId: keyId,
  );

  final signature = await Ed25519().sign(
    payload,
    keyPair: keyPair,
  );

  var encoded = base64Url.encode(signature.bytes).replaceAll('=', '');

  if (tamperSignature) {
    final replacement = encoded.endsWith('A') ? 'B' : 'A';
    encoded = '${encoded.substring(0, encoded.length - 1)}$replacement';
  }

  final token = 'ed25519.$keyId.$encoded';
  final signed = _attestation(
    idempotencyKey: idempotencyKey,
    token: token,
    nowUtc: nowUtc,
  );

  return jsonEncode(<String, Object?>{
    'idempotencyKey': idempotencyKey,
    'transcript': 'Ceftriaxona 2 g intravenosa.',
    'resultRef': 'backend://synthetic-real-chain/result-001',
    'noRetentionAttestation': <String, Object?>{
      'schemaVersion': signed.schemaVersion,
      'idempotencyKey': signed.idempotencyKey,
      'requestReceivedAtUtc': signed.requestReceivedAtUtc.toIso8601String(),
      'upstreamCompletedAtUtc': signed.upstreamCompletedAtUtc.toIso8601String(),
      'temporaryAudioDeletedAtUtc':
          signed.temporaryAudioDeletedAtUtc.toIso8601String(),
      'temporaryAudioDeleted': signed.temporaryAudioDeleted,
      'persistedAudioBytes': signed.persistedAudioBytes,
      'sensitivePayloadLogged': signed.sensitivePayloadLogged,
      'attestationToken': signed.attestationToken,
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    ClinicalLongFormNativeAtRestPlatformBridge.channelName,
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, Object?>() ??
          <String, Object?>{};

      switch (call.method) {
        case 'protectDurableFile':
          return null;
        case 'openFile':
          final source = File(args['sourcePath']! as String);
          final destination = File(args['destinationPath']! as String);
          final sealed = await source.readAsBytes();
          final clear = sealed.map((value) => value ^ 0xA5).toList();
          await destination.writeAsBytes(clear, flush: true);
          return <String, Object?>{
            'path': destination.path,
            'byteCount': clear.length,
          };
      }

      throw PlatformException(code: 'unexpected_mock_method');
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<
      ({
        Directory root,
        File sealed,
        List<int> clearBytes,
        _InMemoryHttpClient grantClient,
        _InMemoryHttpClient transportClient,
        ClinicalLongFormStagingToBackendSandboxAdapter adapter,
      })> fixture({
    bool tamperAttestation = false,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    const sessionId = 'real_backend_synthetic_001';
    const dedupe = 'real_backend_synthetic_001:segment:0';
    const keyId = 'synthetic-cert-2026-01';

    final root = await Directory.systemTemp.createTemp(
      'medcases_real_backend_synthetic_chain_',
    );

    final audioDirectory = Directory(
      '${root.path}${Platform.pathSeparator}'
      '$sessionId${Platform.pathSeparator}audio',
    );
    await audioDirectory.create(recursive: true);

    final sealed = File(
      '${audioDirectory.path}${Platform.pathSeparator}'
      'segment_00000.m4a.sealed',
    );

    final clearBytes = List<int>.generate(
      8192,
      (index) => (index * 13) % 251,
    );
    await sealed.writeAsBytes(
      clearBytes.map((value) => value ^ 0xA5).toList(),
      flush: true,
    );

    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();

    final grantClient = _InMemoryHttpClient(
      statusCode: 200,
      responseBody: _grantResponse(
        sessionId: sessionId,
        deduplicationKey: dedupe,
        nowUtc: nowUtc,
      ),
    );

    final transportClient = _InMemoryHttpClient(
      statusCode: 200,
      responseBody: await _signedTransportResponse(
        idempotencyKey: dedupe,
        keyId: keyId,
        keyPair: keyPair,
        nowUtc: nowUtc,
        tamperSignature: tamperAttestation,
      ),
    );

    final grantProvider = ClinicalLongFormHttpsBackendGrantProvider(
      endpoint: Uri.parse(
        'https://sandbox.medcases.invalid/v1/audio/grant',
      ),
      client: grantClient,
      sessionAccessTokenProvider: const _SessionAccessTokenProvider(),
      nowUtc: () => nowUtc,
    );

    final transport = ClinicalLongFormHttpsBackendProxyTransport(
      endpoint: Uri.parse(
        'https://sandbox.medcases.invalid/v1/audio/transcriptions',
      ),
      client: transportClient,
    );

    final verifier = ClinicalLongFormEd25519NoRetentionAttestationVerifier(
      trustedPublicKeysById: <String, List<int>>{
        keyId: publicKey.bytes,
      },
    );

    final gateway = ClinicalLongFormBackendProxyGatewaySandbox(
      transport: transport,
      attestationVerifier: verifier,
    );

    final remoteProvider = ClinicalLongFormRemoteBatchSandboxProvider(
      consent: ClinicalLongFormRemoteAudioConsent(
        disclosureVersion: 'synthetic_certification_only_v1',
        acceptedAtUtc: nowUtc,
        remoteTranscriptionAccepted: true,
      ),
      grantProvider: grantProvider,
      gateway: gateway,
      audioInspector: const FileClinicalLongFormLocalAudioInspector(),
      medicalKeywords: const <String>[
        'ceftriaxona',
        'insuficiência cardíaca',
      ],
      nowUtc: () => nowUtc,
    );

    final bridge = ClinicalLongFormNativeAtRestPlatformBridge(
      channel: channel,
    );
    final closedAudioAdapter = NativeSecureClinicalLongFormClosedAudioAdapter(
      bridge: bridge,
      keyId: 'device-key-v1',
    );

    final stagingLifecycle = ClinicalLongFormSecurePlaintextStagingLifecycle(
      secureRootDirectory: root,
      closedAudioAdapter: closedAudioAdapter,
      nowUtc: () => nowUtc,
      nonceFactory: () => 'aabbccddeeff00112233445566778899',
    );

    final adapter = ClinicalLongFormStagingToBackendSandboxAdapter(
      stagingLifecycle: stagingLifecycle,
      remoteProvider: remoteProvider,
    );

    return (
      root: root,
      sealed: sealed,
      clearBytes: clearBytes,
      grantClient: grantClient,
      transportClient: transportClient,
      adapter: adapter,
    );
  }

  const request = ClinicalLongFormSealedBatchTranscriptionRequest(
    sessionId: 'real_backend_synthetic_001',
    locale: 'pt-BR',
    segmentIndex: 0,
    sealedSegmentPath: '',
    deduplicationKey: 'real_backend_synthetic_001:segment:0',
    previousContext: 'Paciente sintético com insuficiência cardíaca.',
  );

  test(
    'full synthetic chain uses real grant transport gateway and Ed25519 verifier',
    () async {
      final f = await fixture();

      try {
        final result = await f.adapter.transcribeSealedSegment(
          ClinicalLongFormSealedBatchTranscriptionRequest(
            sessionId: request.sessionId,
            locale: request.locale,
            segmentIndex: request.segmentIndex,
            sealedSegmentPath: f.sealed.path,
            deduplicationKey: request.deduplicationKey,
            previousContext: request.previousContext,
          ),
        );

        expect(result.transcript, 'Ceftriaxona 2 g intravenosa.');
        expect(
          result.resultRef,
          'backend://synthetic-real-chain/result-001',
        );

        expect(f.grantClient.calls, 1);
        expect(f.grantClient.lastRequest, isA<http.Request>());
        expect(
          f.grantClient.lastRequest!.url.host,
          'sandbox.medcases.invalid',
        );
        expect(
          f.grantClient.lastRequest!.headers['Authorization'],
          'Bearer medcases_synthetic_app_session_token_1234567890',
        );

        expect(f.transportClient.calls, 1);
        expect(
          f.transportClient.lastRequest,
          isA<http.MultipartRequest>(),
        );

        final multipart =
            f.transportClient.lastRequest! as http.MultipartRequest;

        expect(multipart.url.host, 'sandbox.medcases.invalid');
        expect(
          multipart.headers['X-MedCases-Audio-Retention'],
          'transient-delete',
        );
        expect(
          multipart.headers['Authorization'],
          'Bearer medcases_synthetic_backend_grant_abcdef1234567890',
        );
        expect(
          multipart.fields['model'],
          ClinicalLongFormRemoteTranscriptionPolicy.fileTranscriptionModel,
        );
        expect(multipart.fields['language'], 'pt');
        expect(multipart.files, hasLength(1));
        expect(
          multipart.files.single.filename,
          startsWith('staging_'),
        );
        expect(
          multipart.files.single.filename,
          endsWith('.m4a'),
        );

        final stagingRoot = Directory(
          '${f.root.path}${Platform.pathSeparator}'
          'transport_plaintext_staging',
        );
        expect(await stagingRoot.exists(), isFalse);
        expect(await f.sealed.exists(), isTrue);
      } finally {
        await f.adapter.dispose();
        await f.root.delete(recursive: true);
      }
    },
  );

  test(
    'invalid Ed25519 proof blocks result and still deletes plaintext staging',
    () async {
      final f = await fixture(tamperAttestation: true);

      try {
        await expectLater(
          () => f.adapter.transcribeSealedSegment(
            ClinicalLongFormSealedBatchTranscriptionRequest(
              sessionId: request.sessionId,
              locale: request.locale,
              segmentIndex: request.segmentIndex,
              sealedSegmentPath: f.sealed.path,
              deduplicationKey: request.deduplicationKey,
              previousContext: request.previousContext,
            ),
          ),
          throwsA(
            isA<ClinicalLongFormBatchTranscriptionException>(),
          ),
        );

        expect(f.grantClient.calls, 1);
        expect(f.transportClient.calls, 1);

        final stagingRoot = Directory(
          '${f.root.path}${Platform.pathSeparator}'
          'transport_plaintext_staging',
        );
        expect(await stagingRoot.exists(), isFalse);
        expect(await f.sealed.exists(), isTrue);
      } finally {
        await f.adapter.dispose();
        await f.root.delete(recursive: true);
      }
    },
  );

  test('certification uses only injected in-memory HTTP clients', () async {
    final source = await File(
      'test/services/audio/'
      'clinical_audio_engine_v2_real_backend_synthetic_full_chain_'
      'certification_test.dart',
    ).readAsString();

    expect(source, contains('extends http.BaseClient'));
    expect(source, contains('sandbox.medcases.invalid'));
    expect(source, isNot(contains('api.' 'openai.com')));
    expect(source, isNot(contains('http.' 'Client()')));
    expect(source, isNot(contains('IO' 'Client')));
    expect(source, contains('synthetic_certification_only_v1'));
    expect(source, contains('real_backend_synthetic_001'));
  });
}
