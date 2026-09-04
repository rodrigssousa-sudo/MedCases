import 'dart:io';

import 'openai_file_transcription_shadow_protocol.dart';

final class FileClinicalLongFormLocalAudioInspector
    implements ClinicalLongFormLocalAudioInspector {
  const FileClinicalLongFormLocalAudioInspector();

  static const bool productionCutoverEnabled = false;

  @override
  Future<ClinicalLongFormLocalAudioDescriptor> inspect(
    String segmentPath,
  ) async {
    if (!segmentPath.toLowerCase().endsWith('.m4a')) {
      throw StateError('Long-form remote transport requires M4A.');
    }

    final type = await FileSystemEntity.type(
      segmentPath,
      followLinks: false,
    );

    if (type == FileSystemEntityType.link) {
      throw StateError('Audio segment symlink is forbidden.');
    }

    if (type != FileSystemEntityType.file) {
      throw StateError('Audio segment is not a regular file.');
    }

    final file = File(segmentPath);
    final bytes = await file.length();

    if (bytes < 1) {
      throw StateError('Audio segment is empty.');
    }

    return ClinicalLongFormLocalAudioDescriptor(
      path: segmentPath,
      fileBytes: bytes,
    );
  }
}
