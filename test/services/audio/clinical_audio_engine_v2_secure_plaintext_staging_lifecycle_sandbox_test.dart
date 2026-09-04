import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_long_form_native_at_rest_platform_bridge.dart';
import 'package:medcases/services/audio/clinical_long_form_native_secure_persistence_adapters.dart';
import 'package:medcases/services/audio/clinical_long_form_secure_plaintext_staging_lifecycle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    ClinicalLongFormNativeAtRestPlatformBridge.channelName,
  );

  late DateTime nowUtc;

  setUp(() {
    nowUtc = DateTime.utc(2026, 8, 19, 21, 30);

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
          final clear = Uint8List.fromList(
            sealed.map((value) => value ^ 0xA5).toList(),
          );
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
        ClinicalLongFormSecurePlaintextStagingLifecycle lifecycle,
      })> fixture() async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_plaintext_staging_',
    );

    final sealedDirectory = Directory(
      '${root.path}${Platform.pathSeparator}'
      'secure_audio_001${Platform.pathSeparator}audio',
    );
    await sealedDirectory.create(recursive: true);

    final sealed = File(
      '${sealedDirectory.path}${Platform.pathSeparator}'
      'segment_00000.m4a.sealed',
    );

    final clear = Uint8List.fromList(
      List<int>.generate(1024, (index) => index % 251),
    );
    await sealed.writeAsBytes(
      Uint8List.fromList(
        clear.map((value) => value ^ 0xA5).toList(),
      ),
      flush: true,
    );

    final bridge = ClinicalLongFormNativeAtRestPlatformBridge(
      channel: channel,
    );
    final closedAudioAdapter = NativeSecureClinicalLongFormClosedAudioAdapter(
      bridge: bridge,
      keyId: 'device-key-v1',
    );

    final lifecycle = ClinicalLongFormSecurePlaintextStagingLifecycle(
      secureRootDirectory: root,
      closedAudioAdapter: closedAudioAdapter,
      nowUtc: () => nowUtc,
      nonceFactory: () => '00112233445566778899aabbccddeeff',
    );

    return (
      root: root,
      sealed: sealed,
      lifecycle: lifecycle,
    );
  }

  test('creates opaque staging lease under secure root with 120s TTL',
      () async {
    final f = await fixture();

    try {
      final lease = await f.lifecycle.createLease(
        sessionId: 'secure_audio_001',
        segmentIndex: 0,
        sealedSource: f.sealed,
      );

      expect(await lease.file.exists(), isTrue);
      expect(
        lease.file.path,
        contains('transport_plaintext_staging'),
      );
      expect(
        lease.file.path,
        contains(
          'staging_00112233445566778899aabbccddeeff_'
          'segment_00000.m4a',
        ),
      );
      expect(
        lease.expiresAtUtc.difference(lease.createdAtUtc),
        const Duration(seconds: 120),
      );
      expect(
        ClinicalLongFormSecurePlaintextStagingLifecycle
            .patientIdentityInFilenameAllowed,
        isFalse,
      );
      expect(
        ClinicalLongFormSecurePlaintextStagingLifecycle
            .plaintextRemotePersistenceAllowed,
        isFalse,
      );
    } finally {
      await f.root.delete(recursive: true);
    }
  });

  test('single-use success deletes plaintext in finally', () async {
    final f = await fixture();

    try {
      final lease = await f.lifecycle.createLease(
        sessionId: 'secure_audio_001',
        segmentIndex: 0,
        sealedSource: f.sealed,
      );

      final result = await lease.useOnce((file) async {
        expect(await file.exists(), isTrue);
        expect(await file.length(), 1024);
        return 'transcribed';
      });

      expect(result, 'transcribed');
      expect(await lease.file.exists(), isFalse);
      expect(lease.used, isTrue);
      expect(lease.closed, isTrue);

      await expectLater(
        () => lease.useOnce((_) async => 'second'),
        throwsStateError,
      );
    } finally {
      await f.root.delete(recursive: true);
    }
  });

  test('callback failure still deletes plaintext', () async {
    final f = await fixture();

    try {
      final lease = await f.lifecycle.createLease(
        sessionId: 'secure_audio_001',
        segmentIndex: 0,
        sealedSource: f.sealed,
      );

      await expectLater(
        () => lease.useOnce<void>((_) async {
          throw StateError('synthetic upload failure');
        }),
        throwsStateError,
      );

      expect(await lease.file.exists(), isFalse);
      expect(lease.closed, isTrue);
    } finally {
      await f.root.delete(recursive: true);
    }
  });

  test('expired lease refuses use and deletes plaintext', () async {
    final f = await fixture();

    try {
      final lease = await f.lifecycle.createLease(
        sessionId: 'secure_audio_001',
        segmentIndex: 0,
        sealedSource: f.sealed,
      );

      nowUtc = nowUtc.add(const Duration(seconds: 121));

      await expectLater(
        () => lease.useOnce((_) async => 'late'),
        throwsStateError,
      );

      expect(await lease.file.exists(), isFalse);
      expect(lease.closed, isTrue);
    } finally {
      await f.root.delete(recursive: true);
    }
  });

  test('periodic GC deletes expired managed staging only', () async {
    final f = await fixture();

    try {
      final lease = await f.lifecycle.createLease(
        sessionId: 'secure_audio_001',
        segmentIndex: 0,
        sealedSource: f.sealed,
      );

      final unknown = File(
        '${lease.file.parent.path}${Platform.pathSeparator}'
        'do_not_delete.txt',
      );
      await unknown.writeAsString('preserve', flush: true);

      nowUtc = nowUtc.add(const Duration(seconds: 121));

      final report = await f.lifecycle.collectExpiredPlaintextResidue();

      expect(report.deletedFiles, 1);
      expect(report.preservedEntries, greaterThanOrEqualTo(1));
      expect(await lease.file.exists(), isFalse);
      expect(await unknown.exists(), isTrue);
    } finally {
      await f.root.delete(recursive: true);
    }
  });

  test('crash recovery deletes fresh orphan because leases never resume',
      () async {
    final f = await fixture();

    try {
      final lease = await f.lifecycle.createLease(
        sessionId: 'secure_audio_001',
        segmentIndex: 0,
        sealedSource: f.sealed,
      );

      expect(await lease.file.exists(), isTrue);

      final report = await f.lifecycle.recoverCrashPlaintextResidue();

      expect(report.deletedFiles, 1);
      expect(await lease.file.exists(), isFalse);
    } finally {
      await f.root.delete(recursive: true);
    }
  });

  test('source contract has TTL, single use, finally delete and no HTTP',
      () async {
    final source = await File(
      'lib/services/audio/'
      'clinical_long_form_secure_plaintext_staging_lifecycle.dart',
    ).readAsString();

    expect(
      source,
      contains('maximumPlaintextLifetimeSeconds'),
    );
    expect(
      source,
      contains('plaintextLeaseSingleUseRequired = true'),
    );
    expect(source, contains('deleteInFinallyRequired = true'));
    expect(source, contains('crashRecoveryGcRequired = true'));
    expect(source, contains('broadRecursiveDeleteAllowed = false'));
    expect(source, contains('remoteTransportWiringEnabled = false'));
    expect(source, contains('remoteRealAudioEnabled = false'));
    expect(source, contains('finally'));
    expect(source, contains('Timer('));
    expect(source, isNot(contains('package:http')));
    expect(source, isNot(contains('MultipartRequest')));
    expect(source, isNot(contains('api.openai.com')));
  });

  test('production owners remain unwired to staging lifecycle', () async {
    final owners = <String>[
      'lib/services/clinical_recorder_service.dart',
      'lib/screens/clinical_recorder_sheet.dart',
      'lib/screens/history_screen.dart',
      'lib/services/audio/record_long_form_audio_provider.dart',
      'lib/services/audio/clinical_long_form_remote_batch_sandbox_provider.dart',
      'lib/services/audio/clinical_long_form_https_backend_proxy_transport.dart',
      'lib/services/audio/clinical_long_form_checkpointed_batch_runner.dart',
    ];

    for (final path in owners) {
      final source = await File(path).readAsString();
      expect(
        source,
        isNot(contains(
          'clinical_long_form_secure_plaintext_staging_lifecycle.dart',
        )),
        reason: path,
      );
      expect(
        source,
        isNot(contains(
          'ClinicalLongFormSecurePlaintextStagingLifecycle',
        )),
        reason: path,
      );
    }
  });
}
