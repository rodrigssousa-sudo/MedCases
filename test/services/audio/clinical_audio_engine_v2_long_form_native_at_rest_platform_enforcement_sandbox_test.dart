import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_long_form_native_at_rest_platform_bridge.dart';
import 'package:medcases/services/audio/clinical_long_form_sensitive_at_rest_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    ClinicalLongFormNativeAtRestPlatformBridge.channelName,
  );

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('bridge capabilities reject key export or production integration',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (call) async => <String, Object?>{
        'platform': 'ios',
        'secureRootKind': 'applicationSupportNoBackup',
        'keyStore': 'Keychain',
        'cipher': 'AES-256-GCM',
        'keyExportToFlutter': false,
        'productionIntegrationEnabled': false,
      },
    );

    final bridge = ClinicalLongFormNativeAtRestPlatformBridge();
    final capabilities = await bridge.capabilities();

    expect(capabilities.cipher, 'AES-256-GCM');
    expect(capabilities.keyExportToFlutter, isFalse);
    expect(capabilities.productionIntegrationEnabled, isFalse);
  });

  test('bridge sends bounded identity and bytes but never asks for key export',
      () async {
    final calls = <MethodCall>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (call) async {
        calls.add(call);

        if (call.method == 'seal') {
          return Uint8List.fromList(
            List<int>.filled(29, 7),
          );
        }

        if (call.method == 'open') {
          return Uint8List.fromList(<int>[1, 2, 3]);
        }

        return null;
      },
    );

    final bridge = ClinicalLongFormNativeAtRestPlatformBridge();
    final descriptor = ClinicalLongFormSensitiveAssetDescriptor(
      sessionId: 'opaque_session_001',
      kind: ClinicalLongFormSensitiveAssetKind.reviewedTranscript,
      logicalName: 'reviewed_transcript',
    );

    final sealed = await bridge.seal(
      keyId: 'device-key-v1',
      descriptor: descriptor,
      clearText: Uint8List.fromList(<int>[1, 2, 3]),
    );

    expect(sealed, hasLength(29));

    final clear = await bridge.open(
      keyId: 'device-key-v1',
      descriptor: descriptor,
      sealedData: sealed,
    );

    expect(clear, <int>[1, 2, 3]);
    expect(
      calls.map((call) => call.method),
      isNot(contains('exportKey')),
    );

    final sealArgs = calls.firstWhere((call) => call.method == 'seal').arguments
        as Map<Object?, Object?>;

    expect(sealArgs['keyId'], 'device-key-v1');
    expect(sealArgs['sessionId'], 'opaque_session_001');
    expect(sealArgs['assetKind'], 'reviewedTranscript');
    expect(sealArgs['logicalName'], 'reviewed_transcript');
  });

  test('active audio is rejected from durable native sealing', () async {
    final bridge = ClinicalLongFormNativeAtRestPlatformBridge();

    await expectLater(
      () => bridge.seal(
        keyId: 'device-key-v1',
        descriptor: ClinicalLongFormSensitiveAssetDescriptor(
          sessionId: 'opaque_session_001',
          kind: ClinicalLongFormSensitiveAssetKind.activeAudioSegment,
          logicalName: 'segment_00000',
        ),
        clearText: Uint8List.fromList(<int>[1, 2, 3]),
      ),
      throwsStateError,
    );
  });

  test('native source implements platform security without production wiring',
      () {
    final ios = File(
      'ios/Runner/AppDelegate.swift',
    ).readAsStringSync();

    final android = File(
      'android/app/src/main/kotlin/'
      'com/medcasespro/med/MainActivity.kt',
    ).readAsStringSync();

    final bridge = File(
      'lib/services/audio/'
      'clinical_long_form_native_at_rest_platform_bridge.dart',
    ).readAsStringSync();

    expect(
      ios,
      contains('medcases/audio_at_rest_v2'),
    );
    expect(
      ios,
      contains('FileProtectionType.completeUnlessOpen'),
    );
    expect(
      ios,
      contains('FileProtectionType.complete'),
    );
    expect(
      ios,
      contains('values.isExcludedFromBackup = true'),
    );
    expect(
      ios,
      contains('kSecAttrAccessibleWhenUnlockedThisDeviceOnly'),
    );
    expect(
      ios,
      contains('AES.GCM.seal'),
    );
    expect(
      ios,
      contains('AES.GCM.open'),
    );

    expect(
      android,
      contains('noBackupFilesDir'),
    );
    expect(
      android,
      contains('"AndroidKeyStore"'),
    );
    expect(
      android,
      contains('"AES/GCM/NoPadding"'),
    );
    expect(
      android,
      contains('KeyGenParameterSpec.Builder'),
    );

    expect(
      bridge,
      contains('keyMaterialMayCrossIntoFlutter = false'),
    );
    expect(
      bridge,
      contains('productionPersistenceIntegrationEnabled = false'),
    );
    expect(
      bridge,
      contains('productionCutoverEnabled = false'),
    );

    for (final forbidden in <String>[
      'OPENAI_API_KEY',
      'api.openai.com',
      'sk-',
      'exportKey',
      'getRawKey',
      'privateKeyBytes',
    ]) {
      expect(
        '$ios\n$android\n$bridge',
        isNot(contains(forbidden)),
        reason: forbidden,
      );
    }

    for (final path in <String>[
      'lib/services/audio/clinical_long_form_durable_store.dart',
      'lib/services/audio/'
          'clinical_long_form_segment_transcript_checkpoint_store.dart',
      'lib/services/audio/clinical_long_form_reviewed_artifact_store.dart',
      'lib/services/audio/record_long_form_audio_provider.dart',
      'lib/main.dart',
      'lib/services/clinical_recorder_service.dart',
      'lib/screens/history_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('ClinicalLongFormNativeAtRestPlatformBridge')),
        reason: path,
      );
    }
  });
}
