import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_long_form_audio_contract.dart';
import 'package:medcases/services/audio/clinical_long_form_backend_auth_contract.dart';
import 'package:medcases/services/audio/clinical_long_form_backend_no_retention_attestation.dart';
import 'package:medcases/services/audio/clinical_long_form_backend_proxy_gateway_sandbox.dart';
import 'package:medcases/services/audio/clinical_long_form_backend_proxy_server_contract.dart';
import 'package:medcases/services/audio/clinical_long_form_batch_transcription_queue.dart';
import 'package:medcases/services/audio/clinical_long_form_checkpointed_batch_runner.dart';
import 'package:medcases/services/audio/clinical_long_form_durable_store.dart';
import 'package:medcases/services/audio/clinical_long_form_engine_state_recovery_orchestrator.dart';
import 'package:medcases/services/audio/clinical_long_form_recording_manifest.dart';
import 'package:medcases/services/audio/clinical_long_form_remote_batch_sandbox_provider.dart';
import 'package:medcases/services/audio/clinical_long_form_remote_transcription_policy.dart';
import 'package:medcases/services/audio/clinical_long_form_segment_transcript_checkpoint_store.dart';
import 'package:medcases/services/audio/clinical_long_form_transcript_assembler.dart';
import 'package:medcases/services/audio/openai_file_transcription_shadow_protocol.dart';

final class _CertInspector implements ClinicalLongFormLocalAudioInspector {
  const _CertInspector();

  @override
  Future<ClinicalLongFormLocalAudioDescriptor> inspect(
    String segmentPath,
  ) async {
    return ClinicalLongFormLocalAudioDescriptor(
      path: segmentPath,
      fileBytes: 2400000,
    );
  }
}

final class _CertGrantProvider implements ClinicalLongFormBackendGrantProvider {
  int calls = 0;

  @override
  Future<ClinicalLongFormBackendTranscriptionGrant> acquireTranscriptionGrant({
    required String sessionId,
    required String deduplicationKey,
  }) async {
    calls++;
    final now = DateTime.now().toUtc();

    return ClinicalLongFormBackendTranscriptionGrant(
      sessionId: sessionId,
      scope: ClinicalLongFormBackendTranscriptionGrant.requiredScope,
      accessToken: 'medcases_cert_ephemeral_grant_1234567890',
      issuedAtUtc: now.subtract(const Duration(seconds: 10)),
      expiresAtUtc: now.add(const Duration(minutes: 10)),
    );
  }
}

final class _CertVerifier
    implements ClinicalLongFormBackendNoRetentionAttestationVerifier {
  const _CertVerifier({
    this.valid = true,
  });

  final bool valid;

  @override
  Future<bool> verify(
    ClinicalLongFormBackendNoRetentionAttestation attestation,
  ) async {
    return valid;
  }
}

final class _CertTransport implements ClinicalLongFormBackendProxyTransport {
  _CertTransport({
    this.failFirstRetryable = false,
  });

  final bool failFirstRetryable;

  final Map<String, int> attemptsByKey = <String, int>{};
  final List<String> observedIdempotencyKeys = <String>[];

  @override
  Future<ClinicalLongFormBackendProxyResponse> transcribe({
    required ClinicalLongFormBackendProxyRequest request,
    required ClinicalLongFormBackendTranscriptionGrant grant,
  }) async {
    observedIdempotencyKeys.add(request.idempotencyKey);

    final attempts = (attemptsByKey[request.idempotencyKey] ?? 0) + 1;
    attemptsByKey[request.idempotencyKey] = attempts;

    if (failFirstRetryable && attempts == 1) {
      throw const ClinicalLongFormBackendProxyException(
        'synthetic_retryable_backend_failure',
      );
    }

    final segmentIndex = int.parse(
      request.idempotencyKey.split(':').last,
    );

    final transcript = <int, String>{
      0: 'Paciente com insuficiência cardíaca e dispneia aos esforços.',
      1: 'Foi revisada fração de ejeção reduzida e ceftriaxona 2 g.',
      2: 'Foram discutidos seguimento e sinais de alarme.',
    }[segmentIndex]!;

    final received = DateTime.utc(2026, 8, 19, 13);
    final completed = received.add(Duration(seconds: 2 + segmentIndex));
    final deleted = completed.add(const Duration(seconds: 1));

    final key = request.idempotencyKey;

    return ClinicalLongFormBackendProxyResponse(
      idempotencyKey: key,
      transcript: transcript,
      resultRef: 'backend://cert/$segmentIndex',
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
        attestationToken:
            'signed_cert_attestation_token_${segmentIndex}_1234567890',
      ),
    );
  }
}

ClinicalLongFormRecordingManifest _manifest({
  String sessionId = 'remote_e2e_001',
  int segmentCount = 3,
}) {
  return ClinicalLongFormRecordingManifest(
    sessionId: sessionId,
    locale: 'pt-BR',
    state: ClinicalLongFormRecordingState.stopped,
    createdAtUtc: DateTime.utc(2026, 8, 19, 12),
    totalActiveDuration: Duration(minutes: segmentCount * 5),
    segments: List<ClinicalLongFormSegmentManifest>.generate(
      segmentCount,
      (index) => ClinicalLongFormSegmentManifest(
        index: index,
        path: '/local/audio/segment_${index.toString().padLeft(5, '0')}.m4a',
        startedAtUtc: DateTime.utc(2026, 8, 19, 12).add(
          Duration(minutes: index * 5),
        ),
        activeDuration: const Duration(minutes: 5),
        completed: true,
      ),
      growable: false,
    ),
  );
}

ClinicalLongFormRemoteAudioConsent _consent() {
  return ClinicalLongFormRemoteAudioConsent(
    disclosureVersion: 'remote_audio_sandbox_cert_v1',
    acceptedAtUtc: DateTime.utc(2026, 8, 19, 13),
    remoteTranscriptionAccepted: true,
  );
}

ClinicalLongFormRemoteBatchSandboxProvider _provider({
  required _CertGrantProvider grants,
  required _CertTransport transport,
  ClinicalLongFormBackendNoRetentionAttestationVerifier verifier =
      const _CertVerifier(),
}) {
  final gateway = ClinicalLongFormBackendProxyGatewaySandbox(
    transport: transport,
    attestationVerifier: verifier,
  );

  return ClinicalLongFormRemoteBatchSandboxProvider(
    consent: _consent(),
    grantProvider: grants,
    gateway: gateway,
    audioInspector: const _CertInspector(),
    medicalKeywords: const <String>[
      'insuficiência cardíaca',
      'fração de ejeção',
      'ceftriaxona',
    ],
  );
}

void main() {
  test(
    'remote sandbox E2E certifies provider proxy attestation checkpoint '
    'restart recovery and final assembly',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'medcases_remote_e2e_cert_',
      );

      try {
        final manifest = _manifest();
        final durableStore = FileClinicalLongFormDurableStore(
          rootDirectory: root,
        );
        final checkpointStore =
            FileClinicalLongFormSegmentTranscriptCheckpointStore(
          rootDirectory: root,
        );

        await durableStore.saveManifest(manifest);

        final queue = ClinicalLongFormBatchQueue.fromManifest(manifest);
        await durableStore.saveBatchQueue(queue);

        final assembler = ClinicalLongFormTranscriptAssembler(
          expectedSegmentCount: queue.totalCount,
        );

        final grants = _CertGrantProvider();
        final transport = _CertTransport();

        final runner = ClinicalLongFormCheckpointedBatchRunner(
          queue: queue,
          provider: _provider(
            grants: grants,
            transport: transport,
          ),
          assembler: assembler,
          durableStore: durableStore,
          checkpointStore: checkpointStore,
          locale: manifest.locale,
          nowUtc: () => DateTime.utc(2026, 8, 19, 13, 10),
        );

        final outcome = await runner.runUntilBlocked();

        expect(outcome.completed, 3);
        expect(outcome.failed, 0);
        expect(queue.isComplete, isTrue);
        expect(assembler.isComplete, isTrue);
        expect(grants.calls, 3);

        final checkpoints = await checkpointStore.loadAll(manifest.sessionId);
        expect(checkpoints, hasLength(3));

        await runner.dispose();

        // Simulated app/process restart.
        final restoredQueue =
            await durableStore.loadBatchQueue(manifest.sessionId);
        expect(restoredQueue, isNotNull);

        final recovery = ClinicalLongFormEngineStateRecoveryOrchestrator(
          checkpointStore: checkpointStore,
        );

        final recovered = await recovery.recoverBatch(
          manifest: manifest,
          queue: restoredQueue!,
        );

        expect(recovered.queue.isComplete, isTrue);
        expect(recovered.assembler.isComplete, isTrue);
        expect(recovered.checkpointsLoaded, 3);

        final finalTranscript = recovered.assembler.assemble();

        expect(finalTranscript.complete, isTrue);
        expect(
          finalTranscript.text,
          contains('insuficiência cardíaca'),
        );
        expect(
          finalTranscript.text,
          contains('ceftriaxona 2 g'),
        );
        expect(
          finalTranscript.text,
          contains('sinais de alarme'),
        );

        expect(
          transport.observedIdempotencyKeys,
          <String>[
            'remote_e2e_001:segment:0',
            'remote_e2e_001:segment:1',
            'remote_e2e_001:segment:2',
          ],
        );
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  test('retryable backend failure preserves the same idempotency key',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_remote_retry_cert_',
    );

    try {
      final manifest = _manifest(
        sessionId: 'remote_retry_001',
        segmentCount: 1,
      );
      final durableStore = FileClinicalLongFormDurableStore(
        rootDirectory: root,
      );
      final checkpointStore =
          FileClinicalLongFormSegmentTranscriptCheckpointStore(
        rootDirectory: root,
      );
      final queue = ClinicalLongFormBatchQueue.fromManifest(manifest);
      final assembler = ClinicalLongFormTranscriptAssembler(
        expectedSegmentCount: 1,
      );

      final transport = _CertTransport(
        failFirstRetryable: true,
      );

      final runner = ClinicalLongFormCheckpointedBatchRunner(
        queue: queue,
        provider: _provider(
          grants: _CertGrantProvider(),
          transport: transport,
        ),
        assembler: assembler,
        durableStore: durableStore,
        checkpointStore: checkpointStore,
        locale: manifest.locale,
        nowUtc: () => DateTime.utc(2026, 8, 19, 13, 20),
      );

      final outcome = await runner.runUntilBlocked();

      expect(outcome.completed, 1);
      expect(outcome.failed, 1);
      expect(queue.isComplete, isTrue);
      expect(
        transport.observedIdempotencyKeys,
        <String>[
          'remote_retry_001:segment:0',
          'remote_retry_001:segment:0',
        ],
      );

      final checkpoints = await checkpointStore.loadAll(manifest.sessionId);
      expect(checkpoints, hasLength(1));
      expect(
        checkpoints.single.deduplicationKey,
        'remote_retry_001:segment:0',
      );

      await runner.dispose();
    } finally {
      await root.delete(recursive: true);
    }
  });

  test(
    'invalid no-retention verification blocks checkpoint and completion',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'medcases_remote_attestation_fail_',
      );

      try {
        final manifest = _manifest(
          sessionId: 'remote_attestation_fail_001',
          segmentCount: 1,
        );
        final durableStore = FileClinicalLongFormDurableStore(
          rootDirectory: root,
        );
        final checkpointStore =
            FileClinicalLongFormSegmentTranscriptCheckpointStore(
          rootDirectory: root,
        );
        final queue = ClinicalLongFormBatchQueue.fromManifest(manifest);
        final assembler = ClinicalLongFormTranscriptAssembler(
          expectedSegmentCount: 1,
        );

        final runner = ClinicalLongFormCheckpointedBatchRunner(
          queue: queue,
          provider: _provider(
            grants: _CertGrantProvider(),
            transport: _CertTransport(),
            verifier: const _CertVerifier(valid: false),
          ),
          assembler: assembler,
          durableStore: durableStore,
          checkpointStore: checkpointStore,
          locale: manifest.locale,
          nowUtc: () => DateTime.utc(2026, 8, 19, 13, 25),
        );

        final outcome = await runner.runUntilBlocked();

        expect(outcome.completed, 0);
        expect(outcome.failed, 1);
        expect(queue.isComplete, isFalse);
        expect(
          queue.items.single.status,
          ClinicalLongFormBatchItemStatus.failed,
        );
        expect(
          queue.items.single.lastErrorCode,
          'backend_no_retention_attestation_invalid',
        );

        final checkpoints = await checkpointStore.loadAll(manifest.sessionId);
        expect(checkpoints, isEmpty);
        expect(assembler.receivedSegmentCount, 0);

        await runner.dispose();
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  test('remote E2E certification introduces no real transport or cutover', () {
    final source = <String>[
      File(
        'lib/services/audio/'
        'clinical_long_form_remote_transcription_policy.dart',
      ).readAsStringSync(),
      File(
        'lib/services/audio/'
        'clinical_long_form_backend_auth_contract.dart',
      ).readAsStringSync(),
      File(
        'lib/services/audio/'
        'clinical_long_form_remote_batch_sandbox_provider.dart',
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
      'MultipartRequest',
      'Firebase',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }

    expect(
      source,
      contains('actualNetworkTransportImplemented = false'),
    );
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

    final main = File('lib/main.dart').readAsStringSync();
    final recorder =
        File('lib/services/clinical_recorder_service.dart').readAsStringSync();
    final history = File('lib/screens/history_screen.dart').readAsStringSync();

    expect(
      main,
      isNot(contains('ClinicalLongFormRemoteBatchSandboxProvider')),
    );
    expect(
      recorder,
      isNot(contains('ClinicalLongFormBackendProxyGatewaySandbox')),
    );
    expect(
      history,
      isNot(contains('ClinicalLongFormRemoteBatchSandboxProvider')),
    );
  });
}
