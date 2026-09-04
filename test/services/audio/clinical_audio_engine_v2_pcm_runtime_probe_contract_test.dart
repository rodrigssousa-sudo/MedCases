import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_audio_capture_provider.dart';
import 'package:medcases/services/audio/clinical_pcm_runtime_metrics.dart';

void main() {
  const format = ClinicalPcmFormat();

  test('runtime metrics preserve PCM frame geometry', () {
    final m = ClinicalPcmRuntimeMetrics(format)..start();
    for (var i = 0; i < 10; i++) {
      m.addFrame(Uint8List(format.bytesPerChunk));
    }
    m.stop();
    final s = m.snapshot();
    expect(s.frameCount, 10);
    expect(s.totalBytes, 48000);
    expect(s.fullFrameCount, 10);
    expect(s.tailFrameCount, 0);
  });

  test('irregular tail is measured rather than discarded', () {
    final m = ClinicalPcmRuntimeMetrics(format)..start();
    m.addFrame(Uint8List(format.bytesPerChunk));
    m.addFrame(Uint8List(1234));
    m.stop();
    final s = m.snapshot();
    expect(s.fullFrameCount, 1);
    expect(s.tailFrameCount, 1);
    expect(s.minFrameBytes, 1234);
    expect(s.maxFrameBytes, format.bytesPerChunk);
  });

  test('probe stays isolated and local-only', () {
    final probe =
        File('lib/debug/audio_pcm_runtime_probe.dart').readAsStringSync();
    expect(probe, contains('RecordPcmCaptureProvider'));
    expect(probe, contains('PRODUCTION_CUTOVER=NO'));
    expect(probe, contains('O áudio não é salvo, transcrito ou enviado'));
    for (final token in const [
      'clinical_recorder_service.dart',
      'stt_helper.dart',
      'speech_to_text',
      'package:http',
      'WebSocket',
      'OpenAI',
      'Gemini',
      'Firebase',
    ]) {
      expect(probe, isNot(contains(token)), reason: token);
    }
  });

  test('production does not import runtime probe', () {
    final main = File('lib/main.dart').readAsStringSync();
    final recorder =
        File('lib/services/clinical_recorder_service.dart').readAsStringSync();
    expect(main, isNot(contains('audio_pcm_runtime_probe.dart')));
    expect(main, isNot(contains('ClinicalPcmRuntimeMetrics')));
    expect(recorder, isNot(contains('RecordPcmCaptureProvider')));
  });
}
