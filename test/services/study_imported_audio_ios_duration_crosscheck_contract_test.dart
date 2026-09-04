import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS imported audio duration uses asset plus audio-track cross-check',
      () {
    final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final pipe = File(
      'lib/services/study/study_imported_audio_pipeline_io.dart',
    ).readAsStringSync();

    expect(ios, contains('assetDurationSeconds'));
    expect(ios, contains('asset.tracks(withMediaType: .audio)'));
    expect(ios, contains('CMTimeRangeGetEnd(track.timeRange)'));
    expect(ios, contains('durationCandidates.max()'));
    expect(ios, contains('maximumTrackEndSeconds'));
    expect(ios, contains('[StudyImportedAudioNative]'));
    expect(ios, contains('chosenDurationMs='));

    expect(pipe, contains('[StudyImportedAudioCoverage]'));
    expect(pipe, contains('coveredDurationMs'));
    expect(pipe, contains('_validateCoverage(segments, durationMs)'));
  });

  test('5 minute segmentation and 4 hour hard cap remain intact', () {
    final pipe = File(
      'lib/services/study/study_imported_audio_pipeline_io.dart',
    ).readAsStringSync();
    final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(pipe, contains('4 * 60 * 60 * 1000'));
    expect(pipe, contains('5 * 60 * 1000'));
    expect(ios, contains('segmentDurationMs'));
    expect(ios, contains('study_audio_over_4h'));
    expect(ios, contains('AVAssetExportPresetAppleM4A'));
  });
}
