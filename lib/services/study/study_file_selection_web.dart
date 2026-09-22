// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<PlatformFile?> select(
    List<String> extensions, bool longInput, bool audio) async {
  if (!audio) {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        allowMultiple: false,
        withData: !longInput,
        withReadStream: longInput);
    return result?.files.first;
  }
  final input = html.FileUploadInputElement()
    ..accept = extensions.map((e) => '.$e').join(',');
  final complete = Completer<PlatformFile?>();
  input.onChange.first.then((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      complete.complete(null);
      return;
    }
    final file = files.single;
    final url = html.Url.createObjectUrl(file);
    complete.complete(PlatformFile(
        name: file.name,
        size: file.size,
        path: url,
        readStream: _stream(file)));
  });
  input.addEventListener('cancel', (_) {
    if (!complete.isCompleted) complete.complete(null);
  });
  input.click();
  return complete.future;
}

Stream<List<int>> _stream(html.File file) async* {
  for (var offset = 0; offset < file.size; offset += 1024 * 1024) {
    final reader = html.FileReader();
    final loaded = reader.onLoad.first;
    reader.readAsArrayBuffer(
        file.slice(offset, (offset + 1024 * 1024).clamp(0, file.size)));
    await loaded;
    final result = reader.result;
    yield result is ByteBuffer ? result.asUint8List() : result as Uint8List;
  }
}

Future<int?> duration(PlatformFile file) async {
  final audio = html.AudioElement()..preload = 'metadata';
  try {
    final loaded = audio.onLoadedMetadata.first;
    audio.src = file.path!;
    await loaded.timeout(const Duration(seconds: 30));
    return audio.duration.isFinite ? (audio.duration * 1000).round() : null;
  } finally {
    audio.removeAttribute('src');
    audio.load();
  }
}

void release(PlatformFile file) {
  final path = file.path;
  if (path != null && path.startsWith('blob:')) html.Url.revokeObjectUrl(path);
}
