import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Study imported audio uses native 5-minute physical segmentation on iOS',
      () {
    final pipeline = File(
      'lib/services/study/study_imported_audio_pipeline_io.dart',
    ).readAsStringSync();
    final screen =
        File('lib/screens/study_workspace_screen.dart').readAsStringSync();
    final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(
      pipeline,
      contains("MethodChannel('medcases/study_imported_audio_segmenter_v1')"),
    );
    expect(pipeline, contains('4 * 60 * 60 * 1000'));
    expect(pipeline, contains('5 * 60 * 1000'));
    expect(pipeline, contains('ClinicalLongFormCheckpointedBatchRunner('));
    expect(
      pipeline,
      contains('ClinicalLongFormEngineStateRecoveryOrchestrator('),
    );
    expect(pipeline, contains('StudyMultimodalExtractionService.binary('));
    expect(pipeline, contains('queue.isComplete'));
    expect(pipeline, contains('assembler.isComplete'));

    expect(
      screen,
      contains(
        'StudyImportedAudioPipeline.nativePhysicalSegmentationAvailable',
      ),
    );
    expect(screen, contains('file.path != null'));

    expect(ios, contains('import AVFoundation'));
    expect(ios, contains('AVAssetExportPresetAppleM4A'));
    expect(ios, contains('exporter.timeRange'));
    expect(ios, contains('segment_%05d.m4a'));
    expect(ios, contains('study_audio_over_4h'));
    expect(ios, contains('FileProtectionType.completeUnlessOpen'));
    expect(ios, contains('isExcludedFromBackup = true'));
  });

  test('R2 PDF and non-iOS fallback remain present', () {
    final screen =
        File('lib/screens/study_workspace_screen.dart').readAsStringSync();
    final large = File(
      'lib/services/study/study_large_file_extraction_service.dart',
    ).readAsStringSync();

    expect(
      screen,
      contains('StudyLargeFileExtractionService.binaryStream('),
    );
    expect(large, contains('study_pdf_coverage_page_missing'));
    expect(large, contains('maxPdfPages = 1000'));
    expect(large, contains('maxPdfBytes = 50 * 1024 * 1024'));
  });
}
