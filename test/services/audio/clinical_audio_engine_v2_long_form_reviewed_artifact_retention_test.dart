import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_long_form_audio_contract.dart';
import 'package:medcases/services/audio/clinical_long_form_local_audio_cleanup.dart';
import 'package:medcases/services/audio/clinical_long_form_recording_manifest.dart';
import 'package:medcases/services/audio/clinical_long_form_retention_finalizer.dart';
import 'package:medcases/services/audio/clinical_long_form_review_lifecycle.dart';
import 'package:medcases/services/audio/clinical_long_form_reviewed_artifact_store.dart';
import 'package:medcases/services/audio/clinical_long_form_reviewed_transcript_artifact.dart';
import 'package:medcases/services/audio/clinical_long_form_transcript_assembler.dart';

ClinicalLongFormRecordingManifest _manifest({
  required List<String> paths,
}) {
  return ClinicalLongFormRecordingManifest(
    sessionId: 'lecture_final_001',
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

ClinicalLongFormReviewLifecycle _reviewedLifecycle() {
  final lifecycle = ClinicalLongFormReviewLifecycle();

  lifecycle.acceptCompletedTranscript(
    const ClinicalLongFormTranscriptAssembly(
      text: 'Aula sobre insuficiência cardíaca. '
          'Ceftriaxona 2 g foi citada como exemplo.',
      segmentCount: 2,
      expectedSegmentCount: 2,
      complete: true,
    ),
  );

  lifecycle.confirmUserReview(
    reviewedTranscript: 'Aula revisada sobre insuficiência cardíaca. '
        'Ceftriaxona 2 g foi citada como exemplo.',
  );

  return lifecycle;
}

final class _RecordingArtifactStore
    implements ClinicalLongFormReviewedArtifactStore {
  final List<ClinicalLongFormReviewedTranscriptArtifact> writes =
      <ClinicalLongFormReviewedTranscriptArtifact>[];

  @override
  Future<void> save(
    ClinicalLongFormReviewedTranscriptArtifact artifact,
  ) async {
    writes.add(artifact);
  }

  @override
  Future<ClinicalLongFormReviewedTranscriptArtifact?> load(
    String sessionId,
  ) async {
    for (var i = writes.length - 1; i >= 0; i--) {
      if (writes[i].sessionId == sessionId) {
        return writes[i];
      }
    }
    return null;
  }
}

final class _OrderAwareCleanup implements ClinicalLongFormAudioCleanup {
  _OrderAwareCleanup({
    required this.store,
    this.shouldFail = false,
  });

  final _RecordingArtifactStore store;
  final bool shouldFail;

  @override
  Future<ClinicalLongFormAudioCleanupReport> deleteCompletedAudio(
    ClinicalLongFormRecordingManifest manifest,
  ) async {
    if (store.writes.isEmpty) {
      throw StateError('cleanup called before durable transcript');
    }

    final latest = store.writes.last;
    if (latest.reviewedTranscript.trim().isEmpty) {
      throw StateError('durable transcript is empty');
    }
    if (latest.retentionState !=
        ClinicalLongFormAudioRetentionState.deletePending) {
      throw StateError('delete intent not durable before cleanup');
    }

    if (shouldFail) {
      throw StateError('synthetic delete failure');
    }

    return ClinicalLongFormAudioCleanupReport(
      expectedFiles: manifest.segments.length,
      deletedFiles: manifest.segments.length,
      alreadyMissingFiles: 0,
    );
  }
}

void main() {
  test('reviewed artifact JSON round-trip preserves approved text', () {
    final artifact = ClinicalLongFormReviewedTranscriptArtifact(
      sessionId: 'lecture_final_001',
      locale: 'pt-BR',
      reviewedTranscript: 'Ceftriaxona 2 g intravenosa.',
      reviewedAtUtc: DateTime.utc(2026, 8, 19, 11),
      sourceSegmentCount: 3,
      sourceActiveDuration: const Duration(minutes: 13),
      retentionState: ClinicalLongFormAudioRetentionState.reviewedPersisted,
      audioDisposition: null,
    );

    final decoded = ClinicalLongFormReviewedTranscriptArtifact.fromJson(
      (jsonDecode(jsonEncode(artifact.toJson())) as Map<String, dynamic>)
          .cast<String, Object?>(),
    );

    expect(decoded.sessionId, artifact.sessionId);
    expect(decoded.locale, artifact.locale);
    expect(decoded.reviewedTranscript, artifact.reviewedTranscript);
    expect(decoded.sourceSegmentCount, 3);
    expect(decoded.sourceActiveDuration, const Duration(minutes: 13));
    expect(
      decoded.retentionState,
      ClinicalLongFormAudioRetentionState.reviewedPersisted,
    );
  });

  test('keep audio persists reviewed text then final keep metadata', () async {
    final store = _RecordingArtifactStore();
    final lifecycle = _reviewedLifecycle();
    final finalizer = ClinicalLongFormRetentionFinalizer(
      artifactStore: store,
    );
    final manifest = _manifest(
      paths: const <String>[
        '/local/a.m4a',
        '/local/b.m4a',
      ],
    );

    final result = await finalizer.finalize(
      lifecycle: lifecycle,
      manifest: manifest,
      disposition: ClinicalLongFormAudioDisposition.keepAudio,
      cleanup: _OrderAwareCleanup(store: store),
      reviewedAtUtc: DateTime.utc(2026, 8, 19, 12),
    );

    expect(store.writes, hasLength(2));
    expect(
      store.writes[0].retentionState,
      ClinicalLongFormAudioRetentionState.reviewedPersisted,
    );
    expect(
      store.writes[1].retentionState,
      ClinicalLongFormAudioRetentionState.keepAudio,
    );
    expect(
      result.artifact.audioDisposition,
      ClinicalLongFormAudioDisposition.keepAudio,
    );
    expect(result.cleanupReport, isNull);
  });

  test('delete path persists text and delete intent before cleanup', () async {
    final store = _RecordingArtifactStore();
    final lifecycle = _reviewedLifecycle();
    final finalizer = ClinicalLongFormRetentionFinalizer(
      artifactStore: store,
    );
    final manifest = _manifest(
      paths: const <String>[
        '/local/a.m4a',
        '/local/b.m4a',
      ],
    );

    final result = await finalizer.finalize(
      lifecycle: lifecycle,
      manifest: manifest,
      disposition: ClinicalLongFormAudioDisposition.deleteAfterReview,
      cleanup: _OrderAwareCleanup(store: store),
      reviewedAtUtc: DateTime.utc(2026, 8, 19, 12),
    );

    expect(store.writes, hasLength(3));
    expect(
      store.writes[0].retentionState,
      ClinicalLongFormAudioRetentionState.reviewedPersisted,
    );
    expect(
      store.writes[1].retentionState,
      ClinicalLongFormAudioRetentionState.deletePending,
    );
    expect(
      store.writes[2].retentionState,
      ClinicalLongFormAudioRetentionState.audioDeleted,
    );
    expect(result.cleanupReport, isNotNull);
    expect(result.cleanupReport!.complete, isTrue);
  });

  test('failed delete keeps durable transcript and retry metadata', () async {
    final store = _RecordingArtifactStore();
    final lifecycle = _reviewedLifecycle();
    final finalizer = ClinicalLongFormRetentionFinalizer(
      artifactStore: store,
    );
    final manifest = _manifest(
      paths: const <String>[
        '/local/a.m4a',
      ],
    );

    await expectLater(
      () => finalizer.finalize(
        lifecycle: lifecycle,
        manifest: manifest,
        disposition: ClinicalLongFormAudioDisposition.deleteAfterReview,
        cleanup: _OrderAwareCleanup(
          store: store,
          shouldFail: true,
        ),
        reviewedAtUtc: DateTime.utc(2026, 8, 19, 12),
      ),
      throwsStateError,
    );

    expect(store.writes.length, greaterThanOrEqualTo(3));
    expect(
      store.writes.first.retentionState,
      ClinicalLongFormAudioRetentionState.reviewedPersisted,
    );
    expect(
      store.writes.last.retentionState,
      ClinicalLongFormAudioRetentionState.deletionFailed,
    );
    expect(
      store.writes.last.lastCleanupErrorCode,
      'local_audio_cleanup_failed',
    );
    expect(
      store.writes.last.reviewedTranscript,
      contains('Ceftriaxona 2 g'),
    );
  });

  test('file artifact store survives primary corruption via backup', () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_reviewed_artifact_',
    );

    try {
      final store = FileClinicalLongFormReviewedArtifactStore(
        rootDirectory: root,
      );

      final first = ClinicalLongFormReviewedTranscriptArtifact(
        sessionId: 'lecture_final_001',
        locale: 'pt-BR',
        reviewedTranscript: 'Primeira versão revisada.',
        reviewedAtUtc: DateTime.utc(2026, 8, 19, 12),
        sourceSegmentCount: 2,
        sourceActiveDuration: const Duration(minutes: 10),
        retentionState: ClinicalLongFormAudioRetentionState.reviewedPersisted,
        audioDisposition: null,
      );

      final second = first.copyWith(
        retentionState: ClinicalLongFormAudioRetentionState.keepAudio,
        audioDisposition: ClinicalLongFormAudioDisposition.keepAudio,
      );

      await store.save(first);
      await store.save(second);

      final primary = File(
        '${root.path}${Platform.pathSeparator}'
        'lecture_final_001${Platform.pathSeparator}'
        'reviewed_transcript.json',
      );

      await primary.writeAsString('{corrupted-json', flush: true);

      final recovered = await store.load('lecture_final_001');

      expect(recovered, isNotNull);
      expect(recovered!.reviewedTranscript, 'Primeira versão revisada.');
      expect(
        recovered.retentionState,
        ClinicalLongFormAudioRetentionState.reviewedPersisted,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('reviewed artifact contains no audio bytes or patient identity fields',
      () {
    final source = <String>[
      File(
        'lib/services/audio/'
        'clinical_long_form_reviewed_transcript_artifact.dart',
      ).readAsStringSync(),
      File(
        'lib/services/audio/'
        'clinical_long_form_reviewed_artifact_store.dart',
      ).readAsStringSync(),
      File(
        'lib/services/audio/'
        'clinical_long_form_retention_finalizer.dart',
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
      'Uint8List',
      'readAsBytes',
      'writeAsBytes',
      'patientName',
      'patientDocument',
      'patientCpf',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }

    expect(
      source,
      contains('deleteBeforeDurableTranscriptAllowed = false'),
    );
    expect(
      source,
      contains('audioBytesPersistenceEnabled = false'),
    );
    expect(
      source,
      contains('cloudSyncEnabled = false'),
    );

    final main = File('lib/main.dart').readAsStringSync();
    final recorder =
        File('lib/services/clinical_recorder_service.dart').readAsStringSync();
    final history = File('lib/screens/history_screen.dart').readAsStringSync();

    expect(
      main,
      isNot(contains('ClinicalLongFormRetentionFinalizer')),
    );
    expect(
      recorder,
      isNot(contains('ClinicalLongFormRetentionFinalizer')),
    );
    expect(
      history,
      isNot(contains('ClinicalLongFormReviewedTranscriptArtifact')),
    );
  });
}
