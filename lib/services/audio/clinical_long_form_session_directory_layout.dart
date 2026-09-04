import 'dart:io';

final class ClinicalLongFormSessionDirectoryLayout {
  ClinicalLongFormSessionDirectoryLayout({
    required Directory rootDirectory,
    required String sessionId,
  })  : _rootDirectory = rootDirectory,
        sessionId = sessionId.trim() {
    _validateSessionId(this.sessionId);
  }

  final Directory _rootDirectory;
  final String sessionId;

  Directory get sessionDirectory => Directory(
        _join(_rootDirectory.path, sessionId),
      );

  Directory get audioDirectory => Directory(
        _join(sessionDirectory.path, 'audio'),
      );

  File get manifestFile => File(
        _join(sessionDirectory.path, 'manifest.json'),
      );

  File get manifestBackupFile => File('${manifestFile.path}.bak');
  File get manifestTempFile => File('${manifestFile.path}.tmp');

  File get batchQueueFile => File(
        _join(sessionDirectory.path, 'batch_queue.json'),
      );

  File get batchQueueBackupFile => File('${batchQueueFile.path}.bak');
  File get batchQueueTempFile => File('${batchQueueFile.path}.tmp');

  File get reviewedTranscriptFile => File(
        _join(sessionDirectory.path, 'reviewed_transcript.json'),
      );

  File get reviewedTranscriptBackupFile =>
      File('${reviewedTranscriptFile.path}.bak');

  File get reviewedTranscriptTempFile =>
      File('${reviewedTranscriptFile.path}.tmp');

  Future<void> ensureDirectories() async {
    if (!await _rootDirectory.exists()) {
      await _rootDirectory.create(recursive: true);
    }
    if (!await sessionDirectory.exists()) {
      await sessionDirectory.create();
    }
    if (!await audioDirectory.exists()) {
      await audioDirectory.create();
    }
  }

  File segmentFile(int index) {
    if (index < 0 || index > 99999) {
      throw ArgumentError.value(index, 'index');
    }
    final padded = index.toString().padLeft(5, '0');
    return File(
      _join(audioDirectory.path, 'segment_$padded.m4a'),
    );
  }

  List<String> get protectedReviewedArtifactPaths => <String>[
        reviewedTranscriptFile.path,
        reviewedTranscriptBackupFile.path,
      ];

  static void _validateSessionId(String sessionId) {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,96}$').hasMatch(sessionId)) {
      throw ArgumentError.value(
        sessionId,
        'sessionId',
        'Unsafe long-form session id.',
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
