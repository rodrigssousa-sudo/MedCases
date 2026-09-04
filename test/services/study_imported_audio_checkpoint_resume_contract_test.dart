import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('imported audio pipeline is checkpointed and restart-recoverable', () {
    final source = File(
      'lib/services/study/study_imported_audio_pipeline_io.dart',
    ).readAsStringSync();

    for (final marker in <String>[
      'FileClinicalLongFormDurableStore(',
      'FileClinicalLongFormSegmentTranscriptCheckpointStore(',
      'loadBatchQueue(jobId)',
      'recoverBatch(',
      'ClinicalLongFormBatchQueue.fromManifest(manifest)',
      'runUntilBlocked()',
      'assembler.assemble()',
      'queue.completedCount',
      'queue.totalCount',
    ]) {
      expect(source, contains(marker), reason: marker);
    }

    expect(
      source,
      contains("'study_imported_segment_transcription_failed'"),
    );
    expect(source, contains('retryable: false'));
  });
}
