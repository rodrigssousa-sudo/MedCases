import 'dart:convert';
import 'dart:io';

import 'clinical_long_form_segment_transcript_checkpoint.dart';

abstract interface class ClinicalLongFormSegmentTranscriptCheckpointStore {
  Future<void> save(
    ClinicalLongFormSegmentTranscriptCheckpoint checkpoint,
  );

  Future<ClinicalLongFormSegmentTranscriptCheckpoint?> load(
    String sessionId,
    int segmentIndex,
  );

  Future<List<ClinicalLongFormSegmentTranscriptCheckpoint>> loadAll(
    String sessionId,
  );
}

final class FileClinicalLongFormSegmentTranscriptCheckpointStore
    implements ClinicalLongFormSegmentTranscriptCheckpointStore {
  FileClinicalLongFormSegmentTranscriptCheckpointStore({
    required Directory rootDirectory,
  }) : _rootDirectory = rootDirectory;

  static const bool productionCutoverEnabled = false;
  static const bool cloudSyncEnabled = false;
  static const bool finalReviewedArtifact = false;

  final Directory _rootDirectory;

  @override
  Future<void> save(
    ClinicalLongFormSegmentTranscriptCheckpoint checkpoint,
  ) async {
    checkpoint.validate();

    final directory = await _checkpointDirectory(
      checkpoint.sessionId,
    );
    final primary = File(
      _join(
        directory.path,
        _fileName(checkpoint.segmentIndex),
      ),
    );
    final backup = File('${primary.path}.bak');
    final temporary = File('${primary.path}.tmp');

    if (await temporary.exists()) {
      await temporary.delete();
    }

    await temporary.writeAsString(
      jsonEncode(checkpoint.toJson()),
      flush: true,
    );

    final validation = jsonDecode(
      await temporary.readAsString(),
    );
    if (validation is! Map<String, dynamic>) {
      throw const FormatException(
        'Invalid temporary segment checkpoint.',
      );
    }
    ClinicalLongFormSegmentTranscriptCheckpoint.fromJson(
      validation.cast<String, Object?>(),
    );

    if (await primary.exists()) {
      await primary.copy(backup.path);
      await primary.delete();
    }

    await temporary.rename(primary.path);
  }

  @override
  Future<ClinicalLongFormSegmentTranscriptCheckpoint?> load(
    String sessionId,
    int segmentIndex,
  ) async {
    _validateSessionId(sessionId);
    _validateSegmentIndex(segmentIndex);

    final directory = Directory(
      _join(
        _join(_rootDirectory.path, sessionId),
        'segment_transcripts',
      ),
    );

    final primary = File(
      _join(directory.path, _fileName(segmentIndex)),
    );
    final backup = File('${primary.path}.bak');

    final fromPrimary = await _tryRead(primary);
    if (fromPrimary != null) {
      _validateIdentity(
        fromPrimary,
        sessionId: sessionId,
        segmentIndex: segmentIndex,
      );
      return fromPrimary;
    }

    final fromBackup = await _tryRead(backup);
    if (fromBackup != null) {
      _validateIdentity(
        fromBackup,
        sessionId: sessionId,
        segmentIndex: segmentIndex,
      );
    }
    return fromBackup;
  }

  @override
  Future<List<ClinicalLongFormSegmentTranscriptCheckpoint>> loadAll(
    String sessionId,
  ) async {
    _validateSessionId(sessionId);

    final sessionDirectory = Directory(
      _join(_rootDirectory.path, sessionId),
    );
    final directory = Directory(
      _join(sessionDirectory.path, 'segment_transcripts'),
    );

    if (!await directory.exists()) {
      return const <ClinicalLongFormSegmentTranscriptCheckpoint>[];
    }

    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.link) {
      throw StateError('Checkpoint directory symlink is forbidden.');
    }
    if (type != FileSystemEntityType.directory) {
      throw StateError('Checkpoint path is not a directory.');
    }

    final byIndex = <int, ClinicalLongFormSegmentTranscriptCheckpoint>{};

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }

      final name =
          entity.uri.pathSegments.isEmpty ? '' : entity.uri.pathSegments.last;

      final match = RegExp(
        r'^segment_(\d{5})\.json$',
      ).firstMatch(name);

      if (match == null) {
        continue;
      }

      final segmentIndex = int.parse(match.group(1)!);
      final checkpoint = await load(sessionId, segmentIndex);
      if (checkpoint != null) {
        byIndex[segmentIndex] = checkpoint;
      }
    }

    final values = byIndex.values.toList(growable: false)
      ..sort(
        (a, b) => a.segmentIndex.compareTo(b.segmentIndex),
      );

    return values;
  }

  Future<Directory> _checkpointDirectory(
    String sessionId,
  ) async {
    _validateSessionId(sessionId);

    if (!await _rootDirectory.exists()) {
      await _rootDirectory.create(recursive: true);
    }

    final sessionDirectory = Directory(
      _join(_rootDirectory.path, sessionId),
    );
    if (!await sessionDirectory.exists()) {
      await sessionDirectory.create();
    }

    final directory = Directory(
      _join(sessionDirectory.path, 'segment_transcripts'),
    );
    if (!await directory.exists()) {
      await directory.create();
    }

    return directory;
  }

  Future<ClinicalLongFormSegmentTranscriptCheckpoint?> _tryRead(
    File file,
  ) async {
    if (!await file.exists()) {
      return null;
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return ClinicalLongFormSegmentTranscriptCheckpoint.fromJson(
        decoded.cast<String, Object?>(),
      );
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  static void _validateIdentity(
    ClinicalLongFormSegmentTranscriptCheckpoint checkpoint, {
    required String sessionId,
    required int segmentIndex,
  }) {
    if (checkpoint.sessionId != sessionId ||
        checkpoint.segmentIndex != segmentIndex) {
      throw StateError('Segment checkpoint identity mismatch.');
    }
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

  static String _fileName(int segmentIndex) {
    _validateSegmentIndex(segmentIndex);
    return 'segment_${segmentIndex.toString().padLeft(5, '0')}.json';
  }

  static String _join(String left, String right) {
    final separator = Platform.pathSeparator;
    if (left.endsWith(separator)) {
      return '$left$right';
    }
    return '$left$separator$right';
  }
}
