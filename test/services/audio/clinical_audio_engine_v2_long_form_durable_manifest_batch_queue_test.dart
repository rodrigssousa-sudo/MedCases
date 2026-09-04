import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_long_form_audio_contract.dart';
import 'package:medcases/services/audio/clinical_long_form_batch_transcription_queue.dart';
import 'package:medcases/services/audio/clinical_long_form_durable_store.dart';
import 'package:medcases/services/audio/clinical_long_form_recording_manifest.dart';

ClinicalLongFormRecordingManifest _manifest({
  String sessionId = 'lecture_001',
  ClinicalLongFormRecordingState state = ClinicalLongFormRecordingState.stopped,
}) {
  return ClinicalLongFormRecordingManifest(
    sessionId: sessionId,
    locale: 'pt-BR',
    state: state,
    createdAtUtc: DateTime.utc(2026, 8, 19, 10),
    totalActiveDuration: const Duration(minutes: 13),
    segments: <ClinicalLongFormSegmentManifest>[
      ClinicalLongFormSegmentManifest(
        index: 0,
        path: '/local/lecture_001_000.m4a',
        startedAtUtc: DateTime.utc(2026, 8, 19, 10),
        activeDuration: const Duration(minutes: 5),
        completed: true,
      ),
      ClinicalLongFormSegmentManifest(
        index: 1,
        path: '/local/lecture_001_001.m4a',
        startedAtUtc: DateTime.utc(2026, 8, 19, 10, 5),
        activeDuration: const Duration(minutes: 5),
        completed: true,
      ),
      ClinicalLongFormSegmentManifest(
        index: 2,
        path: '/local/lecture_001_002.m4a',
        startedAtUtc: DateTime.utc(2026, 8, 19, 10, 10),
        activeDuration: const Duration(minutes: 3),
        completed: state == ClinicalLongFormRecordingState.stopped,
      ),
    ],
  );
}

void main() {
  test('batch queue uses only completed segments in index order', () {
    final liveManifest = _manifest(
      state: ClinicalLongFormRecordingState.recording,
    );

    final queue = ClinicalLongFormBatchQueue.fromManifest(liveManifest);

    expect(queue.items, hasLength(2));
    expect(
      queue.items.map((item) => item.segmentIndex),
      <int>[0, 1],
    );
    expect(
      queue.items[0].deduplicationKey,
      'lecture_001:segment:0',
    );
    expect(
      queue.items[1].deduplicationKey,
      'lecture_001:segment:1',
    );
    expect(queue.progress, 0);
  });

  test('claim complete retry flow is deterministic and ordered', () {
    final queue = ClinicalLongFormBatchQueue.fromManifest(_manifest());

    final first = queue.claimNext()!;
    expect(first.segmentIndex, 0);
    expect(first.attempts, 1);
    expect(first.status, ClinicalLongFormBatchItemStatus.processing);

    queue.markCompleted(
      segmentIndex: 0,
      resultRef: 'local-result://segment-0',
    );

    final second = queue.claimNext()!;
    expect(second.segmentIndex, 1);
    expect(second.attempts, 1);

    queue.markFailed(
      segmentIndex: 1,
      errorCode: 'temporary_failure',
    );

    final retry = queue.claimNext()!;
    expect(retry.segmentIndex, 1);
    expect(retry.attempts, 2);
    expect(
      retry.deduplicationKey,
      'lecture_001:segment:1',
    );

    queue.markCompleted(
      segmentIndex: 1,
      resultRef: 'local-result://segment-1',
    );

    final third = queue.claimNext()!;
    expect(third.segmentIndex, 2);
    expect(third.attempts, 1);

    queue.markCompleted(
      segmentIndex: 2,
      resultRef: 'local-result://segment-2',
    );

    expect(queue.claimNext(), isNull);
    expect(queue.completedCount, 3);
    expect(queue.progress, 1);
    expect(queue.isComplete, isTrue);
  });

  test('processing item is safely requeued after simulated crash', () {
    final queue = ClinicalLongFormBatchQueue.fromManifest(_manifest());

    final first = queue.claimNext()!;
    expect(first.segmentIndex, 0);
    expect(first.attempts, 1);

    final encoded = jsonEncode(queue.toJson());
    final recovered = ClinicalLongFormBatchQueue.fromJson(
      (jsonDecode(encoded) as Map<String, dynamic>).cast<String, Object?>(),
    );

    expect(
      recovered.items.first.status,
      ClinicalLongFormBatchItemStatus.processing,
    );

    final count = recovered.recoverInterruptedProcessing();

    expect(count, 1);
    expect(
      recovered.items.first.status,
      ClinicalLongFormBatchItemStatus.pending,
    );
    expect(recovered.items.first.attempts, 1);

    final reclaimed = recovered.claimNext()!;
    expect(reclaimed.segmentIndex, 0);
    expect(reclaimed.attempts, 2);
    expect(
      reclaimed.deduplicationKey,
      'lecture_001:segment:0',
    );
  });

  test('retry cap prevents infinite transcription loop', () {
    final queue = ClinicalLongFormBatchQueue.fromManifest(
      _manifest(),
      maxAttempts: 2,
    );

    var item = queue.claimNext()!;
    queue.markFailed(
      segmentIndex: item.segmentIndex,
      errorCode: 'temporary_failure',
    );

    item = queue.claimNext()!;
    expect(item.attempts, 2);
    queue.markFailed(
      segmentIndex: item.segmentIndex,
      errorCode: 'temporary_failure',
    );

    final next = queue.claimNext()!;
    expect(next.segmentIndex, 1);
    expect(queue.exhaustedCount, 1);
  });

  test('durable store round-trips manifest and queue locally', () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_long_form_store_',
    );

    try {
      final store = FileClinicalLongFormDurableStore(
        rootDirectory: root,
      );

      final manifest = _manifest();
      final queue = ClinicalLongFormBatchQueue.fromManifest(manifest);

      await store.saveManifest(manifest);
      await store.saveBatchQueue(queue);

      final loadedManifest = await store.loadManifest('lecture_001');
      final loadedQueue = await store.loadBatchQueue('lecture_001');

      expect(loadedManifest, isNotNull);
      expect(loadedManifest!.sessionId, 'lecture_001');
      expect(loadedManifest.segments, hasLength(3));

      expect(loadedQueue, isNotNull);
      expect(loadedQueue!.items, hasLength(3));
      expect(
        loadedQueue.items[2].deduplicationKey,
        'lecture_001:segment:2',
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('durable store falls back to previous-good backup', () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_long_form_backup_',
    );

    try {
      final store = FileClinicalLongFormDurableStore(
        rootDirectory: root,
      );

      final first = _manifest();
      await store.saveManifest(first);

      final second = ClinicalLongFormRecordingManifest(
        sessionId: 'lecture_001',
        locale: 'pt-BR',
        state: ClinicalLongFormRecordingState.stopped,
        createdAtUtc: first.createdAtUtc,
        totalActiveDuration: const Duration(minutes: 18),
        segments: first.segments,
      );

      await store.saveManifest(second);

      final sessionDir = Directory(
        '${root.path}${Platform.pathSeparator}lecture_001',
      );

      final primary = File(
        '${sessionDir.path}${Platform.pathSeparator}manifest.json',
      );

      await primary.writeAsString('{corrupted-json', flush: true);

      final recovered = await store.loadManifest('lecture_001');

      expect(recovered, isNotNull);
      expect(
        recovered!.totalActiveDuration,
        const Duration(minutes: 13),
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('unsafe session id is rejected before filesystem access', () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_long_form_safe_id_',
    );

    try {
      final store = FileClinicalLongFormDurableStore(
        rootDirectory: root,
      );

      expect(
        () => store.loadManifest('../escape'),
        throwsArgumentError,
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('durable layer persists no transcript and has zero network', () {
    final source = <String>[
      File(
        'lib/services/audio/'
        'clinical_long_form_durable_store.dart',
      ).readAsStringSync(),
      File(
        'lib/services/audio/'
        'clinical_long_form_batch_transcription_queue.dart',
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
      'transcriptText',
      'patientName',
      'patientDocument',
      'patientCpf',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }

    expect(
      source,
      contains('static const bool productionPersistenceEnabled = false'),
    );
    expect(
      source,
      contains('static const bool cloudSyncEnabled = false'),
    );
    expect(
      source,
      contains('static const bool transcriptPersistenceEnabled = false'),
    );

    final main = File('lib/main.dart').readAsStringSync();
    final recorder =
        File('lib/services/clinical_recorder_service.dart').readAsStringSync();
    final history = File('lib/screens/history_screen.dart').readAsStringSync();

    expect(
      main,
      isNot(contains('FileClinicalLongFormDurableStore')),
    );
    expect(
      recorder,
      isNot(contains('ClinicalLongFormBatchQueue')),
    );
    expect(
      history,
      isNot(contains('ClinicalLongFormBatchQueue')),
    );
  });
}
