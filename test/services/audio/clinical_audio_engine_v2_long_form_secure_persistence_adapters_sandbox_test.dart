import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_long_form_audio_contract.dart';
import 'package:medcases/services/audio/clinical_long_form_batch_transcription_queue.dart';
import 'package:medcases/services/audio/clinical_long_form_native_at_rest_platform_bridge.dart';
import 'package:medcases/services/audio/clinical_long_form_native_secure_persistence_adapters.dart';
import 'package:medcases/services/audio/clinical_long_form_recording_manifest.dart';
import 'package:medcases/services/audio/clinical_long_form_reviewed_transcript_artifact.dart';
import 'package:medcases/services/audio/clinical_long_form_segment_transcript_checkpoint.dart';

ClinicalLongFormRecordingManifest _manifest({
  String sessionId = 'secure_store_001',
  Duration total = const Duration(minutes: 5),
}) {
  return ClinicalLongFormRecordingManifest(
    sessionId: sessionId,
    locale: 'pt-BR',
    state: ClinicalLongFormRecordingState.stopped,
    createdAtUtc: DateTime.utc(2026, 8, 19, 20),
    totalActiveDuration: total,
    segments: <ClinicalLongFormSegmentManifest>[
      ClinicalLongFormSegmentManifest(
        index: 0,
        path: '/opaque/$sessionId/segment_00000.m4a',
        startedAtUtc: DateTime.utc(2026, 8, 19, 20),
        activeDuration: total,
        completed: true,
      ),
    ],
  );
}

ClinicalLongFormSegmentTranscriptCheckpoint _checkpoint({
  required int index,
  required String transcript,
}) {
  return ClinicalLongFormSegmentTranscriptCheckpoint(
    sessionId: 'secure_checkpoint_001',
    segmentIndex: index,
    deduplicationKey: 'secure_checkpoint_001:segment:$index',
    transcript: transcript,
    resultRef: 'local://secure/$index',
    completedAtUtc: DateTime.utc(2026, 8, 19, 20, index),
  );
}

ClinicalLongFormReviewedTranscriptArtifact _reviewedArtifact() {
  return ClinicalLongFormReviewedTranscriptArtifact(
    sessionId: 'secure_review_001',
    locale: 'pt-BR',
    reviewedTranscript: 'Paciente sem sinais de alarme. Texto revisado.',
    reviewedAtUtc: DateTime.utc(2026, 8, 19, 20),
    sourceSegmentCount: 1,
    sourceActiveDuration: const Duration(minutes: 5),
    retentionState: ClinicalLongFormAudioRetentionState.reviewedPersisted,
    audioDisposition: null,
  );
}

Uint8List _sealBytes(Uint8List clear) {
  final transformed = clear.map((value) => value ^ 0xA5).toList();
  return Uint8List.fromList(
    <int>[
      ...List<int>.filled(29, 0x5A),
      ...transformed,
    ],
  );
}

Uint8List _openBytes(Uint8List sealed) {
  if (sealed.length <= 29) {
    throw const FormatException('mock sealed payload too short');
  }
  return Uint8List.fromList(
    sealed.sublist(29).map((value) => value ^ 0xA5).toList(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    ClinicalLongFormNativeAtRestPlatformBridge.channelName,
  );

  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final args = (call.arguments as Map?)?.cast<String, Object?>() ??
          <String, Object?>{};

      switch (call.method) {
        case 'protectDurableFile':
        case 'protectActiveAudioFile':
          return null;
        case 'seal':
          return _sealBytes(args['clearText']! as Uint8List);
        case 'open':
          return _openBytes(args['sealedData']! as Uint8List);
        case 'sealFile':
          final source = File(args['sourcePath']! as String);
          final destination = File(args['destinationPath']! as String);
          final sealed = _sealBytes(await source.readAsBytes());
          await destination.writeAsBytes(sealed, flush: true);
          return <String, Object?>{
            'path': destination.path,
            'byteCount': sealed.length,
          };
        case 'openFile':
          final source = File(args['sourcePath']! as String);
          final destination = File(args['destinationPath']! as String);
          final clear = _openBytes(await source.readAsBytes());
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

  test('secure durable manifest and queue persist ciphertext only', () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_native_secure_durable_',
    );

    try {
      final bridge = ClinicalLongFormNativeAtRestPlatformBridge(
        channel: channel,
      );
      final store = NativeSecureClinicalLongFormDurableStore(
        rootDirectory: root,
        bridge: bridge,
        keyId: 'device-key-v1',
      );

      final manifest = _manifest();
      final queue = ClinicalLongFormBatchQueue.fromManifest(manifest);

      await store.saveManifest(manifest);
      await store.saveBatchQueue(queue);

      final manifestFile = File(
        '${root.path}${Platform.pathSeparator}'
        'secure_store_001${Platform.pathSeparator}manifest.json',
      );
      final queueFile = File(
        '${root.path}${Platform.pathSeparator}'
        'secure_store_001${Platform.pathSeparator}batch_queue.json',
      );

      final manifestRaw = utf8.decode(
        await manifestFile.readAsBytes(),
        allowMalformed: true,
      );
      final queueRaw = utf8.decode(
        await queueFile.readAsBytes(),
        allowMalformed: true,
      );

      expect(
        manifestRaw,
        isNot(contains('medcases.long_form_audio_manifest.v1')),
      );
      expect(
        queueRaw,
        isNot(contains('medcases.long_form_batch_queue.v1')),
      );

      final loadedManifest = await store.loadManifest('secure_store_001');
      final loadedQueue = await store.loadBatchQueue('secure_store_001');

      expect(loadedManifest?.sessionId, 'secure_store_001');
      expect(loadedManifest?.segments.single.completed, isTrue);
      expect(loadedQueue?.totalCount, 1);
      expect(loadedQueue?.items.single.segmentIndex, 0);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('secure durable store falls back to encrypted previous-good backup',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_native_secure_backup_',
    );

    try {
      final bridge = ClinicalLongFormNativeAtRestPlatformBridge(
        channel: channel,
      );
      final store = NativeSecureClinicalLongFormDurableStore(
        rootDirectory: root,
        bridge: bridge,
        keyId: 'device-key-v1',
      );

      await store.saveManifest(
        _manifest(total: const Duration(minutes: 5)),
      );
      await store.saveManifest(
        _manifest(total: const Duration(minutes: 7)),
      );

      final primary = File(
        '${root.path}${Platform.pathSeparator}'
        'secure_store_001${Platform.pathSeparator}manifest.json',
      );
      final backup = File('${primary.path}.bak');

      expect(await backup.exists(), isTrue);

      await primary.writeAsBytes(
        Uint8List.fromList(<int>[1, 2, 3]),
        flush: true,
      );

      final recovered = await store.loadManifest('secure_store_001');

      expect(
        recovered?.totalActiveDuration,
        const Duration(minutes: 5),
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('secure checkpoint store encrypts transcript and loadAll is ordered',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_native_secure_checkpoint_',
    );

    try {
      final bridge = ClinicalLongFormNativeAtRestPlatformBridge(
        channel: channel,
      );
      final store =
          NativeSecureClinicalLongFormSegmentTranscriptCheckpointStore(
        rootDirectory: root,
        bridge: bridge,
        keyId: 'device-key-v1',
      );

      await store.save(
        _checkpoint(index: 1, transcript: 'Segundo segmento clínico.'),
      );
      await store.save(
        _checkpoint(index: 0, transcript: 'Primeiro segmento clínico.'),
      );

      final raw = utf8.decode(
        await File(
          '${root.path}${Platform.pathSeparator}'
          'secure_checkpoint_001${Platform.pathSeparator}'
          'segment_transcripts${Platform.pathSeparator}'
          'segment_00000.json',
        ).readAsBytes(),
        allowMalformed: true,
      );

      expect(raw, isNot(contains('Primeiro segmento clínico.')));

      final all = await store.loadAll('secure_checkpoint_001');

      expect(all.map((item) => item.segmentIndex), <int>[0, 1]);
      expect(all.first.transcript, 'Primeiro segmento clínico.');
      expect(all.last.transcript, 'Segundo segmento clínico.');
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('reviewed transcript persists encrypted while retaining typed model',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_native_secure_reviewed_',
    );

    try {
      final bridge = ClinicalLongFormNativeAtRestPlatformBridge(
        channel: channel,
      );
      final store = NativeSecureClinicalLongFormReviewedArtifactStore(
        rootDirectory: root,
        bridge: bridge,
        keyId: 'device-key-v1',
      );
      final artifact = _reviewedArtifact();

      await store.save(artifact);

      final file = File(
        '${root.path}${Platform.pathSeparator}'
        'secure_review_001${Platform.pathSeparator}'
        'reviewed_transcript.json',
      );
      final raw = utf8.decode(
        await file.readAsBytes(),
        allowMalformed: true,
      );

      expect(raw, isNot(contains('Paciente sem sinais de alarme')));
      expect(
        (await store.load('secure_review_001'))?.reviewedTranscript,
        artifact.reviewedTranscript,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('closed M4A uses file-to-file bridge and never crosses as channel bytes',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_native_secure_audio_',
    );

    try {
      final clear = File(
        '${root.path}${Platform.pathSeparator}segment_00000.m4a',
      );
      final sealed = File('${clear.path}.sealed');
      final staging = File(
        '${root.path}${Platform.pathSeparator}staging_00000.m4a',
      );

      final original = Uint8List.fromList(
        List<int>.generate(4096, (index) => index % 251),
      );
      await clear.writeAsBytes(original, flush: true);

      final bridge = ClinicalLongFormNativeAtRestPlatformBridge(
        channel: channel,
      );
      final adapter = NativeSecureClinicalLongFormClosedAudioAdapter(
        bridge: bridge,
        keyId: 'device-key-v1',
      );

      final sealResult = await adapter.sealClosedSegment(
        sessionId: 'secure_audio_001',
        segmentIndex: 0,
        clearM4a: clear,
        sealedDestination: sealed,
      );

      expect(sealResult.path, sealed.path);
      expect(await clear.exists(), isTrue);
      expect(await sealed.exists(), isTrue);

      final openResult = await adapter.openToPlaintextStaging(
        sessionId: 'secure_audio_001',
        segmentIndex: 0,
        sealedSource: sealed,
        stagingM4a: staging,
      );

      expect(openResult.path, staging.path);
      expect(await staging.readAsBytes(), original);

      final sealFileCall =
          calls.firstWhere((call) => call.method == 'sealFile');
      final openFileCall =
          calls.firstWhere((call) => call.method == 'openFile');

      final sealArgs = (sealFileCall.arguments as Map).cast<String, Object?>();
      final openArgs = (openFileCall.arguments as Map).cast<String, Object?>();

      expect(sealArgs.containsKey('clearText'), isFalse);
      expect(sealArgs.containsKey('sealedData'), isFalse);
      expect(openArgs.containsKey('clearText'), isFalse);
      expect(openArgs.containsKey('sealedData'), isFalse);
      expect(
        NativeSecureClinicalLongFormClosedAudioAdapter
            .plaintextSourceAutoDeleteEnabled,
        isFalse,
      );
      expect(
        NativeSecureClinicalLongFormClosedAudioAdapter
            .plaintextStagingMaximumLifetimeSeconds,
        120,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('native sources expose file-to-file AES-GCM contract', () async {
    final ios = await File('ios/Runner/AppDelegate.swift').readAsString();
    final android = await File(
      'android/app/src/main/kotlin/com/medcasespro/med/MainActivity.kt',
    ).readAsString();
    final bridge = await File(
      'lib/services/audio/'
      'clinical_long_form_native_at_rest_platform_bridge.dart',
    ).readAsString();

    for (final source in <String>[ios, android, bridge]) {
      expect(source, contains('sealFile'));
      expect(source, contains('openFile'));
    }

    expect(ios, contains('AES.GCM.seal'));
    expect(ios, contains('AES.GCM.open'));
    expect(android, contains('Cipher.ENCRYPT_MODE'));
    expect(android, contains('Cipher.DECRYPT_MODE'));
    expect(
      bridge,
      contains('nativeFileToFileCryptoImplemented = true'),
    );
    expect(
      ClinicalLongFormNativeAtRestPlatformBridge
          .productionPersistenceIntegrationEnabled,
      isFalse,
    );
    expect(
      ClinicalLongFormNativeAtRestPlatformBridge.productionCutoverEnabled,
      isFalse,
    );
  });

  test('sandbox adapters are absent from current production audio owners',
      () async {
    final owners = <String>[
      'lib/services/clinical_recorder_service.dart',
      'lib/screens/clinical_recorder_sheet.dart',
      'lib/screens/history_screen.dart',
      'lib/services/audio/record_long_form_audio_provider.dart',
      'lib/services/audio/clinical_long_form_durable_store.dart',
      'lib/services/audio/'
          'clinical_long_form_segment_transcript_checkpoint_store.dart',
      'lib/services/audio/clinical_long_form_reviewed_artifact_store.dart',
    ];

    for (final path in owners) {
      final source = await File(path).readAsString();
      expect(
        source,
        isNot(contains(
          'clinical_long_form_native_secure_persistence_adapters.dart',
        )),
        reason: path,
      );
      expect(
        source,
        isNot(contains('NativeSecureClinicalLongForm')),
        reason: path,
      );
    }
  });

  test('sandbox adapters expose no remote or production cutover', () async {
    final source = await File(
      'lib/services/audio/'
      'clinical_long_form_native_secure_persistence_adapters.dart',
    ).readAsString();

    expect(
      source,
      contains('productionPersistenceIntegrationEnabled = false'),
    );
    expect(source, contains('productionCutoverEnabled = false'));
    expect(source, contains('remoteTransportWiringEnabled = false'));
    expect(source, isNot(contains('api.openai.com')));
    expect(source, isNot(contains('OPENAI_API_KEY')));
    expect(source, isNot(contains('http.')));
  });
}
