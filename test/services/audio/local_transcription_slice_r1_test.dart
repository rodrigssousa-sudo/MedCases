import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/local_transcription_slice.dart';
import 'package:medcases/services/audio/continuous_aac_file.dart';

Uint8List audio(int seconds) {
  final frames = seconds * 24000 ~/ 1024;
  final b = Uint8List(frames * 8);
  for (var i = 0; i < frames; i++) {
    b.setRange(i * 8, i * 8 + 8, [255, 241, 88, 64, 1, 0, 252, i % 256]);
  }
  return b;
}

void main() {
  for (final testCase in [(875, 560000), (300, 560000)]) {
    test(
        'original ${testCase.$1}s; authorize ${testCase.$2}ms exactly and preserve source',
        () async {
      final root = await Directory.systemTemp.createTemp('immutable-slice-r1-');
      final original = File('${root.path}/original.aac');
      final bytes = audio(testCase.$1);
      await original.writeAsBytes(bytes);
      try {
        final s = await LocalTranscriptionSlice.prepare(
            original: original.path,
            destination: '${root.path}/part.aac',
            startFrame: 0,
            allowedMs: testCase.$2);
        expect(s.durationMs, lessThanOrEqualTo(testCase.$2));
        expect(continuousAacDurationMs(await File(s.path).readAsBytes()),
            s.durationMs);
        expect(await original.readAsBytes(), bytes);
        if (s.remainingMs > 0) {
          final tail = await LocalTranscriptionSlice.prepare(
              original: original.path,
              destination: '${root.path}/tail.aac',
              startFrame: s.endFrame,
              allowedMs: 560000);
          expect(tail.startFrame, s.endFrame);
          expect(tail.endFrame, s.totalFrames);
          final merged = [
            ...await File(s.path).readAsBytes(),
            ...await File(tail.path).readAsBytes()
          ];
          expect(merged, bytes);
          expect(tail.remainingMs, 0);
        } else {
          expect(s.endFrame, s.totalFrames);
        }
      } finally {
        await root.delete(recursive: true);
      }
    });
  }
  test('zero quota never edits source or creates a slice', () async {
    final root = await Directory.systemTemp.createTemp('zero-slice-r1-');
    final f = File('${root.path}/source.aac');
    final bytes = audio(20);
    await f.writeAsBytes(bytes);
    try {
      await expectLater(
          LocalTranscriptionSlice.prepare(
              original: f.path,
              destination: '${root.path}/part.aac',
              startFrame: 0,
              allowedMs: 0),
          throwsStateError);
      expect(await f.readAsBytes(), bytes);
      expect(await File('${root.path}/part.aac').exists(), false);
    } finally {
      await root.delete(recursive: true);
    }
  });
  test(
      'corruption preserves original and does not publish incomplete derivative',
      () async {
    final root = await Directory.systemTemp.createTemp('corrupt-slice-r1-');
    final f = File('${root.path}/source.aac');
    final bytes = Uint8List.fromList([...audio(20), 255]);
    await f.writeAsBytes(bytes);
    try {
      await expectLater(
          LocalTranscriptionSlice.prepare(
              original: f.path,
              destination: '${root.path}/part.aac',
              startFrame: 0,
              allowedMs: 10000),
          throwsFormatException);
      expect(await f.readAsBytes(), bytes);
      expect(await File('${root.path}/part.aac').exists(), false);
    } finally {
      await root.delete(recursive: true);
    }
  });
  test('continuous local file exceeds 90 minutes without segmentation or cap',
      () async {
    final root = await Directory.systemTemp.createTemp('long-local-r1-');
    try {
      final original = File('${root.path}/source.aac');
      await original.writeAsBytes(audio(2 * 60 * 60));
      final scan = inspectContinuousAacFile(original.path);
      expect(scan.durationMs, greaterThan(90 * 60 * 1000));
      final capture = ContinuousAacFile(original.path, append: true);
      capture.add(audio(20));
      capture.close();
      expect(inspectContinuousAacFile(original.path).frames,
          greaterThan(scan.frames));
      expect(root.listSync().whereType<File>().length, 1);
    } finally {
      await root.delete(recursive: true);
    }
  });
  test('crash-tail recovery keeps byte-for-byte original backup', () async {
    final root = await Directory.systemTemp.createTemp('crash-local-r1-');
    try {
      final file = File('${root.path}/source.aac');
      final valid = audio(20);
      final crashed = Uint8List.fromList([...valid, 255, 241]);
      await file.writeAsBytes(crashed);
      expect(() => inspectContinuousAacFile(file.path), throwsFormatException);
      final capture = ContinuousAacFile(file.path, append: true);
      capture.close();
      expect(await file.readAsBytes(), valid);
      expect(
          await File('${file.path}.crash-preserved-0').readAsBytes(), crashed);
    } finally {
      await root.delete(recursive: true);
    }
  });
}
