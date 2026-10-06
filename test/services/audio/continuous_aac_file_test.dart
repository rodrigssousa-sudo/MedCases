import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/continuous_aac_file.dart';

Uint8List frame({int index = 6}) => Uint8List.fromList(
    [255, 241, 64 | (index << 2), 64, 1, 127, 252, 1, 2, 3, 4]);
void main() {
  test('partial transport chunks reach disk only as complete frames', () async {
    final dir = await Directory.systemTemp.createTemp('aac-safe-');
    final path = '${dir.path}/recording.aac', f = frame();
    final writer = ContinuousAacFile(path);
    try {
      writer.add(Uint8List.fromList(f.take(4).toList()));
      expect(File(path).lengthSync(), 0);
      writer.add(Uint8List.fromList(f.skip(4).toList()));
      expect(File(path).readAsBytesSync(), f);
      expect(continuousAacDurationMs(File(path).readAsBytesSync()), 43);
      writer.add(Uint8List.fromList(f.take(5).toList()));
      expect(() => writer.close(), throwsStateError);
      expect(File(path).readAsBytesSync(), f);
      final resumed = ContinuousAacFile(path, append: true);
      resumed.add(f);
      resumed.close();
      expect(File(path).readAsBytesSync(), [...f, ...f]);
      expect(continuousAacDurationMs(File(path).readAsBytesSync()), 86);
    } finally {
      writer.close();
      await dir.delete(recursive: true);
    }
  });
  test('existing data is never overwritten and malformed append is rejected',
      () async {
    final dir = await Directory.systemTemp.createTemp('aac-safe-');
    final path = '${dir.path}/recording.aac';
    try {
      File(path).writeAsBytesSync(frame());
      expect(() => ContinuousAacFile(path), throwsStateError);
      final resumed = ContinuousAacFile(path, append: true);
      expect(() => resumed.add(frame(index: 4)), throwsStateError);
      resumed.close();
      final before = File(path).readAsBytesSync();
      File(path).writeAsBytesSync([...before, 255]);
      final recovered = ContinuousAacFile(path, append: true);
      recovered.close();
      expect(File(path).readAsBytesSync(), before);
      expect(
          File('$path.crash-preserved-0').readAsBytesSync(), [...before, 255]);
      File(path).writeAsBytesSync([...before, 0, 0, 0, 0, 0, 0, 0]);
      expect(
          () => ContinuousAacFile(path, append: true), throwsFormatException);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
