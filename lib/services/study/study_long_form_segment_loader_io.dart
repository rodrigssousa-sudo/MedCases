import 'dart:io';
import 'dart:typed_data';

final class StudyLongFormSegmentLoader {
  const StudyLongFormSegmentLoader._();

  static Future<Uint8List> read(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('study_recorded_segment_missing');
    }
    return file.readAsBytes();
  }

  static Future<void> deleteAll(Iterable<String> paths) async {
    for (final path in paths) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
