import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_long_form_backend_auth_contract.dart';
import 'package:medcases/services/audio/clinical_long_form_backend_no_retention_attestation.dart';
import 'package:medcases/services/audio/clinical_long_form_backend_proxy_gateway_sandbox.dart';
import 'package:medcases/services/audio/clinical_long_form_backend_proxy_server_contract.dart';
import 'package:medcases/services/audio/openai_file_transcription_shadow_protocol.dart';

final class _FakeVerifier
    implements ClinicalLongFormBackendNoRetentionAttestationVerifier {
  _FakeVerifier({
    this.valid = true,
  });

  final bool valid;
  int calls = 0;

  @override
  Future<bool> verify(
    ClinicalLongFormBackendNoRetentionAttestation attestation,
  ) async {
    calls++;
    return valid;
  }
}

final class _FakeTransport implements ClinicalLongFormBackendProxyTransport {
  _FakeTransport({
    this.idempotencyOverride,
  });

  final String? idempotencyOverride;

  int calls = 0;
  ClinicalLongFormBackendProxyRequest? lastRequest;

  @override
  Future<ClinicalLongFormBackendProxyResponse> transcribe({
    required ClinicalLongFormBackendProxyRequest request,
    required ClinicalLongFormBackendTranscriptionGrant grant,
  }) async {
    calls++;
    lastRequest = request;

    final key = idempotencyOverride ?? request.idempotencyKey;
    final received = DateTime.utc(2026, 8, 19, 12);
    final completed = received.add(const Duration(seconds: 4));
    final deleted = completed.add(const Duration(seconds: 1));

    return ClinicalLongFormBackendProxyResponse(
      idempotencyKey: key,
      transcript: 'Ceftriaxona 2 g intravenosa.',
      resultRef: 'backend://result-001',
      noRetentionAttestation: ClinicalLongFormBackendNoRetentionAttestation(
        schemaVersion:
            ClinicalLongFormBackendNoRetentionAttestation.currentSchema,
        idempotencyKey: key,
        requestReceivedAtUtc: received,
        upstreamCompletedAtUtc: completed,
        temporaryAudioDeletedAtUtc: deleted,
        temporaryAudioDeleted: true,
        persistedAudioBytes: 0,
        sensitivePayloadLogged: false,
        attestationToken: 'signed_server_attestation_token_1234567890',
      ),
    );
  }
}

ClinicalLongFormBackendTranscriptionGrant _grant() {
  final now = DateTime.now().toUtc();

  return ClinicalLongFormBackendTranscriptionGrant(
    sessionId: 'proxy_sandbox_001',
    scope: ClinicalLongFormBackendTranscriptionGrant.requiredScope,
    accessToken: 'medcases_ephemeral_grant_1234567890',
    issuedAtUtc: now.subtract(const Duration(minutes: 1)),
    expiresAtUtc: now.add(const Duration(minutes: 10)),
  );
}

OpenAiFileTranscriptionShadowRequest _request() {
  return OpenAiFileTranscriptionShadowRequest(
    segmentPath: '/local/audio/segment_00000.m4a',
    fileBytes: 2400000,
    deduplicationKey: 'proxy_sandbox_001:segment:0',
    language: 'pt',
    prompt: 'Transcrição médica. Preservar doses, números e unidades.',
    keywords: const <String>[
      'ceftriaxona',
      'insuficiência cardíaca',
    ],
  );
}

void main() {
  test('server contract requires idempotency and no-retention attestation', () {
    expect(
      ClinicalLongFormBackendProxyServerPolicy.idempotencyRequired,
      isTrue,
    );
    expect(
      ClinicalLongFormBackendProxyServerPolicy.noRetentionAttestationRequired,
      isTrue,
    );
    expect(
      ClinicalLongFormBackendProxyServerPolicy
          .rawAudioDurablePersistenceAllowed,
      isFalse,
    );
    expect(
      ClinicalLongFormBackendProxyServerPolicy.sensitivePayloadLoggingAllowed,
      isFalse,
    );
  });

  test('happy path accepts same idempotency and verified zero-retention proof',
      () async {
    final transport = _FakeTransport();
    final verifier = _FakeVerifier();
    final gateway = ClinicalLongFormBackendProxyGatewaySandbox(
      transport: transport,
      attestationVerifier: verifier,
    );

    final response = await gateway.transcribe(
      request: _request(),
      grant: _grant(),
    );

    expect(response.transcript, 'Ceftriaxona 2 g intravenosa.');
    expect(response.resultRef, 'backend://result-001');
    expect(transport.calls, 1);
    expect(verifier.calls, 1);

    final proxy = transport.lastRequest!;
    expect(proxy.sessionId, 'proxy_sandbox_001');
    expect(proxy.segmentPath, endsWith('.m4a'));
    expect(proxy.contentLengthBytes, 2400000);
    expect(proxy.contentType, 'audio/mp4');
    expect(proxy.model, 'gpt-transcribe');
    expect(proxy.language, 'pt');
    expect(
      proxy.idempotencyKey,
      'proxy_sandbox_001:segment:0',
    );
    expect(proxy.timeout, const Duration(minutes: 2));
  });

  test('idempotency mismatch is rejected as non-retryable', () async {
    final gateway = ClinicalLongFormBackendProxyGatewaySandbox(
      transport: _FakeTransport(
        idempotencyOverride: 'different:segment:0',
      ),
      attestationVerifier: _FakeVerifier(),
    );

    await expectLater(
      () => gateway.transcribe(
        request: _request(),
        grant: _grant(),
      ),
      throwsA(
        isA<MedCasesLongFormBackendException>().having(
          (error) => error.retryable,
          'retryable',
          isFalse,
        ),
      ),
    );
  });

  test('unverified no-retention attestation rejects transcript', () async {
    final gateway = ClinicalLongFormBackendProxyGatewaySandbox(
      transport: _FakeTransport(),
      attestationVerifier: _FakeVerifier(valid: false),
    );

    await expectLater(
      () => gateway.transcribe(
        request: _request(),
        grant: _grant(),
      ),
      throwsA(
        isA<MedCasesLongFormBackendException>().having(
          (error) => error.retryable,
          'retryable',
          isFalse,
        ),
      ),
    );
  });

  test('attestation model itself rejects persisted backend audio bytes', () {
    final received = DateTime.utc(2026, 8, 19, 12);
    final completed = received.add(const Duration(seconds: 2));
    final deleted = completed.add(const Duration(seconds: 1));

    expect(
      () => ClinicalLongFormBackendNoRetentionAttestation(
        schemaVersion:
            ClinicalLongFormBackendNoRetentionAttestation.currentSchema,
        idempotencyKey: 'proxy_sandbox_001:segment:0',
        requestReceivedAtUtc: received,
        upstreamCompletedAtUtc: completed,
        temporaryAudioDeletedAtUtc: deleted,
        temporaryAudioDeleted: true,
        persistedAudioBytes: 1,
        sensitivePayloadLogged: false,
        attestationToken: 'signed_server_attestation_token_1234567890',
      ),
      throwsStateError,
    );
  });

  test('attestation model rejects sensitive payload logging', () {
    final received = DateTime.utc(2026, 8, 19, 12);
    final completed = received.add(const Duration(seconds: 2));
    final deleted = completed.add(const Duration(seconds: 1));

    expect(
      () => ClinicalLongFormBackendNoRetentionAttestation(
        schemaVersion:
            ClinicalLongFormBackendNoRetentionAttestation.currentSchema,
        idempotencyKey: 'proxy_sandbox_001:segment:0',
        requestReceivedAtUtc: received,
        upstreamCompletedAtUtc: completed,
        temporaryAudioDeletedAtUtc: deleted,
        temporaryAudioDeleted: true,
        persistedAudioBytes: 0,
        sensitivePayloadLogged: true,
        attestationToken: 'signed_server_attestation_token_1234567890',
      ),
      throwsStateError,
    );
  });

  test('attestation redacts proof token from diagnostics', () {
    final received = DateTime.utc(2026, 8, 19, 12);
    final completed = received.add(const Duration(seconds: 2));
    final deleted = completed.add(const Duration(seconds: 1));

    final attestation = ClinicalLongFormBackendNoRetentionAttestation(
      schemaVersion:
          ClinicalLongFormBackendNoRetentionAttestation.currentSchema,
      idempotencyKey: 'proxy_sandbox_001:segment:0',
      requestReceivedAtUtc: received,
      upstreamCompletedAtUtc: completed,
      temporaryAudioDeletedAtUtc: deleted,
      temporaryAudioDeleted: true,
      persistedAudioBytes: 0,
      sensitivePayloadLogged: false,
      attestationToken: 'signed_server_attestation_token_1234567890',
    );

    expect(
      attestation.redactedDescription,
      contains('[REDACTED]'),
    );
    expect(
      attestation.redactedDescription,
      isNot(contains('signed_server_attestation_token_1234567890')),
    );
  });

  test('server/gateway sandbox contains no HTTP or actual audio upload', () {
    final source = <String>[
      File(
        'lib/services/audio/'
        'clinical_long_form_backend_no_retention_attestation.dart',
      ).readAsStringSync(),
      File(
        'lib/services/audio/'
        'clinical_long_form_backend_proxy_server_contract.dart',
      ).readAsStringSync(),
      File(
        'lib/services/audio/'
        'clinical_long_form_backend_proxy_gateway_sandbox.dart',
      ).readAsStringSync(),
    ].join('\n');

    for (final forbidden in <String>[
      'package:http',
      'dart:io',
      'WebSocket',
      'HttpClient',
      'api.openai.com',
      'OPENAI_API_KEY',
      'Authorization:',
      'Firebase',
      'readAsBytes',
      'writeAsBytes',
      'MultipartRequest',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }

    expect(
      source,
      contains('actualHttpTransportImplemented = false'),
    );
    expect(
      source,
      contains('actualAudioUploadImplemented = false'),
    );
    expect(
      source,
      contains('responseAcceptedWithoutRetentionProof = false'),
    );
    expect(
      source,
      contains('productionCutoverEnabled = false'),
    );

    final main = File('lib/main.dart').readAsStringSync();
    final recorder =
        File('lib/services/clinical_recorder_service.dart').readAsStringSync();
    final history = File('lib/screens/history_screen.dart').readAsStringSync();

    expect(
      main,
      isNot(contains('ClinicalLongFormBackendProxyGatewaySandbox')),
    );
    expect(
      recorder,
      isNot(contains('ClinicalLongFormBackendProxyGatewaySandbox')),
    );
    expect(
      history,
      isNot(contains('ClinicalLongFormBackendProxyGatewaySandbox')),
    );
  });
}
