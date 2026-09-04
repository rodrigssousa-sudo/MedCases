import 'dart:convert';
import 'dart:io';

import 'clinical_long_form_reviewed_transcript_artifact.dart';

abstract interface class ClinicalLongFormReviewedArtifactStore {
  Future<void> save(
    ClinicalLongFormReviewedTranscriptArtifact artifact,
  );

  Future<ClinicalLongFormReviewedTranscriptArtifact?> load(
    String sessionId,
  );
}

/// Persistência local do TEXTO revisado e metadados de retenção.
///
/// Não contém bytes de áudio, não possui cloud sync e não é importada por
/// produção nesta build. O root é injetado por caller futuro.
final class FileClinicalLongFormReviewedArtifactStore
    implements ClinicalLongFormReviewedArtifactStore {
  FileClinicalLongFormReviewedArtifactStore({
    required Directory rootDirectory,
  }) : _rootDirectory = rootDirectory;

  static const bool productionCutoverEnabled = false;
  static const bool cloudSyncEnabled = false;
  static const bool audioBytesPersistenceEnabled = false;

  final Directory _rootDirectory;

  @override
  Future<void> save(
    ClinicalLongFormReviewedTranscriptArtifact artifact,
  ) async {
    artifact.validate();

    final directory = await _sessionDirectory(
      artifact.sessionId,
    );
    final primary = File(
      _join(directory.path, 'reviewed_transcript.json'),
    );
    final backup = File('${primary.path}.bak');
    final temporary = File('${primary.path}.tmp');

    if (await temporary.exists()) {
      await temporary.delete();
    }

    await temporary.writeAsString(
      jsonEncode(artifact.toJson()),
      flush: true,
    );

    // Validate the bytes we are about to promote.
    final decoded = jsonDecode(await temporary.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Invalid temporary reviewed transcript artifact.',
      );
    }
    ClinicalLongFormReviewedTranscriptArtifact.fromJson(
      decoded.cast<String, Object?>(),
    );

    if (await primary.exists()) {
      await primary.copy(backup.path);
      await primary.delete();
    }

    await temporary.rename(primary.path);
  }

  @override
  Future<ClinicalLongFormReviewedTranscriptArtifact?> load(
    String sessionId,
  ) async {
    _validateSessionId(sessionId);

    final directory = Directory(
      _join(_rootDirectory.path, sessionId),
    );
    final primary = File(
      _join(directory.path, 'reviewed_transcript.json'),
    );
    final backup = File('${primary.path}.bak');

    final fromPrimary = await _tryRead(primary);
    if (fromPrimary != null) {
      return fromPrimary;
    }

    return _tryRead(backup);
  }

  Future<ClinicalLongFormReviewedTranscriptArtifact?> _tryRead(
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

      return ClinicalLongFormReviewedTranscriptArtifact.fromJson(
        decoded.cast<String, Object?>(),
      );
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    } on StateError {
      return null;
    }
  }

  Future<Directory> _sessionDirectory(
    String sessionId,
  ) async {
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
        'Unsafe reviewed artifact session id.',
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
