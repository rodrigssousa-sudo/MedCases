import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_long_form_review_lifecycle.dart';
import 'package:medcases/services/audio/clinical_long_form_reviewed_transcript_artifact.dart';
import 'package:medcases/services/audio/clinical_long_form_session_directory_layout.dart';
import 'package:medcases/services/audio/clinical_long_form_session_garbage_collector.dart';

ClinicalLongFormReviewedTranscriptArtifact _artifact({
  required ClinicalLongFormAudioRetentionState state,
  ClinicalLongFormAudioDisposition? disposition,
}) {
  return ClinicalLongFormReviewedTranscriptArtifact(
    sessionId: 'lecture_gc_001',
    locale: 'pt-BR',
    reviewedTranscript: 'Transcrição revisada e aprovada.',
    reviewedAtUtc: DateTime.utc(2026, 8, 19, 12),
    sourceSegmentCount: 2,
    sourceActiveDuration: const Duration(minutes: 10),
    retentionState: state,
    audioDisposition: disposition,
  );
}

void main() {
  test('session layout produces canonical isolated paths', () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_gc_layout_',
    );

    try {
      final layout = ClinicalLongFormSessionDirectoryLayout(
        rootDirectory: root,
        sessionId: 'lecture_gc_001',
      );

      await layout.ensureDirectories();

      expect(await layout.sessionDirectory.exists(), isTrue);
      expect(await layout.audioDirectory.exists(), isTrue);
      expect(
        layout.segmentFile(7).path,
        endsWith(
          '${Platform.pathSeparator}audio'
          '${Platform.pathSeparator}segment_00007.m4a',
        ),
      );
      expect(
        layout.reviewedTranscriptFile.path,
        endsWith(
          '${Platform.pathSeparator}reviewed_transcript.json',
        ),
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('keepAudio removes temps but preserves M4A manifest and reviewed text',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_gc_keep_',
    );

    try {
      final layout = ClinicalLongFormSessionDirectoryLayout(
        rootDirectory: root,
        sessionId: 'lecture_gc_001',
      );
      await layout.ensureDirectories();

      final segment = layout.segmentFile(0);
      await segment.writeAsBytes(<int>[1, 2, 3], flush: true);
      await layout.manifestFile.writeAsString('{}', flush: true);
      await layout.batchQueueFile.writeAsString('{}', flush: true);
      await layout.reviewedTranscriptFile.writeAsString(
        '{"reviewedTranscript":"preserve"}',
        flush: true,
      );
      await layout.reviewedTranscriptBackupFile.writeAsString(
        '{"reviewedTranscript":"backup"}',
        flush: true,
      );
      await layout.manifestTempFile.writeAsString('tmp', flush: true);
      await layout.batchQueueTempFile.writeAsString('tmp', flush: true);
      await layout.reviewedTranscriptTempFile.writeAsString(
        'tmp',
        flush: true,
      );

      final collector = ClinicalLongFormSessionGarbageCollector(
        layout: layout,
      );

      await collector.collect(
        artifact: _artifact(
          state: ClinicalLongFormAudioRetentionState.keepAudio,
          disposition: ClinicalLongFormAudioDisposition.keepAudio,
        ),
      );

      expect(await segment.exists(), isTrue);
      expect(await layout.manifestFile.exists(), isTrue);
      expect(await layout.batchQueueFile.exists(), isTrue);
      expect(await layout.reviewedTranscriptFile.exists(), isTrue);
      expect(await layout.reviewedTranscriptBackupFile.exists(), isTrue);

      expect(await layout.manifestTempFile.exists(), isFalse);
      expect(await layout.batchQueueTempFile.exists(), isFalse);
      expect(await layout.reviewedTranscriptTempFile.exists(), isFalse);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('audioDeleted removes technical state but preserves reviewed artifact',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_gc_deleted_',
    );

    try {
      final layout = ClinicalLongFormSessionDirectoryLayout(
        rootDirectory: root,
        sessionId: 'lecture_gc_001',
      );
      await layout.ensureDirectories();

      await layout.manifestFile.writeAsString('{}', flush: true);
      await layout.manifestBackupFile.writeAsString('{}', flush: true);
      await layout.batchQueueFile.writeAsString('{}', flush: true);
      await layout.batchQueueBackupFile.writeAsString('{}', flush: true);
      await layout.reviewedTranscriptFile.writeAsString(
        '{"reviewedTranscript":"approved"}',
        flush: true,
      );
      await layout.reviewedTranscriptBackupFile.writeAsString(
        '{"reviewedTranscript":"approved-backup"}',
        flush: true,
      );
      await layout.reviewedTranscriptTempFile.writeAsString(
        'tmp',
        flush: true,
      );

      final unrelated = File(
        '${layout.sessionDirectory.path}'
        '${Platform.pathSeparator}user_export.txt',
      );
      await unrelated.writeAsString('preserve', flush: true);

      final collector = ClinicalLongFormSessionGarbageCollector(
        layout: layout,
      );

      final report = await collector.collect(
        artifact: _artifact(
          state: ClinicalLongFormAudioRetentionState.audioDeleted,
          disposition: ClinicalLongFormAudioDisposition.deleteAfterReview,
        ),
      );

      expect(report.deletedFiles, greaterThanOrEqualTo(5));

      expect(await layout.manifestFile.exists(), isFalse);
      expect(await layout.manifestBackupFile.exists(), isFalse);
      expect(await layout.batchQueueFile.exists(), isFalse);
      expect(await layout.batchQueueBackupFile.exists(), isFalse);
      expect(await layout.reviewedTranscriptTempFile.exists(), isFalse);

      expect(await layout.reviewedTranscriptFile.exists(), isTrue);
      expect(await layout.reviewedTranscriptBackupFile.exists(), isTrue);
      expect(await unrelated.exists(), isTrue);
      expect(await layout.sessionDirectory.exists(), isTrue);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('deletePending and deletionFailed never remove durable technical state',
      () async {
    for (final state in <ClinicalLongFormAudioRetentionState>[
      ClinicalLongFormAudioRetentionState.deletePending,
      ClinicalLongFormAudioRetentionState.deletionFailed,
    ]) {
      final root = await Directory.systemTemp.createTemp(
        'medcases_gc_retry_',
      );

      try {
        final layout = ClinicalLongFormSessionDirectoryLayout(
          rootDirectory: root,
          sessionId: 'lecture_gc_001',
        );
        await layout.ensureDirectories();

        final segment = layout.segmentFile(0);
        await segment.writeAsBytes(<int>[1], flush: true);
        await layout.manifestFile.writeAsString('{}', flush: true);
        await layout.batchQueueFile.writeAsString('{}', flush: true);
        await layout.reviewedTranscriptFile.writeAsString(
          '{"reviewedTranscript":"approved"}',
          flush: true,
        );
        await layout.manifestTempFile.writeAsString('tmp', flush: true);

        final collector = ClinicalLongFormSessionGarbageCollector(
          layout: layout,
        );

        await collector.collect(
          artifact: _artifact(
            state: state,
            disposition: ClinicalLongFormAudioDisposition.deleteAfterReview,
          ),
        );

        expect(await segment.exists(), isTrue, reason: state.name);
        expect(
          await layout.manifestFile.exists(),
          isTrue,
          reason: state.name,
        );
        expect(
          await layout.batchQueueFile.exists(),
          isTrue,
          reason: state.name,
        );
        expect(
          await layout.reviewedTranscriptFile.exists(),
          isTrue,
          reason: state.name,
        );
        expect(
          await layout.manifestTempFile.exists(),
          isFalse,
          reason: state.name,
        );
      } finally {
        await root.delete(recursive: true);
      }
    }
  });

  test('garbage collector never deletes arbitrary session files', () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_gc_arbitrary_',
    );

    try {
      final layout = ClinicalLongFormSessionDirectoryLayout(
        rootDirectory: root,
        sessionId: 'lecture_gc_001',
      );
      await layout.ensureDirectories();

      await layout.reviewedTranscriptFile.writeAsString(
        '{"reviewedTranscript":"approved"}',
        flush: true,
      );

      final arbitrary = File(
        '${layout.sessionDirectory.path}'
        '${Platform.pathSeparator}do_not_touch.bin',
      );
      await arbitrary.writeAsBytes(<int>[9, 9, 9], flush: true);

      final collector = ClinicalLongFormSessionGarbageCollector(
        layout: layout,
      );

      await collector.collect(
        artifact: _artifact(
          state: ClinicalLongFormAudioRetentionState.audioDeleted,
          disposition: ClinicalLongFormAudioDisposition.deleteAfterReview,
        ),
      );

      expect(await arbitrary.exists(), isTrue);
      expect(await layout.reviewedTranscriptFile.exists(), isTrue);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('layout rejects path traversal session ids', () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_gc_safe_id_',
    );

    try {
      expect(
        () => ClinicalLongFormSessionDirectoryLayout(
          rootDirectory: root,
          sessionId: '../escape',
        ),
        throwsArgumentError,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('GC source forbids broad recursive deletion and production cutover', () {
    final source = <String>[
      File(
        'lib/services/audio/'
        'clinical_long_form_session_directory_layout.dart',
      ).readAsStringSync(),
      File(
        'lib/services/audio/'
        'clinical_long_form_session_garbage_collector.dart',
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
      'delete(recursive: true)',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }

    expect(
      source,
      contains('broadRecursiveDeleteAllowed = false'),
    );
    expect(
      source,
      contains('reviewedArtifactDeletionAllowed = false'),
    );
    expect(
      source,
      contains('productionCutoverEnabled = false'),
    );

    final main = File('lib/main.dart').readAsStringSync();
    final recorder =
        File('lib/services/clinical_recorder_service.dart').readAsStringSync();
    final history = File('lib/screens/history_screen.dart').readAsStringSync();

    expect(
      main,
      isNot(contains('ClinicalLongFormSessionGarbageCollector')),
    );
    expect(
      recorder,
      isNot(contains('ClinicalLongFormSessionGarbageCollector')),
    );
    expect(
      history,
      isNot(contains('ClinicalLongFormSessionDirectoryLayout')),
    );
  });
}
