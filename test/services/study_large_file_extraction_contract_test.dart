import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/study/study_large_file_extraction_service.dart';

void main() {
  test('long-input product contract is 4h audio and 50MiB PDF', () {
    expect(
      StudyLongInputPolicy.maxUploadedAudioDuration,
      const Duration(hours: 4),
    );
    expect(StudyLongInputPolicy.audioTokensPerSecond, 32);
    expect(StudyLongInputPolicy.maxUploadedAudioTokens, 460800);
    expect(StudyLongInputPolicy.maxPdfBytes, 50 * 1024 * 1024);
    expect(StudyLongInputPolicy.maxFilesApiBytes, 2 * 1024 * 1024 * 1024);
    expect(StudyLongInputPolicy.maxPdfPages, 1000);
  });

  test('Files API owner is resumable, coverage-gated and delete-finalized', () {
    final source = File(
      'lib/services/study/study_large_file_extraction_service.dart',
    ).readAsStringSync();

    for (final required in <String>[
      'X-Goog-Upload-Protocol',
      'resumable',
      'X-Goog-Upload-Command',
      'upload, finalize',
      'fileData',
      ':countTokens',
      '65536',
      'study_audio_over_4h',
      'study_audio_coverage_block_count_mismatch',
      'study_pdf_coverage_count_mismatch',
      'study_pdf_coverage_page_missing',
      'study_long_extract_truncated',
      '.delete(',
      'study_remote_file_cleanup_failed',
    ]) {
      expect(source, contains(required), reason: required);
    }

    expect(source, isNot(contains('base64Encode(')));
    expect(source, isNot(contains('Uint8List.fromList(')));
  });

  test('Study picker streams PDF/audio instead of demanding full bytes', () {
    final screen =
        File('lib/screens/study_workspace_screen.dart').readAsStringSync();

    expect(screen, contains('withReadStream: isLongInput'));
    expect(screen, contains('withData: !isLongInput'));
    expect(screen, contains('file.readStream'));
    expect(
      screen,
      contains('StudyLargeFileExtractionService.binaryStream('),
    );
  });
}
