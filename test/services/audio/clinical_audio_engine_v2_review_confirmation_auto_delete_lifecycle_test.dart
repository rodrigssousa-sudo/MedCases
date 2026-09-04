import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_long_form_audio_contract.dart';
import 'package:medcases/services/audio/clinical_long_form_local_audio_cleanup.dart';
import 'package:medcases/services/audio/clinical_long_form_recording_manifest.dart';
import 'package:medcases/services/audio/clinical_long_form_review_lifecycle.dart';
import 'package:medcases/services/audio/clinical_long_form_transcript_assembler.dart';

ClinicalLongFormRecordingManifest _manifest({
  required List<String> paths,
}) {
  return ClinicalLongFormRecordingManifest(
    sessionId: 'lecture_review_001',
    locale: 'pt-BR',
    state: ClinicalLongFormRecordingState.stopped,
    createdAtUtc: DateTime.utc(2026, 8, 19, 10),
    totalActiveDuration: Duration(minutes: paths.length * 5),
    segments: List<ClinicalLongFormSegmentManifest>.generate(
      paths.length,
      (index) => ClinicalLongFormSegmentManifest(
        index: index,
        path: paths[index],
        startedAtUtc: DateTime.utc(2026, 8, 19, 10).add(
          Duration(minutes: index * 5),
        ),
        activeDuration: const Duration(minutes: 5),
        completed: true,
      ),
      growable: false,
    ),
  );
}

ClinicalLongFormTranscriptAssembly _completeTranscript() {
  return const ClinicalLongFormTranscriptAssembly(
    text: 'Aula sobre insuficiência cardíaca. '
        'Fração de ejeção reduzida e tratamento.',
    segmentCount: 2,
    expectedSegmentCount: 2,
    complete: true,
  );
}

final class _CountingCleanup implements ClinicalLongFormAudioCleanup {
  _CountingCleanup({
    this.shouldFail = false,
  });

  final bool shouldFail;
  int calls = 0;

  @override
  Future<ClinicalLongFormAudioCleanupReport> deleteCompletedAudio(
    ClinicalLongFormRecordingManifest manifest,
  ) async {
    calls++;

    if (shouldFail) {
      throw StateError('synthetic cleanup failure');
    }

    return ClinicalLongFormAudioCleanupReport(
      expectedFiles: manifest.segments.length,
      deletedFiles: manifest.segments.length,
      alreadyMissingFiles: 0,
    );
  }
}

void main() {
  test('transcription completion alone can never delete audio', () async {
    final lifecycle = ClinicalLongFormReviewLifecycle();
    final cleanup = _CountingCleanup();
    final manifest = _manifest(
      paths: const <String>[
        '/local/segment_000.m4a',
        '/local/segment_001.m4a',
      ],
    );

    expect(
      lifecycle.defaultDisposition,
      ClinicalLongFormAudioDisposition.deleteAfterReview,
    );

    lifecycle.acceptCompletedTranscript(_completeTranscript());

    expect(
      lifecycle.state,
      ClinicalLongFormReviewLifecycleState.readyForReview,
    );
    expect(lifecycle.canDeleteAudio, isFalse);

    await expectLater(
      () => lifecycle.executeConfirmedDeletion(
        manifest: manifest,
        cleanup: cleanup,
      ),
      throwsStateError,
    );

    expect(cleanup.calls, 0);
  });

  test('confirmed review plus keep audio permanently blocks cleanup', () async {
    final lifecycle = ClinicalLongFormReviewLifecycle();
    final cleanup = _CountingCleanup();
    final manifest = _manifest(
      paths: const <String>[
        '/local/segment_000.m4a',
      ],
    );

    lifecycle.acceptCompletedTranscript(_completeTranscript());
    lifecycle.confirmUserReview(
      reviewedTranscript: 'Aula revisada sobre insuficiência cardíaca.',
    );
    lifecycle.confirmAudioDisposition(
      ClinicalLongFormAudioDisposition.keepAudio,
    );

    expect(
      lifecycle.state,
      ClinicalLongFormReviewLifecycleState.keepConfirmed,
    );
    expect(lifecycle.audioRetentionFinalized, isTrue);
    expect(lifecycle.canDeleteAudio, isFalse);

    await expectLater(
      () => lifecycle.executeConfirmedDeletion(
        manifest: manifest,
        cleanup: cleanup,
      ),
      throwsStateError,
    );

    expect(cleanup.calls, 0);
  });

  test('confirmed review plus delete executes cleanup exactly once', () async {
    final lifecycle = ClinicalLongFormReviewLifecycle();
    final cleanup = _CountingCleanup();
    final manifest = _manifest(
      paths: const <String>[
        '/local/segment_000.m4a',
        '/local/segment_001.m4a',
      ],
    );

    lifecycle.acceptCompletedTranscript(_completeTranscript());
    lifecycle.confirmUserReview(
      reviewedTranscript: 'Aula revisada sobre insuficiência cardíaca.',
    );
    lifecycle.confirmAudioDisposition(
      ClinicalLongFormAudioDisposition.deleteAfterReview,
    );

    expect(lifecycle.canDeleteAudio, isTrue);

    final report = await lifecycle.executeConfirmedDeletion(
      manifest: manifest,
      cleanup: cleanup,
    );

    expect(report.complete, isTrue);
    expect(cleanup.calls, 1);
    expect(
      lifecycle.state,
      ClinicalLongFormReviewLifecycleState.audioDeleted,
    );
    expect(lifecycle.audioRetentionFinalized, isTrue);
  });

  test('cleanup failure is explicit and can be retried', () async {
    final lifecycle = ClinicalLongFormReviewLifecycle();
    final failing = _CountingCleanup(shouldFail: true);
    final succeeding = _CountingCleanup();
    final manifest = _manifest(
      paths: const <String>[
        '/local/segment_000.m4a',
      ],
    );

    lifecycle.acceptCompletedTranscript(_completeTranscript());
    lifecycle.confirmUserReview(
      reviewedTranscript: 'Transcrição revisada.',
    );
    lifecycle.confirmAudioDisposition(
      ClinicalLongFormAudioDisposition.deleteAfterReview,
    );

    await expectLater(
      () => lifecycle.executeConfirmedDeletion(
        manifest: manifest,
        cleanup: failing,
      ),
      throwsStateError,
    );

    expect(
      lifecycle.state,
      ClinicalLongFormReviewLifecycleState.deletionFailed,
    );
    expect(
      lifecycle.lastDeletionErrorCode,
      'local_audio_cleanup_failed',
    );
    expect(lifecycle.canDeleteAudio, isTrue);

    final report = await lifecycle.executeConfirmedDeletion(
      manifest: manifest,
      cleanup: succeeding,
    );

    expect(report.complete, isTrue);
    expect(
      lifecycle.state,
      ClinicalLongFormReviewLifecycleState.audioDeleted,
    );
  });

  test('real local cleanup deletes only manifest M4A files inside root',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_audio_cleanup_',
    );

    try {
      final sessionDir = Directory(
        '${root.path}${Platform.pathSeparator}lecture_review_001',
      );
      await sessionDir.create(recursive: true);

      final first = File(
        '${sessionDir.path}${Platform.pathSeparator}segment_000.m4a',
      );
      final second = File(
        '${sessionDir.path}${Platform.pathSeparator}segment_001.m4a',
      );
      final keep = File(
        '${sessionDir.path}${Platform.pathSeparator}notes.txt',
      );

      await first.writeAsBytes(<int>[1, 2, 3], flush: true);
      await second.writeAsBytes(<int>[4, 5, 6], flush: true);
      await keep.writeAsString('preserve', flush: true);

      final cleanup = FileClinicalLongFormAudioCleanup(
        allowedRootDirectory: root,
      );

      final report = await cleanup.deleteCompletedAudio(
        _manifest(
          paths: <String>[
            first.path,
            second.path,
          ],
        ),
      );

      expect(report.expectedFiles, 2);
      expect(report.deletedFiles, 2);
      expect(report.alreadyMissingFiles, 0);
      expect(await first.exists(), isFalse);
      expect(await second.exists(), isFalse);
      expect(await keep.exists(), isTrue);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('local cleanup is idempotent for already missing audio', () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_audio_cleanup_missing_',
    );

    try {
      final missingPath = '${root.path}${Platform.pathSeparator}missing.m4a';

      final cleanup = FileClinicalLongFormAudioCleanup(
        allowedRootDirectory: root,
      );

      final report = await cleanup.deleteCompletedAudio(
        _manifest(paths: <String>[missingPath]),
      );

      expect(report.expectedFiles, 1);
      expect(report.deletedFiles, 0);
      expect(report.alreadyMissingFiles, 1);
      expect(report.complete, isTrue);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('cleanup rejects an existing M4A outside the allowed root', () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_audio_cleanup_root_',
    );
    final outside = await Directory.systemTemp.createTemp(
      'medcases_audio_cleanup_outside_',
    );

    try {
      final outsideFile = File(
        '${outside.path}${Platform.pathSeparator}segment_000.m4a',
      );
      await outsideFile.writeAsBytes(<int>[1], flush: true);

      final cleanup = FileClinicalLongFormAudioCleanup(
        allowedRootDirectory: root,
      );

      await expectLater(
        () => cleanup.deleteCompletedAudio(
          _manifest(paths: <String>[outsideFile.path]),
        ),
        throwsStateError,
      );

      expect(await outsideFile.exists(), isTrue);
    } finally {
      await root.delete(recursive: true);
      await outside.delete(recursive: true);
    }
  });

  test('review lifecycle remains isolated with no network or transcript disk',
      () {
    final source = <String>[
      File(
        'lib/services/audio/'
        'clinical_long_form_review_lifecycle.dart',
      ).readAsStringSync(),
      File(
        'lib/services/audio/'
        'clinical_long_form_local_audio_cleanup.dart',
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
      'writeAsString',
      'writeAsBytes',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }

    expect(
      source,
      contains('autoDeleteWithoutUserConfirmation = false'),
    );
    expect(
      source,
      contains('transcriptPersistenceEnabled = false'),
    );
    expect(
      source,
      contains('automaticDeleteEnabledInProduction = false'),
    );

    final main = File('lib/main.dart').readAsStringSync();
    final recorder =
        File('lib/services/clinical_recorder_service.dart').readAsStringSync();
    final history = File('lib/screens/history_screen.dart').readAsStringSync();

    expect(
      main,
      isNot(contains('ClinicalLongFormReviewLifecycle')),
    );
    expect(
      recorder,
      isNot(contains('ClinicalLongFormReviewLifecycle')),
    );
    expect(
      history,
      isNot(contains('ClinicalLongFormReviewLifecycle')),
    );
  });
}
