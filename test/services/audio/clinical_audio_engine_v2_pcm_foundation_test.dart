import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_audio_capture_provider.dart';
import 'package:medcases/services/audio/clinical_pcm16_chunk_framer.dart';

void main() {
  const format = ClinicalPcmFormat();

  test('PCM canonical geometry is 24kHz mono PCM16 in 100ms frames', () {
    format.validate();

    expect(format.sampleRate, 24000);
    expect(format.channels, 1);
    expect(format.bitsPerSample, 16);
    expect(format.targetChunkDurationMs, 100);
    expect(format.bytesPerSecond, 48000);
    expect(format.bytesPerChunk, 4800);
  });

  test('framer emits exact 100ms boundaries and preserves byte order', () {
    final framer = ClinicalPcm16ChunkFramer(format);

    final source = Uint8List.fromList(
      List<int>.generate(10000, (index) => index % 251),
    );

    final first = framer.add(Uint8List.sublistView(source, 0, 1000));
    expect(first, isEmpty);
    expect(framer.pendingBytes, 1000);

    final second = framer.add(Uint8List.sublistView(source, 1000, 5200));
    expect(second, hasLength(1));
    expect(second.single, orderedEquals(source.sublist(0, 4800)));
    expect(framer.pendingBytes, 400);

    final third = framer.add(Uint8List.sublistView(source, 5200));
    expect(third, hasLength(1));
    expect(third.single, orderedEquals(source.sublist(4800, 9600)));

    final tail = framer.flush();
    expect(tail, isNotNull);
    expect(tail, orderedEquals(source.sublist(9600)));
    expect(framer.pendingBytes, 0);
  });

  test('record provider is foundation-only and does not cut over production',
      () {
    final providerSource = File(
      'lib/services/audio/record_pcm_capture_provider.dart',
    ).readAsStringSync();

    expect(providerSource, contains('AudioEncoder.pcm16bits'));
    expect(providerSource, contains('sampleRate: _format.sampleRate'));
    expect(providerSource, contains('numChannels: _format.channels'));
    expect(providerSource, contains('streamBufferSize: _format.bytesPerChunk'));
    expect(providerSource, contains('autoGain: false'));
    expect(providerSource, contains('echoCancel: false'));
    expect(providerSource, contains('noiseSuppress: false'));

    expect(
      providerSource,
      contains('static const bool productionCutoverEnabled = false'),
    );
    expect(
      providerSource,
      contains('static const bool remoteTranscriptionEnabled = false'),
    );
    expect(
      providerSource,
      contains('static const bool audioUploadEnabled = false'),
    );

    expect(providerSource, isNot(contains('stt_helper.dart')));
    expect(providerSource, isNot(contains('clinical_recorder_service.dart')));
    expect(providerSource, isNot(contains('http.')));
    expect(providerSource, isNot(contains('WebSocket')));
    expect(providerSource, isNot(contains('OpenAI')));
  });

  test('legacy recorder remains the production owner in this build', () {
    final legacy = File(
      'lib/services/clinical_recorder_service.dart',
    ).readAsStringSync();

    expect(legacy, contains("import 'stt_helper.dart';"));
    expect(legacy, contains('SttHelper.start('));
    expect(
      legacy,
      isNot(contains('record_pcm_capture_provider.dart')),
    );
    expect(
      legacy,
      isNot(contains('RecordPcmCaptureProvider')),
    );
  });
}
