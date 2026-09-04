import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_long_form_audio_contract.dart';
import 'package:medcases/services/audio/clinical_long_form_recording_manifest.dart';
import 'package:medcases/services/audio/clinical_long_form_recording_session.dart';
import 'package:medcases/services/audio/record_long_form_audio_provider.dart';
import 'package:record/record.dart';

final class _FakeLongFormCapture implements ClinicalLongFormFileCapture {
  final List<String> lifecycle = <String>[];

  @override
  Future<void> startSegment({
    required String path,
    required ClinicalLongFormRecordingConfig config,
  }) async {
    lifecycle.add('start:$path');
  }

  @override
  Future<void> pause() async {
    lifecycle.add('pause');
  }

  @override
  Future<void> resume() async {
    lifecycle.add('resume');
  }

  @override
  Future<String?> stopSegment() async {
    lifecycle.add('stop');
    return null;
  }

  @override
  Future<void> cancelSegment() async {
    lifecycle.add('cancel');
  }

  @override
  Future<void> dispose() async {
    lifecycle.add('dispose');
  }
}

void main() {
  test('default long-form profile targets lecture-scale compressed audio', () {
    const config = ClinicalLongFormRecordingConfig();

    expect(config.segmentDuration, const Duration(minutes: 5));
    expect(config.maxDuration, const Duration(hours: 6));
    expect(config.requestedSampleRateHz, 24000);
    expect(config.requestedBitRateBps, 64000);
    expect(config.channels, 1);
    expect(config.fileExtension, 'm4a');

    expect(config.estimatedBytesPerSegment, 2400000);
    expect(config.estimatedBytesPerHour, 28800000);
    expect(config.estimatedBytesAtMaxDuration, 172800000);
  });

  test('record provider requests AAC-LC M4A profile without DSP', () {
    const config = ClinicalLongFormRecordingConfig();

    final recordConfig = RecordLongFormAudioProvider.buildRecordConfig(config);

    expect(recordConfig.encoder, AudioEncoder.aacLc);
    expect(recordConfig.bitRate, 64000);
    expect(recordConfig.sampleRate, 24000);
    expect(recordConfig.numChannels, 1);
    expect(recordConfig.autoGain, isFalse);
    expect(recordConfig.echoCancel, isFalse);
    expect(recordConfig.noiseSuppress, isFalse);

    expect(
      RecordLongFormAudioProvider.productionCutoverEnabled,
      isFalse,
    );
    expect(
      RecordLongFormAudioProvider.productionPersistenceEnabled,
      isFalse,
    );
    expect(
      RecordLongFormAudioProvider.remoteUploadEnabled,
      isFalse,
    );
  });

  test('pause resume excludes paused wall time from active duration', () async {
    final fake = _FakeLongFormCapture();
    final session = ClinicalLongFormRecordingSession(
      sessionId: 'lecture_001',
      locale: 'pt-BR',
      capture: fake,
    );

    final t0 = DateTime.utc(2026, 8, 19, 10);

    await session.start(
      firstSegmentPath: '/tmp/lecture_001_000.m4a',
      nowUtc: t0,
    );

    await session.pause(t0.add(const Duration(minutes: 2)));
    expect(
      session.activeDurationAt(t0.add(const Duration(minutes: 20))),
      const Duration(minutes: 2),
    );

    await session.resume(t0.add(const Duration(minutes: 20)));
    expect(
      session.activeDurationAt(t0.add(const Duration(minutes: 23))),
      const Duration(minutes: 5),
    );

    await session.stop(t0.add(const Duration(minutes: 23)));

    expect(
      fake.lifecycle,
      <String>[
        'start:/tmp/lecture_001_000.m4a',
        'pause',
        'resume',
        'stop',
      ],
    );
  });

  test('five-minute rotation creates contiguous completed segments', () async {
    final fake = _FakeLongFormCapture();
    final session = ClinicalLongFormRecordingSession(
      sessionId: 'lecture_002',
      locale: 'es-ES',
      capture: fake,
    );

    final t0 = DateTime.utc(2026, 8, 19, 11);

    await session.start(
      firstSegmentPath: '/tmp/lecture_002_000.m4a',
      nowUtc: t0,
    );

    expect(
      session.shouldRotate(t0.add(const Duration(minutes: 4, seconds: 59))),
      isFalse,
    );
    expect(
      session.shouldRotate(t0.add(const Duration(minutes: 5))),
      isTrue,
    );

    await session.rotate(
      nextSegmentPath: '/tmp/lecture_002_001.m4a',
      nowUtc: t0.add(const Duration(minutes: 5)),
    );

    await session.stop(t0.add(const Duration(minutes: 8)));

    final manifest = session.snapshot(
      t0.add(const Duration(minutes: 8)),
    );

    expect(manifest.segments, hasLength(2));
    expect(manifest.segments[0].index, 0);
    expect(manifest.segments[0].activeDuration, const Duration(minutes: 5));
    expect(manifest.segments[0].completed, isTrue);
    expect(manifest.segments[1].index, 1);
    expect(manifest.segments[1].activeDuration, const Duration(minutes: 3));
    expect(manifest.segments[1].completed, isTrue);
    expect(manifest.totalActiveDuration, const Duration(minutes: 8));
  });

  test('manifest JSON round-trip supports crash recovery plan', () async {
    final fake = _FakeLongFormCapture();
    final session = ClinicalLongFormRecordingSession(
      sessionId: 'lecture_recovery',
      locale: 'pt-BR',
      capture: fake,
    );

    final t0 = DateTime.utc(2026, 8, 19, 12);

    await session.start(
      firstSegmentPath: '/tmp/lecture_recovery_000.m4a',
      nowUtc: t0,
    );

    final liveManifest = session.snapshot(
      t0.add(const Duration(minutes: 3)),
    );

    final encoded = jsonEncode(liveManifest.toJson());
    final decoded = ClinicalLongFormRecordingManifest.fromJson(
      (jsonDecode(encoded) as Map<String, dynamic>).cast<String, Object?>(),
    );

    final plan = ClinicalLongFormRecoveryPlan.fromManifest(decoded);

    expect(decoded.sessionId, 'lecture_recovery');
    expect(decoded.state, ClinicalLongFormRecordingState.recording);
    expect(decoded.segments, hasLength(1));
    expect(decoded.segments.single.completed, isFalse);
    expect(plan.canRecover, isTrue);
    expect(plan.nextSegmentIndex, 1);
    expect(plan.reason, 'resume_as_new_segment');
    expect(plan.totalRecoveredDuration, const Duration(minutes: 3));

    await session.stop(t0.add(const Duration(minutes: 3)));
  });

  test('long-form foundation remains isolated from production and network', () {
    final source = <String>[
      File(
        'lib/services/audio/clinical_long_form_audio_contract.dart',
      ).readAsStringSync(),
      File(
        'lib/services/audio/clinical_long_form_recording_manifest.dart',
      ).readAsStringSync(),
      File(
        'lib/services/audio/record_long_form_audio_provider.dart',
      ).readAsStringSync(),
      File(
        'lib/services/audio/clinical_long_form_recording_session.dart',
      ).readAsStringSync(),
    ].join('\n');

    for (final forbidden in <String>[
      'package:http',
      'WebSocket',
      'HttpClient',
      'Authorization',
      'Bearer ',
      'api.openai.com',
      'Firebase',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }

    final main = File('lib/main.dart').readAsStringSync();
    final recorder =
        File('lib/services/clinical_recorder_service.dart').readAsStringSync();
    final history = File('lib/screens/history_screen.dart').readAsStringSync();

    expect(
      main,
      isNot(contains('ClinicalLongFormRecordingSession')),
    );
    expect(
      recorder,
      isNot(contains('ClinicalLongFormRecordingSession')),
    );
    expect(
      history,
      isNot(contains('ClinicalLongFormRecordingSession')),
    );

    // Manifest intentionally stores only opaque session/file metadata.
    expect(source, isNot(contains('patientName')));
    expect(source, isNot(contains('patientDocument')));
    expect(source, isNot(contains('patientCpf')));
  });
}
