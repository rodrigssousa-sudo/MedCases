import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_long_form_backend_auth_contract.dart';
import 'package:medcases/services/audio/clinical_long_form_batch_transcription_provider.dart';
import 'package:medcases/services/audio/clinical_long_form_native_at_rest_platform_bridge.dart';
import 'package:medcases/services/audio/clinical_long_form_native_secure_persistence_adapters.dart';
import 'package:medcases/services/audio/clinical_long_form_remote_batch_sandbox_provider.dart';
import 'package:medcases/services/audio/clinical_long_form_remote_transcription_policy.dart';
import 'package:medcases/services/audio/clinical_long_form_secure_plaintext_staging_lifecycle.dart';
import 'package:medcases/services/audio/clinical_long_form_staging_to_backend_sandbox_adapter.dart';
import 'package:medcases/services/audio/file_clinical_long_form_local_audio_inspector.dart';
import 'package:medcases/services/audio/openai_file_transcription_shadow_protocol.dart';

final class _FakeGrantProvider implements ClinicalLongFormBackendGrantProvider {
  _FakeGrantProvider(this.nowUtc);

  final DateTime nowUtc;
  int calls = 0;

  @override
  Future<ClinicalLongFormBackendTranscriptionGrant> acquireTranscriptionGrant({
    required String sessionId,
    required String deduplicationKey,
  }) async {
    calls++;
    return ClinicalLongFormBackendTranscriptionGrant(
      sessionId: sessionId,
      scope: ClinicalLongFormBackendTranscriptionGrant.requiredScope,
      accessToken: 'medcases_synthetic_ephemeral_grant_1234567890',
      issuedAtUtc: nowUtc.subtract(const Duration(seconds: 5)),
      expiresAtUtc: nowUtc.add(const Duration(minutes: 5)),
    );
  }
}

final class _FakeGateway
    implements MedCasesLongFormBackendTranscriptionGateway {
  _FakeGateway({
    this.fail = false,
  });

  final bool fail;
  int calls = 0;
  String? observedPath;
  bool plaintextExistedDuringCall = false;
  List<int>? observedBytes;
  OpenAiFileTranscriptionShadowRequest? lastRequest;

  @override
  Future<MedCasesLongFormBackendTranscriptionResponse> transcribe({
    required OpenAiFileTranscriptionShadowRequest request,
    required ClinicalLongFormBackendTranscriptionGrant grant,
  }) async {
    calls++;
    lastRequest = request;
    observedPath = request.segmentPath;

    final file = File(request.segmentPath);
    plaintextExistedDuringCall = await file.exists();
    if (plaintextExistedDuringCall) {
      observedBytes = await file.readAsBytes();
    }

    if (fail) {
      throw const MedCasesLongFormBackendException(
        'synthetic_backend_failure',
      );
    }

    return const MedCasesLongFormBackendTranscriptionResponse(
      transcript: 'Ceftriaxona 2 g intravenosa.',
      resultRef: 'backend://synthetic/result-001',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    ClinicalLongFormNativeAtRestPlatformBridge.channelName,
  );

  late DateTime nowUtc;

  setUp(() {
    nowUtc = DateTime.utc(2026, 8, 19, 22);

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
        _FakeGrantProvider grants,
        _FakeGateway gateway,
        ClinicalLongFormStagingToBackendSandboxAdapter adapter,
      })> fixture({
    bool gatewayFailure = false,
  }) async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_staging_backend_',
    );

    final sourceDirectory = Directory(
      '${root.path}${Platform.pathSeparator}'
      'synthetic_session_001${Platform.pathSeparator}audio',
    );
    await sourceDirectory.create(recursive: true);

    final sealed = File(
      '${sourceDirectory.path}${Platform.pathSeparator}'
      'segment_00000.m4a.sealed',
    );

    final clearBytes = List<int>.generate(
      4096,
      (index) => (index * 7) % 251,
    );
    await sealed.writeAsBytes(
      clearBytes.map((value) => value ^ 0xA5).toList(),
      flush: true,
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
      nonceFactory: () => '11223344556677889900aabbccddeeff',
    );

    final grants = _FakeGrantProvider(nowUtc);
    final gateway = _FakeGateway(fail: gatewayFailure);
    final remoteProvider = ClinicalLongFormRemoteBatchSandboxProvider(
      consent: ClinicalLongFormRemoteAudioConsent(
        disclosureVersion: 'synthetic_sandbox_v1',
        acceptedAtUtc: nowUtc,
        remoteTranscriptionAccepted: true,
      ),
      grantProvider: grants,
      gateway: gateway,
      audioInspector: const FileClinicalLongFormLocalAudioInspector(),
      medicalKeywords: const <String>[
        'ceftriaxona',
        'insuficiência cardíaca',
      ],
      nowUtc: () => nowUtc,
    );

    return (
      root: root,
      sealed: sealed,
      clearBytes: clearBytes,
      grants: grants,
      gateway: gateway,
      adapter: ClinicalLongFormStagingToBackendSandboxAdapter(
        stagingLifecycle: stagingLifecycle,
        remoteProvider: remoteProvider,
      ),
    );
  }

  ClinicalLongFormSealedBatchTranscriptionRequest request({
    String sealedPath = '/synthetic/segment_00000.m4a.sealed',
  }) {
    return ClinicalLongFormSealedBatchTranscriptionRequest(
      sessionId: 'synthetic_session_001',
      locale: 'pt-BR',
      segmentIndex: 0,
      sealedSegmentPath: sealedPath,
      deduplicationKey: 'synthetic_session_001:segment:0',
      previousContext: 'Paciente com insuficiência cardíaca.',
    );
  }

  test('sealed segment is staged, delegated, then plaintext is deleted',
      () async {
    final f = await fixture();

    try {
      final result = await f.adapter.transcribeSealedSegment(
        request(sealedPath: f.sealed.path),
      );

      expect(result.segmentIndex, 0);
      expect(
        result.deduplicationKey,
        'synthetic_session_001:segment:0',
      );
      expect(result.transcript, 'Ceftriaxona 2 g intravenosa.');

      expect(f.grants.calls, 1);
      expect(f.gateway.calls, 1);
      expect(f.gateway.plaintextExistedDuringCall, isTrue);
      expect(f.gateway.observedBytes, f.clearBytes);

      final stagedPath = f.gateway.observedPath!;
      expect(stagedPath, isNot(f.sealed.path));
      expect(stagedPath, endsWith('.m4a'));
      expect(
        stagedPath,
        contains('transport_plaintext_staging'),
      );
      expect(await File(stagedPath).exists(), isFalse);
      expect(await f.sealed.exists(), isTrue);
    } finally {
      await f.adapter.dispose();
      await f.root.delete(recursive: true);
    }
  });

  test('backend failure still deletes staged plaintext', () async {
    final f = await fixture(gatewayFailure: true);

    try {
      await expectLater(
        () => f.adapter.transcribeSealedSegment(
          request(sealedPath: f.sealed.path),
        ),
        throwsA(
          isA<ClinicalLongFormBatchTranscriptionException>(),
        ),
      );

      expect(f.gateway.calls, 1);
      expect(f.gateway.plaintextExistedDuringCall, isTrue);

      final stagedPath = f.gateway.observedPath!;
      expect(await File(stagedPath).exists(), isFalse);
      expect(await f.sealed.exists(), isTrue);
    } finally {
      await f.adapter.dispose();
      await f.root.delete(recursive: true);
    }
  });

  test('invalid sealed extension is rejected before staging', () async {
    final f = await fixture();

    try {
      await expectLater(
        () => f.adapter.transcribeSealedSegment(
          request(sealedPath: '${f.root.path}/not-sealed.m4a'),
        ),
        throwsArgumentError,
      );

      expect(f.grants.calls, 0);
      expect(f.gateway.calls, 0);
    } finally {
      await f.adapter.dispose();
      await f.root.delete(recursive: true);
    }
  });

  test('adapter contract is sandbox-only and creates no HTTP owner', () async {
    final source = await File(
      'lib/services/audio/'
      'clinical_long_form_staging_to_backend_sandbox_adapter.dart',
    ).readAsString();

    expect(source, contains('productionCutoverEnabled = false'));
    expect(
      source,
      contains('productionAudioOwnersWired = false'),
    );
    expect(source, contains('realPatientAudioEnabled = false'));
    expect(
      source,
      contains('actualNetworkCreatedByThisAdapter = false'),
    );
    expect(
      source,
      contains('plaintextPathDurablyPersisted = false'),
    );
    expect(source, contains('sealedSourceSentToProvider = false'));
    expect(source, contains('stagingLeaseRequired = true'));
    expect(source, contains('stagingLeaseSingleUseRequired = true'));
    expect(
      source,
      contains('ClinicalLongFormRemoteBatchSandboxProvider'),
    );
    expect(source, isNot(contains('package:http')));
    expect(source, isNot(contains('MultipartRequest')));
    expect(source, isNot(contains('api.openai.com')));
  });

  test('existing production and HTTPS owners remain unwired', () async {
    final owners = <String>[
      'lib/main.dart',
      'lib/services/clinical_recorder_service.dart',
      'lib/screens/clinical_recorder_sheet.dart',
      'lib/screens/history_screen.dart',
      'lib/services/audio/record_long_form_audio_provider.dart',
      'lib/services/audio/clinical_long_form_checkpointed_batch_runner.dart',
      'lib/services/audio/clinical_long_form_remote_batch_sandbox_provider.dart',
      'lib/services/audio/clinical_long_form_https_backend_proxy_transport.dart',
    ];

    for (final path in owners) {
      final source = await File(path).readAsString();
      expect(
        source,
        isNot(contains(
          'clinical_long_form_staging_to_backend_sandbox_adapter.dart',
        )),
        reason: path,
      );
      expect(
        source,
        isNot(contains(
          'ClinicalLongFormStagingToBackendSandboxAdapter',
        )),
        reason: path,
      );
    }
  });
}
