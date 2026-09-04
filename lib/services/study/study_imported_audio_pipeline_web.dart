import 'study_multimodal_extraction_service.dart';

final class StudyImportedAudioPipelineResult {
  const StudyImportedAudioPipelineResult({
    required this.extraction,
    required this.jobId,
    required this.segmentCount,
  });

  final StudyExtraction extraction;
  final String jobId;
  final int segmentCount;
}

final class StudyImportedAudioPipeline {
  const StudyImportedAudioPipeline._();

  static bool get nativePhysicalSegmentationAvailable => false;

  static Future<StudyImportedAudioPipelineResult> process({
    required String sourceId,
    required String fileName,
    required String sourcePath,
    required int fileSize,
    required bool isEs,
  }) {
    throw UnsupportedError(
      'study_imported_audio_native_segmentation_unavailable',
    );
  }

  static Future<void> cleanup(String jobId) async {}
}
