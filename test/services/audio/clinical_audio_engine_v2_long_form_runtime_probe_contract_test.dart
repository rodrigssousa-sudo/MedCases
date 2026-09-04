import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_long_form_audio_contract.dart';
import 'package:medcases/services/audio/record_long_form_audio_provider.dart';
import 'package:record/record.dart';

void main() {
  test('accelerated physical profile remains canonical AAC-LC', () {
    const c = ClinicalLongFormRecordingConfig(
      segmentDuration: Duration(minutes: 1),
      maxDuration: Duration(minutes: 10),
      requestedSampleRateHz: 24000,
      requestedBitRateBps: 64000,
      channels: 1,
      fileExtension: 'm4a',
    );
    c.validate();
    final r = RecordLongFormAudioProvider.buildRecordConfig(c);
    expect(r.encoder, AudioEncoder.aacLc);
    expect(r.bitRate, 64000);
    expect(r.sampleRate, 24000);
    expect(r.numChannels, 1);
  });

  test('probe stays local-only and production remains unwired', () {
    final p =
        File('lib/debug/audio_long_form_runtime_probe.dart').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final recorder =
        File('lib/services/clinical_recorder_service.dart').readAsStringSync();

    expect(p, contains('RecordLongFormAudioProvider'));
    expect(p, contains('ClinicalLongFormRecordingSession'));
    expect(p, contains('FileClinicalLongFormAudioCleanup'));
    expect(p, contains('AUDIO_UPLOADED=NO'));
    expect(p, contains('TRANSCRIPTION=NO'));
    expect(p, contains('REAL_PATIENT_AUDIO=NO'));
    expect(p, contains('PRODUCTION_CUTOVER=NO'));

    expect(p, isNot(contains("package:http")));
    expect(p, isNot(contains('openai_')));
    expect(p, isNot(contains('RemoteBatch')));
    expect(p, isNot(contains('StagingToBackend')));
    expect(main, isNot(contains('audio_long_form_runtime_probe.dart')));
    expect(recorder, isNot(contains('RecordLongFormAudioProvider')));
  });
}
