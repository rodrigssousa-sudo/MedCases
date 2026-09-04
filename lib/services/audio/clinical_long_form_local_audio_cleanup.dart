import 'dart:io';

import 'clinical_long_form_recording_manifest.dart';

final class ClinicalLongFormAudioCleanupReport {
  const ClinicalLongFormAudioCleanupReport({
    required this.expectedFiles,
    required this.deletedFiles,
    required this.alreadyMissingFiles,
  });

  final int expectedFiles;
  final int deletedFiles;
  final int alreadyMissingFiles;

  bool get complete => expectedFiles == deletedFiles + alreadyMissingFiles;
}

abstract interface class ClinicalLongFormAudioCleanup {
  Future<ClinicalLongFormAudioCleanupReport> deleteCompletedAudio(
    ClinicalLongFormRecordingManifest manifest,
  );
}

/// Deleter local isolado.
///
/// Só aceita segmentos .m4a de um manifest STOPPED e completo, e somente
/// arquivos que resolvem dentro do root explicitamente injetado.
/// Symlinks são rejeitados para impedir escape do diretório permitido.
final class FileClinicalLongFormAudioCleanup
    implements ClinicalLongFormAudioCleanup {
  FileClinicalLongFormAudioCleanup({
    required Directory allowedRootDirectory,
  }) : _allowedRootDirectory = allowedRootDirectory;

  static const bool productionCutoverEnabled = false;
  static const bool automaticDeleteEnabledInProduction = false;
  static const bool cloudDeleteEnabled = false;

  final Directory _allowedRootDirectory;

  @override
  Future<ClinicalLongFormAudioCleanupReport> deleteCompletedAudio(
    ClinicalLongFormRecordingManifest manifest,
  ) async {
    _validateManifest(manifest);

    if (!await _allowedRootDirectory.exists()) {
      throw StateError('Allowed audio root does not exist.');
    }

    final resolvedRoot = await _allowedRootDirectory.resolveSymbolicLinks();
    final rootPrefix = _withTrailingSeparator(resolvedRoot);

    var deleted = 0;
    var missing = 0;

    for (final segment in manifest.segments) {
      final path = segment.path;

      if (!path.toLowerCase().endsWith('.m4a')) {
        throw StateError('Only M4A segment cleanup is allowed.');
      }

      final file = File(path);

      if (!await file.exists()) {
        missing++;
        continue;
      }

      final type = await FileSystemEntity.type(
        file.path,
        followLinks: false,
      );

      if (type == FileSystemEntityType.link) {
        throw StateError('Symlink audio deletion is forbidden.');
      }

      if (type != FileSystemEntityType.file) {
        throw StateError('Audio cleanup target is not a regular file.');
      }

      final resolvedFile = await file.resolveSymbolicLinks();

      if (!resolvedFile.startsWith(rootPrefix)) {
        throw StateError(
          'Audio cleanup target is outside allowed root.',
        );
      }

      await file.delete();
      deleted++;
    }

    final report = ClinicalLongFormAudioCleanupReport(
      expectedFiles: manifest.segments.length,
      deletedFiles: deleted,
      alreadyMissingFiles: missing,
    );

    if (!report.complete) {
      throw StateError('Audio cleanup incomplete.');
    }

    return report;
  }

  static void _validateManifest(
    ClinicalLongFormRecordingManifest manifest,
  ) {
    if (manifest.state.name != 'stopped') {
      throw StateError(
        'Audio cleanup requires a stopped long-form recording.',
      );
    }

    if (manifest.segments.isEmpty) {
      throw StateError('Audio cleanup requires at least one segment.');
    }

    if (manifest.segments.any((segment) => !segment.completed)) {
      throw StateError(
        'Audio cleanup requires all segments completed.',
      );
    }
  }

  static String _withTrailingSeparator(String path) {
    final separator = Platform.pathSeparator;
    return path.endsWith(separator) ? path : '$path$separator';
  }
}
