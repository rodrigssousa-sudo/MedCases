import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'clinical_long_form_batch_transcription_queue.dart';
import 'clinical_long_form_durable_store.dart';
import 'clinical_long_form_native_at_rest_platform_bridge.dart';
import 'clinical_long_form_recording_manifest.dart';
import 'clinical_long_form_reviewed_artifact_store.dart';
import 'clinical_long_form_reviewed_transcript_artifact.dart';
import 'clinical_long_form_segment_transcript_checkpoint.dart';
import 'clinical_long_form_segment_transcript_checkpoint_store.dart';
import 'clinical_long_form_sensitive_at_rest_policy.dart';

final class NativeSecureClinicalLongFormDurableStore
    implements ClinicalLongFormDurableStore {
  NativeSecureClinicalLongFormDurableStore({
    required Directory rootDirectory,
    required ClinicalLongFormNativeAtRestPlatformBridge bridge,
    required String keyId,
  }) : _documents = _NativeSecureJsonDocuments(
          rootDirectory: rootDirectory,
          bridge: bridge,
          keyId: keyId,
        );

  static const bool productionPersistenceIntegrationEnabled = false;
  static const bool productionCutoverEnabled = false;
  static const bool plaintextJsonAtRestAllowed = false;

  final _NativeSecureJsonDocuments _documents;

  @override
  Future<void> saveManifest(
    ClinicalLongFormRecordingManifest manifest,
  ) {
    return _documents.write(
      sessionId: manifest.sessionId,
      fileName: 'manifest.json',
      descriptor: ClinicalLongFormSensitiveAssetDescriptor(
        sessionId: manifest.sessionId,
        kind: ClinicalLongFormSensitiveAssetKind.recordingManifest,
        logicalName: 'manifest',
      ),
      json: manifest.toJson(),
    );
  }

  @override
  Future<ClinicalLongFormRecordingManifest?> loadManifest(
    String sessionId,
  ) async {
    final json = await _documents.read(
      sessionId: sessionId,
      fileName: 'manifest.json',
      descriptor: ClinicalLongFormSensitiveAssetDescriptor(
        sessionId: sessionId,
        kind: ClinicalLongFormSensitiveAssetKind.recordingManifest,
        logicalName: 'manifest',
      ),
    );

    if (json == null) {
      return null;
    }
    return ClinicalLongFormRecordingManifest.fromJson(json);
  }

  @override
  Future<void> saveBatchQueue(
    ClinicalLongFormBatchQueue queue,
  ) {
    return _documents.write(
      sessionId: queue.sessionId,
      fileName: 'batch_queue.json',
      descriptor: ClinicalLongFormSensitiveAssetDescriptor(
        sessionId: queue.sessionId,
        kind: ClinicalLongFormSensitiveAssetKind.batchQueue,
        logicalName: 'batch_queue',
      ),
      json: queue.toJson(),
    );
  }

  @override
  Future<ClinicalLongFormBatchQueue?> loadBatchQueue(
    String sessionId,
  ) async {
    final json = await _documents.read(
      sessionId: sessionId,
      fileName: 'batch_queue.json',
      descriptor: ClinicalLongFormSensitiveAssetDescriptor(
        sessionId: sessionId,
        kind: ClinicalLongFormSensitiveAssetKind.batchQueue,
        logicalName: 'batch_queue',
      ),
    );

    if (json == null) {
      return null;
    }
    return ClinicalLongFormBatchQueue.fromJson(json);
  }
}

final class NativeSecureClinicalLongFormSegmentTranscriptCheckpointStore
    implements ClinicalLongFormSegmentTranscriptCheckpointStore {
  NativeSecureClinicalLongFormSegmentTranscriptCheckpointStore({
    required Directory rootDirectory,
    required ClinicalLongFormNativeAtRestPlatformBridge bridge,
    required String keyId,
  })  : _rootDirectory = rootDirectory,
        _documents = _NativeSecureJsonDocuments(
          rootDirectory: rootDirectory,
          bridge: bridge,
          keyId: keyId,
        );

  static const bool productionPersistenceIntegrationEnabled = false;
  static const bool productionCutoverEnabled = false;
  static const bool plaintextTranscriptAtRestAllowed = false;

  final Directory _rootDirectory;
  final _NativeSecureJsonDocuments _documents;

  @override
  Future<void> save(
    ClinicalLongFormSegmentTranscriptCheckpoint checkpoint,
  ) {
    checkpoint.validate();

    return _documents.write(
      sessionId: checkpoint.sessionId,
      relativeDirectory: 'segment_transcripts',
      fileName: _fileName(checkpoint.segmentIndex),
      descriptor: ClinicalLongFormSensitiveAssetDescriptor(
        sessionId: checkpoint.sessionId,
        kind: ClinicalLongFormSensitiveAssetKind.segmentTranscriptCheckpoint,
        logicalName: _logicalName(checkpoint.segmentIndex),
      ),
      json: checkpoint.toJson(),
    );
  }

  @override
  Future<ClinicalLongFormSegmentTranscriptCheckpoint?> load(
    String sessionId,
    int segmentIndex,
  ) async {
    _validateSessionId(sessionId);
    _validateSegmentIndex(segmentIndex);

    final json = await _documents.read(
      sessionId: sessionId,
      relativeDirectory: 'segment_transcripts',
      fileName: _fileName(segmentIndex),
      descriptor: ClinicalLongFormSensitiveAssetDescriptor(
        sessionId: sessionId,
        kind: ClinicalLongFormSensitiveAssetKind.segmentTranscriptCheckpoint,
        logicalName: _logicalName(segmentIndex),
      ),
    );

    if (json == null) {
      return null;
    }

    final checkpoint =
        ClinicalLongFormSegmentTranscriptCheckpoint.fromJson(json);

    if (checkpoint.sessionId != sessionId ||
        checkpoint.segmentIndex != segmentIndex) {
      throw StateError('Secure checkpoint identity mismatch.');
    }

    return checkpoint;
  }

  @override
  Future<List<ClinicalLongFormSegmentTranscriptCheckpoint>> loadAll(
    String sessionId,
  ) async {
    _validateSessionId(sessionId);

    final directory = Directory(
      _join(
        _join(_rootDirectory.path, sessionId),
        'segment_transcripts',
      ),
    );

    if (!await directory.exists()) {
      return const <ClinicalLongFormSegmentTranscriptCheckpoint>[];
    }

    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.link) {
      throw StateError('Secure checkpoint directory symlink is forbidden.');
    }
    if (type != FileSystemEntityType.directory) {
      throw StateError('Secure checkpoint path is not a directory.');
    }

    final checkpoints = <ClinicalLongFormSegmentTranscriptCheckpoint>[];

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }

      final name =
          entity.uri.pathSegments.isEmpty ? '' : entity.uri.pathSegments.last;
      final match = RegExp(r'^segment_(\d{5})\.json$').firstMatch(name);
      if (match == null) {
        continue;
      }

      final checkpoint = await load(
        sessionId,
        int.parse(match.group(1)!),
      );
      if (checkpoint != null) {
        checkpoints.add(checkpoint);
      }
    }

    checkpoints.sort(
      (a, b) => a.segmentIndex.compareTo(b.segmentIndex),
    );
    return List<ClinicalLongFormSegmentTranscriptCheckpoint>.unmodifiable(
      checkpoints,
    );
  }

  static String _fileName(int index) {
    _validateSegmentIndex(index);
    return 'segment_${index.toString().padLeft(5, '0')}.json';
  }

  static String _logicalName(int index) {
    _validateSegmentIndex(index);
    return 'segment_${index.toString().padLeft(5, '0')}_transcript';
  }

  static void _validateSessionId(String sessionId) {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,96}$').hasMatch(sessionId)) {
      throw ArgumentError.value(sessionId, 'sessionId');
    }
  }

  static void _validateSegmentIndex(int segmentIndex) {
    if (segmentIndex < 0 || segmentIndex > 99999) {
      throw ArgumentError.value(segmentIndex, 'segmentIndex');
    }
  }
}

final class NativeSecureClinicalLongFormReviewedArtifactStore
    implements ClinicalLongFormReviewedArtifactStore {
  NativeSecureClinicalLongFormReviewedArtifactStore({
    required Directory rootDirectory,
    required ClinicalLongFormNativeAtRestPlatformBridge bridge,
    required String keyId,
  }) : _documents = _NativeSecureJsonDocuments(
          rootDirectory: rootDirectory,
          bridge: bridge,
          keyId: keyId,
        );

  static const bool productionPersistenceIntegrationEnabled = false;
  static const bool productionCutoverEnabled = false;
  static const bool plaintextReviewedTranscriptAtRestAllowed = false;

  final _NativeSecureJsonDocuments _documents;

  @override
  Future<void> save(
    ClinicalLongFormReviewedTranscriptArtifact artifact,
  ) {
    artifact.validate();

    return _documents.write(
      sessionId: artifact.sessionId,
      fileName: 'reviewed_transcript.json',
      descriptor: ClinicalLongFormSensitiveAssetDescriptor(
        sessionId: artifact.sessionId,
        kind: ClinicalLongFormSensitiveAssetKind.reviewedTranscript,
        logicalName: 'reviewed_transcript',
      ),
      json: artifact.toJson(),
    );
  }

  @override
  Future<ClinicalLongFormReviewedTranscriptArtifact?> load(
    String sessionId,
  ) async {
    final json = await _documents.read(
      sessionId: sessionId,
      fileName: 'reviewed_transcript.json',
      descriptor: ClinicalLongFormSensitiveAssetDescriptor(
        sessionId: sessionId,
        kind: ClinicalLongFormSensitiveAssetKind.reviewedTranscript,
        logicalName: 'reviewed_transcript',
      ),
    );

    if (json == null) {
      return null;
    }
    return ClinicalLongFormReviewedTranscriptArtifact.fromJson(json);
  }
}

final class NativeSecureClinicalLongFormClosedAudioAdapter {
  NativeSecureClinicalLongFormClosedAudioAdapter({
    required ClinicalLongFormNativeAtRestPlatformBridge bridge,
    required String keyId,
  })  : _bridge = bridge,
        _keyId = keyId {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,64}$').hasMatch(keyId)) {
      throw ArgumentError.value(keyId, 'keyId');
    }
  }

  static const bool productionPersistenceIntegrationEnabled = false;
  static const bool productionCutoverEnabled = false;
  static const bool plaintextSourceAutoDeleteEnabled = false;
  static const bool remoteTransportWiringEnabled = false;
  static const int plaintextStagingMaximumLifetimeSeconds =
      ClinicalLongFormSensitiveAtRestPolicy
          .transportPlaintextMaximumLifetimeSeconds;

  final ClinicalLongFormNativeAtRestPlatformBridge _bridge;
  final String _keyId;

  Future<ClinicalLongFormNativeFileCryptoResult> sealClosedSegment({
    required String sessionId,
    required int segmentIndex,
    required File clearM4a,
    required File sealedDestination,
  }) async {
    _validateSegmentIndex(segmentIndex);
    if (!clearM4a.path.toLowerCase().endsWith('.m4a')) {
      throw ArgumentError.value(clearM4a.path, 'clearM4a');
    }
    if (!sealedDestination.path.toLowerCase().endsWith('.m4a.sealed')) {
      throw ArgumentError.value(
        sealedDestination.path,
        'sealedDestination',
      );
    }

    await _requireExistingRegularFile(clearM4a);
    await _requireMissingDestination(sealedDestination);
    await _bridge.protectDurableFile(clearM4a.path);

    return _bridge.sealFile(
      keyId: _keyId,
      descriptor: _descriptor(
        sessionId: sessionId,
        segmentIndex: segmentIndex,
      ),
      sourcePath: clearM4a.path,
      destinationPath: sealedDestination.path,
    );
  }

  Future<ClinicalLongFormNativeFileCryptoResult> openToPlaintextStaging({
    required String sessionId,
    required int segmentIndex,
    required File sealedSource,
    required File stagingM4a,
  }) async {
    _validateSegmentIndex(segmentIndex);
    if (!sealedSource.path.toLowerCase().endsWith('.m4a.sealed')) {
      throw ArgumentError.value(sealedSource.path, 'sealedSource');
    }
    if (!stagingM4a.path.toLowerCase().endsWith('.m4a')) {
      throw ArgumentError.value(stagingM4a.path, 'stagingM4a');
    }

    await _requireExistingRegularFile(sealedSource);
    await _requireMissingDestination(stagingM4a);

    return _bridge.openFile(
      keyId: _keyId,
      descriptor: _descriptor(
        sessionId: sessionId,
        segmentIndex: segmentIndex,
      ),
      sourcePath: sealedSource.path,
      destinationPath: stagingM4a.path,
    );
  }

  static Future<void> _requireExistingRegularFile(File file) async {
    final type = await FileSystemEntity.type(
      file.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.link) {
      throw StateError('Closed audio symlink is forbidden.');
    }
    if (type != FileSystemEntityType.file) {
      throw StateError('Closed audio source must be a regular file.');
    }
  }

  static Future<void> _requireMissingDestination(File file) async {
    final type = await FileSystemEntity.type(
      file.path,
      followLinks: false,
    );
    if (type != FileSystemEntityType.notFound) {
      throw StateError('Closed audio destination must not exist.');
    }

    final parent = file.parent;
    final parentType = await FileSystemEntity.type(
      parent.path,
      followLinks: false,
    );
    if (parentType == FileSystemEntityType.link) {
      throw StateError('Closed audio destination parent symlink forbidden.');
    }
    if (parentType != FileSystemEntityType.directory) {
      throw StateError('Closed audio destination parent must exist.');
    }
  }

  static ClinicalLongFormSensitiveAssetDescriptor _descriptor({
    required String sessionId,
    required int segmentIndex,
  }) {
    return ClinicalLongFormSensitiveAssetDescriptor(
      sessionId: sessionId,
      kind: ClinicalLongFormSensitiveAssetKind.closedAudioSegment,
      logicalName: 'segment_${segmentIndex.toString().padLeft(5, '0')}_m4a',
    );
  }

  static void _validateSegmentIndex(int index) {
    if (index < 0 || index > 99999) {
      throw ArgumentError.value(index, 'segmentIndex');
    }
  }
}

final class _NativeSecureJsonDocuments {
  _NativeSecureJsonDocuments({
    required Directory rootDirectory,
    required ClinicalLongFormNativeAtRestPlatformBridge bridge,
    required String keyId,
  })  : _rootDirectory = rootDirectory,
        _bridge = bridge,
        _keyId = keyId {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,64}$').hasMatch(keyId)) {
      throw ArgumentError.value(keyId, 'keyId');
    }
  }

  final Directory _rootDirectory;
  final ClinicalLongFormNativeAtRestPlatformBridge _bridge;
  final String _keyId;

  Future<void> write({
    required String sessionId,
    required String fileName,
    required ClinicalLongFormSensitiveAssetDescriptor descriptor,
    required Map<String, Object?> json,
    String? relativeDirectory,
  }) async {
    _validateSessionId(sessionId);
    _validateFileName(fileName);
    _validateDescriptor(descriptor, sessionId: sessionId);

    final directory = await _ensureDirectory(
      sessionId: sessionId,
      relativeDirectory: relativeDirectory,
    );
    final primary = File(_join(directory.path, fileName));
    final backup = File('${primary.path}.bak');
    final temporary = File('${primary.path}.tmp');

    await _requireRegularOrMissing(primary);
    await _requireRegularOrMissing(backup);
    await _requireRegularOrMissing(temporary);

    if (await temporary.exists()) {
      await temporary.delete();
    }

    final clear = Uint8List.fromList(
      utf8.encode(jsonEncode(json)),
    );
    final sealed = await _bridge.seal(
      keyId: _keyId,
      descriptor: descriptor,
      clearText: clear,
    );

    try {
      await temporary.writeAsBytes(
        sealed,
        flush: true,
      );
      await _bridge.protectDurableFile(temporary.path);

      final validation = await _decodeEncryptedJson(
        temporary,
        descriptor: descriptor,
      );
      if (validation == null) {
        throw const FormatException(
          'Secure temporary document validation failed.',
        );
      }

      if (await primary.exists()) {
        final currentCiphertext = await primary.readAsBytes();
        await backup.writeAsBytes(
          currentCiphertext,
          flush: true,
        );
        await _bridge.protectDurableFile(backup.path);
        await primary.delete();
      }

      await temporary.rename(primary.path);
      await _bridge.protectDurableFile(primary.path);
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }

  Future<Map<String, Object?>?> read({
    required String sessionId,
    required String fileName,
    required ClinicalLongFormSensitiveAssetDescriptor descriptor,
    String? relativeDirectory,
  }) async {
    _validateSessionId(sessionId);
    _validateFileName(fileName);
    _validateDescriptor(descriptor, sessionId: sessionId);

    final directory = _directory(
      sessionId: sessionId,
      relativeDirectory: relativeDirectory,
    );
    final primary = File(_join(directory.path, fileName));
    final backup = File('${primary.path}.bak');

    final fromPrimary = await _decodeEncryptedJson(
      primary,
      descriptor: descriptor,
    );
    if (fromPrimary != null) {
      return fromPrimary;
    }

    return _decodeEncryptedJson(
      backup,
      descriptor: descriptor,
    );
  }

  Future<Map<String, Object?>?> _decodeEncryptedJson(
    File file, {
    required ClinicalLongFormSensitiveAssetDescriptor descriptor,
  }) async {
    if (!await file.exists()) {
      return null;
    }

    final type = await FileSystemEntity.type(
      file.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.link) {
      throw StateError('Secure document symlink is forbidden.');
    }
    if (type != FileSystemEntityType.file) {
      throw StateError('Secure document path is not a regular file.');
    }

    try {
      final sealed = await file.readAsBytes();
      final clear = await _bridge.open(
        keyId: _keyId,
        descriptor: descriptor,
        sealedData: sealed,
      );
      final decoded = jsonDecode(utf8.decode(clear));
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return decoded.cast<String, Object?>();
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<Directory> _ensureDirectory({
    required String sessionId,
    String? relativeDirectory,
  }) async {
    if (!await _rootDirectory.exists()) {
      await _rootDirectory.create(recursive: true);
    } else {
      final rootType = await FileSystemEntity.type(
        _rootDirectory.path,
        followLinks: false,
      );
      if (rootType == FileSystemEntityType.link) {
        throw StateError('Secure root symlink is forbidden.');
      }
      if (rootType != FileSystemEntityType.directory) {
        throw StateError('Secure root path is not a directory.');
      }
    }

    final sessionDirectory = Directory(
      _join(_rootDirectory.path, sessionId),
    );
    if (!await sessionDirectory.exists()) {
      await sessionDirectory.create();
    } else {
      final sessionType = await FileSystemEntity.type(
        sessionDirectory.path,
        followLinks: false,
      );
      if (sessionType == FileSystemEntityType.link) {
        throw StateError('Secure session directory symlink is forbidden.');
      }
      if (sessionType != FileSystemEntityType.directory) {
        throw StateError('Secure session path is not a directory.');
      }
    }

    if (relativeDirectory == null) {
      return sessionDirectory;
    }

    _validateRelativeDirectory(relativeDirectory);
    final nested = Directory(
      _join(sessionDirectory.path, relativeDirectory),
    );
    if (!await nested.exists()) {
      await nested.create();
    } else {
      final nestedType = await FileSystemEntity.type(
        nested.path,
        followLinks: false,
      );
      if (nestedType == FileSystemEntityType.link) {
        throw StateError('Secure nested directory symlink is forbidden.');
      }
      if (nestedType != FileSystemEntityType.directory) {
        throw StateError('Secure nested path is not a directory.');
      }
    }

    return nested;
  }

  Directory _directory({
    required String sessionId,
    String? relativeDirectory,
  }) {
    final sessionDirectory = Directory(
      _join(_rootDirectory.path, sessionId),
    );

    if (relativeDirectory == null) {
      return sessionDirectory;
    }

    _validateRelativeDirectory(relativeDirectory);
    return Directory(
      _join(sessionDirectory.path, relativeDirectory),
    );
  }

  static Future<void> _requireRegularOrMissing(File file) async {
    final type = await FileSystemEntity.type(
      file.path,
      followLinks: false,
    );

    if (type == FileSystemEntityType.notFound) {
      return;
    }
    if (type == FileSystemEntityType.link) {
      throw StateError('Secure document symlink is forbidden.');
    }
    if (type != FileSystemEntityType.file) {
      throw StateError('Secure document target is not a regular file.');
    }
  }

  static void _validateDescriptor(
    ClinicalLongFormSensitiveAssetDescriptor descriptor, {
    required String sessionId,
  }) {
    if (descriptor.sessionId != sessionId) {
      throw StateError('Secure descriptor/session mismatch.');
    }

    final rule = ClinicalLongFormSensitiveAtRestPolicy.ruleFor(
      descriptor.kind,
    );
    if (!rule.applicationLayerEncryptionRequired) {
      throw StateError('Secure JSON requires encrypted asset kind.');
    }
  }

  static void _validateSessionId(String sessionId) {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,96}$').hasMatch(sessionId)) {
      throw ArgumentError.value(sessionId, 'sessionId');
    }
  }

  static void _validateFileName(String fileName) {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,128}$').hasMatch(fileName)) {
      throw ArgumentError.value(fileName, 'fileName');
    }
  }

  static void _validateRelativeDirectory(String directory) {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,96}$').hasMatch(directory)) {
      throw ArgumentError.value(directory, 'relativeDirectory');
    }
  }
}

String _join(String left, String right) {
  final separator = Platform.pathSeparator;
  if (left.endsWith(separator)) {
    return '$left$right';
  }
  return '$left$separator$right';
}
