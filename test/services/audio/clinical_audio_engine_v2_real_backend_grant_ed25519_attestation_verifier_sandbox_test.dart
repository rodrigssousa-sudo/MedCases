import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:medcases/services/audio/clinical_long_form_backend_auth_contract.dart';
import 'package:medcases/services/audio/clinical_long_form_backend_no_retention_attestation.dart';
import 'package:medcases/services/audio/clinical_long_form_batch_transcription_provider.dart';
import 'package:medcases/services/audio/clinical_long_form_ed25519_no_retention_attestation_verifier.dart';
import 'package:medcases/services/audio/clinical_long_form_https_backend_grant_provider.dart';
import 'package:medcases/services/audio/clinical_long_form_no_retention_attestation_canonical_payload.dart';
import 'package:medcases/services/audio/clinical_long_form_pre_cutover_gate.dart';
import 'package:medcases/services/audio/clinical_long_form_remote_batch_sandbox_provider.dart';
import 'package:medcases/services/audio/clinical_long_form_remote_transcription_policy.dart';
import 'package:medcases/services/audio/openai_file_transcription_shadow_protocol.dart';

final class _SessionTokenProvider
    implements ClinicalLongFormBackendSessionAccessTokenProvider {
  const _SessionTokenProvider();

  @override
  Future<String> acquireSessionAccessToken() async =>
      'medcases_app_session_token_1234567890';
}

final class _CapturingClient extends http.BaseClient {
  _CapturingClient({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
  int calls = 0;
  http.BaseRequest? lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    lastRequest = request;
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      statusCode,
      headers: const <String, String>{
        'content-type': 'application/json',
      },
    );
  }
}

final class _FailingGrantProvider
    implements ClinicalLongFormBackendGrantProvider {
  const _FailingGrantProvider();

  @override
  Future<ClinicalLongFormBackendTranscriptionGrant> acquireTranscriptionGrant({
    required String sessionId,
    required String deduplicationKey,
  }) {
    throw const ClinicalLongFormBackendGrantProviderException(
      'synthetic_grant_503',
    );
  }
}

final class _DescriptorInspector
    implements ClinicalLongFormLocalAudioInspector {
  const _DescriptorInspector();

  @override
  Future<ClinicalLongFormLocalAudioDescriptor> inspect(
    String segmentPath,
  ) async {
    return ClinicalLongFormLocalAudioDescriptor(
      path: segmentPath,
      fileBytes: 128,
    );
  }
}

final class _NeverGateway
    implements MedCasesLongFormBackendTranscriptionGateway {
  int calls = 0;

  @override
  Future<MedCasesLongFormBackendTranscriptionResponse> transcribe({
    required OpenAiFileTranscriptionShadowRequest request,
    required ClinicalLongFormBackendTranscriptionGrant grant,
  }) async {
    calls++;
    throw StateError('Gateway must not be reached.');
  }
}

String _grantResponse({
  String sessionId = 'grant_sandbox_001',
  String dedupe = 'grant_sandbox_001:segment:0',
}) {
  return jsonEncode(<String, Object?>{
    'sessionId': sessionId,
    'deduplicationKey': dedupe,
    'scope': ClinicalLongFormBackendTranscriptionGrant.requiredScope,
    'accessToken': 'medcases_backend_grant_abcdef1234567890',
    'issuedAtUtc': '2026-08-19T17:00:00.000Z',
    'expiresAtUtc': '2026-08-19T17:10:00.000Z',
  });
}

ClinicalLongFormBackendNoRetentionAttestation _attestation({
  required String token,
  String idempotencyKey = 'attestation_sandbox_001:segment:0',
}) {
  final received = DateTime.utc(2026, 8, 19, 17);
  final completed = received.add(const Duration(seconds: 4));
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

Future<ClinicalLongFormBackendNoRetentionAttestation> _signedAttestation({
  required String keyId,
  required KeyPair keyPair,
}) async {
  final draft = _attestation(
    token: 'placeholder_attestation_token_1234567890',
  );

  final payload = ClinicalLongFormNoRetentionAttestationCanonicalPayload.encode(
    attestation: draft,
    keyId: keyId,
  );

  final signature = await Ed25519().sign(
    payload,
    keyPair: keyPair,
  );

  final encoded = base64Url.encode(signature.bytes).replaceAll('=', '');

  return _attestation(
    token: 'ed25519.$keyId.$encoded',
  );
}

void main() {
  test('grant provider rejects non-HTTPS endpoint', () {
    expect(
      () => ClinicalLongFormHttpsBackendGrantProvider(
        endpoint: Uri.parse('http://sandbox.medcases.invalid/grant'),
        client: _CapturingClient(
          statusCode: 200,
          body: '{}',
        ),
        sessionAccessTokenProvider: const _SessionTokenProvider(),
      ),
      throwsArgumentError,
    );
  });

  test('grant provider sends scoped request and parses ephemeral grant',
      () async {
    final client = _CapturingClient(
      statusCode: 200,
      body: _grantResponse(),
    );

    final provider = ClinicalLongFormHttpsBackendGrantProvider(
      endpoint: Uri.parse(
        'https://sandbox.medcases.invalid/v1/audio/grant',
      ),
      client: client,
      sessionAccessTokenProvider: const _SessionTokenProvider(),
      nowUtc: () => DateTime.utc(2026, 8, 19, 17, 1),
    );

    final grant = await provider.acquireTranscriptionGrant(
      sessionId: 'grant_sandbox_001',
      deduplicationKey: 'grant_sandbox_001:segment:0',
    );

    expect(grant.sessionId, 'grant_sandbox_001');
    expect(
      grant.scope,
      ClinicalLongFormBackendTranscriptionGrant.requiredScope,
    );
    expect(
      grant.redactedDescription,
      isNot(contains('abcdef1234567890')),
    );

    expect(client.calls, 1);
    final request = client.lastRequest! as http.Request;
    expect(request.url.scheme, 'https');
    expect(
      request.headers['Authorization'],
      startsWith('Bearer medcases_app_session_token_'),
    );

    final decoded = jsonDecode(request.body) as Map<String, dynamic>;
    expect(decoded['sessionId'], 'grant_sandbox_001');
    expect(
      decoded['deduplicationKey'],
      'grant_sandbox_001:segment:0',
    );
    expect(
      decoded['scope'],
      ClinicalLongFormBackendTranscriptionGrant.requiredScope,
    );
  });

  test('grant provider retry classification is deterministic', () async {
    Future<ClinicalLongFormBackendGrantProviderException> run(
      int status,
    ) async {
      final provider = ClinicalLongFormHttpsBackendGrantProvider(
        endpoint: Uri.parse(
          'https://sandbox.medcases.invalid/v1/audio/grant',
        ),
        client: _CapturingClient(
          statusCode: status,
          body: '{"error":"synthetic"}',
        ),
        sessionAccessTokenProvider: const _SessionTokenProvider(),
      );

      try {
        await provider.acquireTranscriptionGrant(
          sessionId: 'grant_sandbox_001',
          deduplicationKey: 'grant_sandbox_001:segment:0',
        );
      } on ClinicalLongFormBackendGrantProviderException catch (error) {
        return error;
      }

      throw StateError('Expected grant provider exception.');
    }

    expect((await run(503)).retryable, isTrue);
    expect((await run(429)).retryable, isTrue);
    expect((await run(401)).retryable, isFalse);
    expect((await run(403)).retryable, isFalse);
  });

  test('remote batch provider maps grant failure before gateway', () async {
    final gateway = _NeverGateway();

    final provider = ClinicalLongFormRemoteBatchSandboxProvider(
      consent: ClinicalLongFormRemoteAudioConsent(
        disclosureVersion: 'sandbox_test_v1',
        acceptedAtUtc: DateTime.utc(2026, 8, 19, 17),
        remoteTranscriptionAccepted: true,
      ),
      grantProvider: const _FailingGrantProvider(),
      gateway: gateway,
      audioInspector: const _DescriptorInspector(),
      medicalKeywords: const <String>['ceftriaxona'],
    );

    await expectLater(
      () => provider.transcribeSegment(
        const ClinicalLongFormBatchTranscriptionRequest(
          sessionId: 'grant_sandbox_001',
          locale: 'pt-BR',
          segmentIndex: 0,
          segmentPath: '/local/segment_00000.m4a',
          deduplicationKey: 'grant_sandbox_001:segment:0',
        ),
      ),
      throwsA(
        isA<ClinicalLongFormBatchTranscriptionException>()
            .having(
              (error) => error.code,
              'code',
              'synthetic_grant_503',
            )
            .having(
              (error) => error.retryable,
              'retryable',
              isTrue,
            ),
      ),
    );

    expect(gateway.calls, 0);
  });

  test('Ed25519 verifier accepts valid signature and key rotation id',
      () async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();

    const keyId = 'sandbox-2026-01';

    final verifier = ClinicalLongFormEd25519NoRetentionAttestationVerifier(
      trustedPublicKeysById: <String, List<int>>{
        keyId: publicKey.bytes,
      },
    );

    final attestation = await _signedAttestation(
      keyId: keyId,
      keyPair: keyPair,
    );

    expect(verifier.trustedKeyCount, 1);
    expect(await verifier.verify(attestation), isTrue);
  });

  test('Ed25519 verifier rejects tampered signed payload', () async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();

    const keyId = 'sandbox-2026-01';

    final verifier = ClinicalLongFormEd25519NoRetentionAttestationVerifier(
      trustedPublicKeysById: <String, List<int>>{
        keyId: publicKey.bytes,
      },
    );

    final signed = await _signedAttestation(
      keyId: keyId,
      keyPair: keyPair,
    );

    final tampered = _attestation(
      token: signed.attestationToken,
      idempotencyKey: 'attestation_sandbox_001:segment:999',
    );

    expect(await verifier.verify(tampered), isFalse);
  });

  test('Ed25519 verifier rejects unknown key id', () async {
    final algorithm = Ed25519();
    final signer = await algorithm.newKeyPair();
    final trusted = await algorithm.newKeyPair();
    final trustedPublic = await trusted.extractPublicKey();

    final verifier = ClinicalLongFormEd25519NoRetentionAttestationVerifier(
      trustedPublicKeysById: <String, List<int>>{
        'trusted-key': trustedPublic.bytes,
      },
    );

    final signed = await _signedAttestation(
      keyId: 'unknown-key',
      keyPair: signer,
    );

    expect(await verifier.verify(signed), isFalse);
  });

  test('pre-cutover gate records grant provider and verifier certified', () {
    const gate = ClinicalLongFormPreCutoverGate();
    final assessment = gate.evaluate(
      ClinicalLongFormPreCutoverEvidence.currentCertifiedFoundation(),
    );

    expect(
      assessment.blockers,
      isNot(contains(
        ClinicalLongFormPreCutoverRequirement.realBackendGrantProviderCertified,
      )),
    );
    expect(
      assessment.blockers,
      isNot(contains(
        ClinicalLongFormPreCutoverRequirement.realNoRetentionVerifierCertified,
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
    expect(assessment.eligible, isTrue);
  });

  test('production source contains public verification only', () {
    final verifierSource = File(
      'lib/services/audio/'
      'clinical_long_form_ed25519_no_retention_attestation_verifier.dart',
    ).readAsStringSync();

    final grantSource = File(
      'lib/services/audio/'
      'clinical_long_form_https_backend_grant_provider.dart',
    ).readAsStringSync();

    expect(
      verifierSource,
      contains('privateSigningKeyPresentInFlutter = false'),
    );
    expect(
      verifierSource,
      contains('publicKeyVerificationOnly = true'),
    );
    expect(
      grantSource,
      contains('persistentGrantStorageUsed = false'),
    );
    expect(
      grantSource,
      contains('openAiCredentialUsedByClient = false'),
    );

    for (final forbidden in <String>[
      'OPENAI_API_KEY',
      'api.openai.com',
      'sk-',
      'SimpleKeyPairData',
      'newKeyPair(',
      '.sign(',
    ]) {
      expect(
        verifierSource,
        isNot(contains(forbidden)),
        reason: forbidden,
      );
    }

    final main = File('lib/main.dart').readAsStringSync();
    final recorder =
        File('lib/services/clinical_recorder_service.dart').readAsStringSync();
    final history = File('lib/screens/history_screen.dart').readAsStringSync();

    expect(
      main,
      isNot(contains('ClinicalLongFormHttpsBackendGrantProvider')),
    );
    expect(
      recorder,
      isNot(contains('ClinicalLongFormEd25519NoRetentionAttestationVerifier')),
    );
    expect(
      history,
      isNot(contains('ClinicalLongFormHttpsBackendGrantProvider')),
    );
  });
}
