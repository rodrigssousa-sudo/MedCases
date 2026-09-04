import 'dart:io';

import 'clinical_long_form_reviewed_transcript_artifact.dart';
import 'clinical_long_form_session_directory_layout.dart';

final class ClinicalLongFormGarbageCollectionReport {
  const ClinicalLongFormGarbageCollectionReport({
    required this.deletedFiles,
    required this.alreadyMissingFiles,
    required this.preservedFiles,
  });

  final int deletedFiles;
  final int alreadyMissingFiles;
  final int preservedFiles;

  ClinicalLongFormGarbageCollectionReport add(
    ClinicalLongFormGarbageCollectionReport other,
  ) {
    return ClinicalLongFormGarbageCollectionReport(
      deletedFiles: deletedFiles + other.deletedFiles,
      alreadyMissingFiles: alreadyMissingFiles + other.alreadyMissingFiles,
      preservedFiles: preservedFiles + other.preservedFiles,
    );
  }
}

final class ClinicalLongFormSessionGarbageCollector {
  ClinicalLongFormSessionGarbageCollector({
    required ClinicalLongFormSessionDirectoryLayout layout,
  }) : _layout = layout;

  static const bool productionCutoverEnabled = false;
  static const bool broadRecursiveDeleteAllowed = false;
  static const bool reviewedArtifactDeletionAllowed = false;
  static const bool checkpointGcBeforeFinalRetentionAllowed = false;

  final ClinicalLongFormSessionDirectoryLayout _layout;

  Future<ClinicalLongFormGarbageCollectionReport> collect({
    required ClinicalLongFormReviewedTranscriptArtifact artifact,
  }) async {
    if (artifact.sessionId != _layout.sessionId) {
      throw StateError('Artifact/session layout mismatch.');
    }

    switch (artifact.retentionState) {
      case ClinicalLongFormAudioRetentionState.keepAudio:
        return _cleanupFinalizedKeepAudio();
      case ClinicalLongFormAudioRetentionState.audioDeleted:
        return _cleanupFinalizedDeletedSession();
      case ClinicalLongFormAudioRetentionState.reviewedPersisted:
      case ClinicalLongFormAudioRetentionState.deletePending:
      case ClinicalLongFormAudioRetentionState.deletionFailed:
        return _cleanupTemporaryResidueOnly();
    }
  }

  Future<ClinicalLongFormGarbageCollectionReport>
      _cleanupTemporaryResidueOnly() async {
    final candidates = <File>[
      _layout.manifestTempFile,
      _layout.batchQueueTempFile,
      _layout.reviewedTranscriptTempFile,
    ];

    return _deleteKnownFiles(
      candidates,
      preservedFiles: 2,
    );
  }

  Future<ClinicalLongFormGarbageCollectionReport>
      _cleanupFinalizedKeepAudio() async {
    final base = await _deleteKnownFiles(
      <File>[
        _layout.manifestTempFile,
        _layout.batchQueueTempFile,
        _layout.reviewedTranscriptTempFile,
      ],
      preservedFiles: 2,
    );

    final checkpoints = await _cleanupFinalizedSegmentTranscriptCheckpoints();

    return base.add(checkpoints);
  }

  Future<ClinicalLongFormGarbageCollectionReport>
      _cleanupFinalizedDeletedSession() async {
    final base = await _deleteKnownFiles(
      <File>[
        _layout.manifestFile,
        _layout.manifestBackupFile,
        _layout.manifestTempFile,
        _layout.batchQueueFile,
        _layout.batchQueueBackupFile,
        _layout.batchQueueTempFile,
        _layout.reviewedTranscriptTempFile,
      ],
      preservedFiles: 2,
    );

    final checkpoints = await _cleanupFinalizedSegmentTranscriptCheckpoints();

    await _deleteDirectoryIfEmpty(_layout.audioDirectory);

    return base.add(checkpoints);
  }

  Future<ClinicalLongFormGarbageCollectionReport>
      _cleanupFinalizedSegmentTranscriptCheckpoints() async {
    final directory = Directory(
      '${_layout.sessionDirectory.path}'
      '${Platform.pathSeparator}segment_transcripts',
    );

    if (!await directory.exists()) {
      return const ClinicalLongFormGarbageCollectionReport(
        deletedFiles: 0,
        alreadyMissingFiles: 0,
        preservedFiles: 0,
      );
    }

    final directoryType = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );

    if (directoryType == FileSystemEntityType.link) {
      throw StateError(
        'Segment transcript checkpoint directory symlink is forbidden.',
      );
    }
    if (directoryType != FileSystemEntityType.directory) {
      throw StateError(
        'Segment transcript checkpoint path is not a directory.',
      );
    }

    final resolvedSession =
        await _layout.sessionDirectory.resolveSymbolicLinks();
    final sessionPrefix = _withTrailingSeparator(resolvedSession);
    final resolvedDirectory = await directory.resolveSymbolicLinks();

    if (!resolvedDirectory.startsWith(sessionPrefix)) {
      throw StateError(
        'Segment transcript checkpoint directory escapes session.',
      );
    }

    var deleted = 0;
    var preserved = 0;

    await for (final entity in directory.list(followLinks: false)) {
      final type = await FileSystemEntity.type(
        entity.path,
        followLinks: false,
      );

      if (type == FileSystemEntityType.link) {
        throw StateError(
          'Garbage collector will not delete checkpoint symlinks.',
        );
      }

      if (type != FileSystemEntityType.file) {
        preserved++;
        continue;
      }

      final name =
          entity.uri.pathSegments.isEmpty ? '' : entity.uri.pathSegments.last;

      final allowed = RegExp(
        r'^segment_\d{5}\.json(?:\.bak|\.tmp)?$',
      ).hasMatch(name);

      if (!allowed) {
        preserved++;
        continue;
      }

      final resolved = await File(entity.path).resolveSymbolicLinks();
      if (!resolved.startsWith(
        _withTrailingSeparator(resolvedDirectory),
      )) {
        throw StateError('Checkpoint GC target escapes directory.');
      }

      await File(entity.path).delete();
      deleted++;
    }

    await _deleteDirectoryIfEmpty(directory);

    return ClinicalLongFormGarbageCollectionReport(
      deletedFiles: deleted,
      alreadyMissingFiles: 0,
      preservedFiles: preserved,
    );
  }

  Future<ClinicalLongFormGarbageCollectionReport> _deleteKnownFiles(
    List<File> candidates, {
    required int preservedFiles,
  }) async {
    final sessionDirectory = _layout.sessionDirectory;

    if (!await sessionDirectory.exists()) {
      return ClinicalLongFormGarbageCollectionReport(
        deletedFiles: 0,
        alreadyMissingFiles: candidates.length,
        preservedFiles: preservedFiles,
      );
    }

    final sessionType = await FileSystemEntity.type(
      sessionDirectory.path,
      followLinks: false,
    );

    if (sessionType == FileSystemEntityType.link) {
      throw StateError('Session directory symlink is forbidden.');
    }
    if (sessionType != FileSystemEntityType.directory) {
      throw StateError('Session path is not a directory.');
    }

    final resolvedSession = await sessionDirectory.resolveSymbolicLinks();
    final sessionPrefix = _withTrailingSeparator(resolvedSession);

    final protected = _layout.protectedReviewedArtifactPaths.toSet();

    var deleted = 0;
    var missing = 0;

    for (final candidate in candidates) {
      if (protected.contains(candidate.path)) {
        throw StateError('Reviewed artifact cannot be garbage collected.');
      }

      if (!await candidate.exists()) {
        missing++;
        continue;
      }

      final type = await FileSystemEntity.type(
        candidate.path,
        followLinks: false,
      );

      if (type == FileSystemEntityType.link) {
        throw StateError('Garbage collector will not delete symlinks.');
      }
      if (type != FileSystemEntityType.file) {
        throw StateError('GC target is not a regular file.');
      }

      final resolved = await candidate.resolveSymbolicLinks();
      if (!resolved.startsWith(sessionPrefix)) {
        throw StateError('GC target escapes session directory.');
      }

      await candidate.delete();
      deleted++;
    }

    return ClinicalLongFormGarbageCollectionReport(
      deletedFiles: deleted,
      alreadyMissingFiles: missing,
      preservedFiles: preservedFiles,
    );
  }

  Future<void> _deleteDirectoryIfEmpty(Directory directory) async {
    if (!await directory.exists()) {
      return;
    }

    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );

    if (type == FileSystemEntityType.link) {
      throw StateError('GC will not delete directory symlinks.');
    }
    if (type != FileSystemEntityType.directory) {
      return;
    }

    final entries = await directory.list(followLinks: false).toList();

    if (entries.isEmpty) {
      await directory.delete();
    }
  }

  static String _withTrailingSeparator(String path) {
    final separator = Platform.pathSeparator;
    return path.endsWith(separator) ? path : '$path$separator';
  }
}
