import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
Future<void> _pending = Future<void>.value();
File? _file;
void writeAiTrace(String line) {
  // Only structured metadata from AiStreamTrace may enter this sink.
  stderr.writeln(line);
  _pending = _pending.then((_) async {
    if (_file == null) {
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      _file = File('${dir.path}/medcases_ai_trace.log');
      await _file!.writeAsString('');
    }
    if (await _file!.length() > 131072) await _file!.writeAsString('');
    await _file!.writeAsString('$line\n', mode: FileMode.append, flush: true);
  }).catchError((Object _) {});
}
