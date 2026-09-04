import 'dart:convert';
import 'dart:io';

import 'clinical_long_form_batch_transcription_queue.dart';
import 'clinical_long_form_recording_manifest.dart';

abstract interface class ClinicalLongFormDurableStore {
  Future<void> saveManifest(
    ClinicalLongFormRecordingManifest manifest,
  );

  Future<ClinicalLongFormRecordingManifest?> loadManifest(
    String sessionId,
  );

  Future<void> saveBatchQueue(
    ClinicalLongFormBatchQueue queue,
  );

  Future<ClinicalLongFormBatchQueue?> loadBatchQueue(
    String sessionId,
  );
}

/// Store local isolado.
///
/// Não possui path_provider, singleton ou import em produção.
/// Um caller futuro deve injetar explicitamente a pasta raiz.
///
/// Cada documento usa:
/// primary -> previous-good backup -> temp write.
/// Se o primary estiver corrompido, load tenta o backup.
final class FileClinicalLongFormDurableStore
    implements ClinicalLongFormDurableStore {
  FileClinicalLongFormDurableStore({
    required Directory rootDirectory,
  }) : _rootDirectory = rootDirectory;

  static const bool productionPersistenceEnabled = false;
  static const bool cloudSyncEnabled = false;
  static const bool transcriptPersistenceEnabled = false;

  final Directory _rootDirectory;

  @override
  Future<void> saveManifest(
    ClinicalLongFormRecordingManifest manifest,
  ) async {
    await _writeDocument(
      sessionId: manifest.sessionId,
      fileName: 'manifest.json',
      json: manifest.toJson(),
    );
  }

  @override
  Future<ClinicalLongFormRecordingManifest?> loadManifest(
    String sessionId,
  ) async {
    final json = await _readDocument(
      sessionId: sessionId,
      fileName: 'manifest.json',
    );
    if (json == null) {
      return null;
    }
    return ClinicalLongFormRecordingManifest.fromJson(json);
  }

  @override
  Future<void> saveBatchQueue(
    ClinicalLongFormBatchQueue queue,
  ) async {
    await _writeDocument(
      sessionId: queue.sessionId,
      fileName: 'batch_queue.json',
      json: queue.toJson(),
    );
  }

  @override
  Future<ClinicalLongFormBatchQueue?> loadBatchQueue(
    String sessionId,
  ) async {
    final json = await _readDocument(
      sessionId: sessionId,
      fileName: 'batch_queue.json',
    );
    if (json == null) {
      return null;
    }
    return ClinicalLongFormBatchQueue.fromJson(json);
  }

  Future<void> _writeDocument({
    required String sessionId,
    required String fileName,
    required Map<String, Object?> json,
  }) async {
    final directory = await _sessionDirectory(sessionId);
    final primary = File(_join(directory.path, fileName));
    final backup = File('${primary.path}.bak');
    final temporary = File('${primary.path}.tmp');

    if (await temporary.exists()) {
      await temporary.delete();
    }

    await temporary.writeAsString(
      jsonEncode(json),
      flush: true,
    );

    if (await primary.exists()) {
      await primary.copy(backup.path);
      await primary.delete();
    }

    await temporary.rename(primary.path);
  }

  Future<Map<String, Object?>?> _readDocument({
    required String sessionId,
    required String fileName,
  }) async {
    _validateSessionId(sessionId);

    final directory = Directory(
      _join(_rootDirectory.path, sessionId),
    );
    final primary = File(_join(directory.path, fileName));
    final backup = File('${primary.path}.bak');

    final primaryJson = await _tryReadJson(primary);
    if (primaryJson != null) {
      return primaryJson;
    }

    return _tryReadJson(backup);
  }

  Future<Map<String, Object?>?> _tryReadJson(File file) async {
    if (!await file.exists()) {
      return null;
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return decoded.cast<String, Object?>();
    } on FormatException {
      return null;
    }
  }

  Future<Directory> _sessionDirectory(String sessionId) async {
    _validateSessionId(sessionId);

    if (!await _rootDirectory.exists()) {
      await _rootDirectory.create(recursive: true);
    }

    final directory = Directory(
      _join(_rootDirectory.path, sessionId),
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  static void _validateSessionId(String sessionId) {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,96}$').hasMatch(sessionId)) {
      throw ArgumentError.value(
        sessionId,
        'sessionId',
        'Unsafe durable session id.',
      );
    }
  }

  static String _join(String left, String right) {
    final separator = Platform.pathSeparator;
    if (left.endsWith(separator)) {
      return '$left$right';
    }
    return '$left$separator$right';
  }
}
