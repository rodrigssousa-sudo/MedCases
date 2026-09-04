import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_long_form_aes_gcm_at_rest_protector.dart';
import 'package:medcases/services/audio/clinical_long_form_at_rest_key_provider.dart';
import 'package:medcases/services/audio/clinical_long_form_sensitive_at_rest_policy.dart';

final class _MemoryKeyProvider implements ClinicalLongFormAtRestKeyProvider {
  _MemoryKeyProvider(this.material);
  final ClinicalLongFormAtRestKeyMaterial material;

  @override
  Future<ClinicalLongFormAtRestKeyMaterial> currentEncryptionKey() async =>
      material;

  @override
  Future<SecretKey> keyForId(String keyId) async {
    if (keyId != material.keyId) throw StateError('Unknown key.');
    return material.secretKey;
  }
}

void main() {
  test('all local sensitive assets are no-backup and no-cloud-sync', () {
    for (final kind in ClinicalLongFormSensitiveAssetKind.values) {
      final rule = ClinicalLongFormSensitiveAtRestPolicy.ruleFor(kind);
      expect(rule.backupExcluded, isTrue, reason: kind.name);
      expect(rule.automaticCloudSyncAllowed, isFalse, reason: kind.name);
      expect(
        rule.androidStorage,
        ClinicalLongFormAndroidStorageProfile.noBackupFilesDir,
        reason: kind.name,
      );
    }
    expect(
      ClinicalLongFormSensitiveAtRestPolicy.patientIdentityAllowedInFileNames,
      isFalse,
    );
    expect(
      ClinicalLongFormSensitiveAtRestPolicy.reviewedTranscriptBackupAllowed,
      isFalse,
    );
  });

  test('active M4A is record-safe then closed M4A requires envelope', () {
    final active = ClinicalLongFormSensitiveAtRestPolicy.ruleFor(
      ClinicalLongFormSensitiveAssetKind.activeAudioSegment,
    );
    final closed = ClinicalLongFormSensitiveAtRestPolicy.ruleFor(
      ClinicalLongFormSensitiveAssetKind.closedAudioSegment,
    );

    expect(
      active.iosFileProtection,
      ClinicalLongFormIosFileProtectionProfile.completeUnlessOpen,
    );
    expect(active.applicationLayerEncryptionRequired, isFalse);
    expect(active.encryptImmediatelyAfterClose, isTrue);

    expect(
      closed.iosFileProtection,
      ClinicalLongFormIosFileProtectionProfile.complete,
    );
    expect(closed.applicationLayerEncryptionRequired, isTrue);
  });

  test('durable metadata and transcript require AES-256-GCM', () {
    for (final kind in <ClinicalLongFormSensitiveAssetKind>[
      ClinicalLongFormSensitiveAssetKind.closedAudioSegment,
      ClinicalLongFormSensitiveAssetKind.recordingManifest,
      ClinicalLongFormSensitiveAssetKind.batchQueue,
      ClinicalLongFormSensitiveAssetKind.segmentTranscriptCheckpoint,
      ClinicalLongFormSensitiveAssetKind.reviewedTranscript,
      ClinicalLongFormSensitiveAssetKind.retentionMetadata,
    ]) {
      expect(
        ClinicalLongFormSensitiveAtRestPolicy.ruleFor(kind)
            .applicationLayerEncryptionRequired,
        isTrue,
      );
    }
    expect(
      ClinicalLongFormSensitiveAtRestPolicy.applicationLayerCipher,
      'AES-256-GCM',
    );
  });

  test('transport plaintext staging is delete-required and max 120s', () {
    final r = ClinicalLongFormSensitiveAtRestPolicy.ruleFor(
      ClinicalLongFormSensitiveAssetKind.transportPlaintextStaging,
    );
    expect(r.deleteAfterUseRequired, isTrue);
    expect(r.maximumPlaintextLifetimeSeconds, 120);
  });

  test('AES-GCM round trip binds session asset and logical name', () async {
    final key = await AesGcm.with256bits().newSecretKey();
    final protector = ClinicalLongFormAesGcmAtRestProtector(
      keyProvider: _MemoryKeyProvider(
        ClinicalLongFormAtRestKeyMaterial(
          keyId: 'device-key-v1',
          secretKey: key,
        ),
      ),
    );

    final d = ClinicalLongFormSensitiveAssetDescriptor(
      sessionId: 'opaque_session_001',
      kind: ClinicalLongFormSensitiveAssetKind.reviewedTranscript,
      logicalName: 'reviewed_transcript',
    );

    final clear = utf8.encode('ceftriaxona 2 g intravenosa');
    final envelope = await protector.seal(descriptor: d, clearText: clear);

    expect(envelope.secretBoxBase64, isNot(contains('ceftriaxona')));
    final opened = await protector.open(envelope: envelope, descriptor: d);
    expect(opened, clear);

    final wrong = ClinicalLongFormSensitiveAssetDescriptor(
      sessionId: 'opaque_session_002',
      kind: ClinicalLongFormSensitiveAssetKind.reviewedTranscript,
      logicalName: 'reviewed_transcript',
    );

    await expectLater(
      () => protector.open(envelope: envelope, descriptor: wrong),
      throwsStateError,
    );
  });

  test('active recording cannot be sealed as durable envelope', () async {
    final key = await AesGcm.with256bits().newSecretKey();
    final protector = ClinicalLongFormAesGcmAtRestProtector(
      keyProvider: _MemoryKeyProvider(
        ClinicalLongFormAtRestKeyMaterial(
          keyId: 'device-key-v1',
          secretKey: key,
        ),
      ),
    );

    await expectLater(
      () => protector.seal(
        descriptor: ClinicalLongFormSensitiveAssetDescriptor(
          sessionId: 'opaque_session_001',
          kind: ClinicalLongFormSensitiveAssetKind.activeAudioSegment,
          logicalName: 'segment_00000',
        ),
        clearText: <int>[1, 2, 3],
      ),
      throwsStateError,
    );
  });

  test('key policy is device-bound and architecture remains unwired', () {
    expect(
      ClinicalLongFormAtRestKeyManagementPolicy.iosAccessibility,
      'whenUnlockedThisDeviceOnly',
    );
    expect(
      ClinicalLongFormAtRestKeyManagementPolicy.androidStore,
      'AndroidKeystore',
    );
    expect(ClinicalLongFormAtRestKeyManagementPolicy.keyExportAllowed, isFalse);
    expect(ClinicalLongFormAtRestKeyManagementPolicy.keyBackupAllowed, isFalse);
    expect(
      ClinicalLongFormAtRestKeyManagementPolicy.nativeProviderImplemented,
      isFalse,
    );

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
        isNot(contains('ClinicalLongFormAesGcmAtRestProtector')),
        reason: path,
      );
    }
  });
}
