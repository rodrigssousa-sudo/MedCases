import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

Future<PlatformFile?> select(
    List<String> extensions, bool longInput, bool audio) async {
  final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      allowMultiple: false,
      withData: !longInput,
      withReadStream: longInput);
  return result == null || result.files.isEmpty ? null : result.files.single;
}

Future<int?> duration(PlatformFile file) async {
  final path = file.path;
  if (path == null || !path.startsWith('/') || path.contains('\u0000'))
    throw const FormatException('INVALID_AUDIO_PATH');
  final selected = File(path);
  if (!await selected.exists() || await selected.length() != file.size)
    throw const FormatException('AUDIO_FILE_CHANGED');
  return await const MethodChannel('medcases/audio_duration_v1')
      .invokeMethod<int>(
          'duration', {'path': path}).timeout(const Duration(seconds: 30));
}

void release(PlatformFile file) {}
