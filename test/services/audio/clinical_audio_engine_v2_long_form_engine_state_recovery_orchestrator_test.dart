import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_long_form_audio_contract.dart';
import 'package:medcases/services/audio/clinical_long_form_batch_transcription_provider.dart';
import 'package:medcases/services/audio/clinical_long_form_batch_transcription_queue.dart';
import 'package:medcases/services/audio/clinical_long_form_checkpointed_batch_runner.dart';
import 'package:medcases/services/audio/clinical_long_form_durable_store.dart';
import 'package:medcases/services/audio/clinical_long_form_engine_state_recovery_orchestrator.dart';
import 'package:medcases/services/audio/clinical_long_form_recording_manifest.dart';
import 'package:medcases/services/audio/clinical_long_form_review_lifecycle.dart';
import 'package:medcases/services/audio/clinical_long_form_reviewed_transcript_artifact.dart';
import 'package:medcases/services/audio/clinical_long_form_segment_transcript_checkpoint.dart';
import 'package:medcases/services/audio/clinical_long_form_segment_transcript_checkpoint_store.dart';
import 'package:medcases/services/audio/clinical_long_form_transcript_assembler.dart';

ClinicalLongFormRecordingManifest _manifest({
  ClinicalLongFormRecordingState state = ClinicalLongFormRecordingState.stopped,
}) {
  return ClinicalLongFormRecordingManifest(
    sessionId: 'lecture_recovery_001',
    locale: 'pt-BR',
    state: state,
    createdAtUtc: DateTime.utc(2026, 8, 19, 10),
    totalActiveDuration: const Duration(minutes: 10),
    segments: <ClinicalLongFormSegmentManifest>[
      ClinicalLongFormSegmentManifest(
        index: 0,
        path: '/local/segment_000.m4a',
        startedAtUtc: DateTime.utc(2026, 8, 19, 10),
        activeDuration: const Duration(minutes: 5),
        completed: true,
      ),
      ClinicalLongFormSegmentManifest(
        index: 1,
        path: '/local/segment_001.m4a',
        startedAtUtc: DateTime.utc(2026, 8, 19, 10, 5),
        activeDuration: const Duration(minutes: 5),
        completed: state == ClinicalLongFormRecordingState.stopped,
      ),
    ],
  );
}

final class _MemoryCheckpointStore
    implements ClinicalLongFormSegmentTranscriptCheckpointStore {
  final Map<int, ClinicalLongFormSegmentTranscriptCheckpoint> values =
      <int, ClinicalLongFormSegmentTranscriptCheckpoint>{};

  @override
  Future<void> save(
    ClinicalLongFormSegmentTranscriptCheckpoint checkpoint,
  ) async {
    values[checkpoint.segmentIndex] = checkpoint;
  }

  @override
  Future<ClinicalLongFormSegmentTranscriptCheckpoint?> load(
    String sessionId,
    int segmentIndex,
  ) async {
    final value = values[segmentIndex];
    if (value?.sessionId != sessionId) {
      return null;
    }
    return value;
  }

  @override
  Future<List<ClinicalLongFormSegmentTranscriptCheckpoint>> loadAll(
    String sessionId,
  ) async {
    final result = values.values
        .where((value) => value.sessionId == sessionId)
        .toList(growable: false)
      ..sort((a, b) => a.segmentIndex.compareTo(b.segmentIndex));
    return result;
  }
}

final class _MemoryDurableStore implements ClinicalLongFormDurableStore {
  final List<ClinicalLongFormBatchQueue> queueWrites =
      <ClinicalLongFormBatchQueue>[];

  @override
  Future<ClinicalLongFormRecordingManifest?> loadManifest(
    String sessionId,
  ) async =>
      null;

  @override
  Future<ClinicalLongFormBatchQueue?> loadBatchQueue(
    String sessionId,
  ) async =>
      queueWrites.isEmpty ? null : queueWrites.last;

  @override
  Future<void> saveManifest(
    ClinicalLongFormRecordingManifest manifest,
  ) async {}

  @override
  Future<void> saveBatchQueue(
    ClinicalLongFormBatchQueue queue,
  ) async {
    queueWrites.add(
      ClinicalLongFormBatchQueue.fromJson(queue.toJson()),
    );
  }
}

final class _SinglePassProvider
    implements ClinicalLongFormBatchTranscriptionProvider {
  @override
  String get providerId => 'single_pass_fake';

  @override
  Future<ClinicalLongFormBatchTranscriptionResult> transcribeSegment(
    ClinicalLongFormBatchTranscriptionRequest request,
  ) async {
    return ClinicalLongFormBatchTranscriptionResult(
      segmentIndex: request.segmentIndex,
      deduplicationKey: request.deduplicationKey,
      transcript: 'Texto do segmento ${request.segmentIndex}.',
      resultRef: 'memory://${request.segmentIndex}',
    );
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  test('checkpoint JSON store survives primary corruption through backup',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_segment_checkpoint_',
    );

    try {
      final store = FileClinicalLongFormSegmentTranscriptCheckpointStore(
        rootDirectory: root,
      );

      final first = ClinicalLongFormSegmentTranscriptCheckpoint(
        sessionId: 'lecture_recovery_001',
        segmentIndex: 0,
        deduplicationKey: 'lecture_recovery_001:segment:0',
        transcript: 'Primeira versão.',
        resultRef: 'local://first',
        completedAtUtc: DateTime.utc(2026, 8, 19, 12),
      );

      final second = ClinicalLongFormSegmentTranscriptCheckpoint(
        sessionId: 'lecture_recovery_001',
        segmentIndex: 0,
        deduplicationKey: 'lecture_recovery_001:segment:0',
        transcript: 'Segunda versão.',
        resultRef: 'local://second',
        completedAtUtc: DateTime.utc(2026, 8, 19, 12, 1),
      );

      await store.save(first);
      await store.save(second);

      final primary = File(
        '${root.path}${Platform.pathSeparator}'
        'lecture_recovery_001${Platform.pathSeparator}'
        'segment_transcripts${Platform.pathSeparator}'
        'segment_00000.json',
      );

      await primary.writeAsString('{corrupt', flush: true);

      final recovered = await store.load(
        'lecture_recovery_001',
        0,
      );

      expect(recovered, isNotNull);
      expect(recovered!.transcript, 'Primeira versão.');
      expect(recovered.resultRef, 'local://first');
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('checkpoint wins after crash between checkpoint and queue completion',
      () async {
    final manifest = _manifest();
    final queue = ClinicalLongFormBatchQueue.fromManifest(manifest);
    final claimed = queue.claimNext()!;

    expect(
      claimed.status,
      ClinicalLongFormBatchItemStatus.processing,
    );

    final checkpointStore = _MemoryCheckpointStore();
    await checkpointStore.save(
      ClinicalLongFormSegmentTranscriptCheckpoint(
        sessionId: manifest.sessionId,
        segmentIndex: 0,
        deduplicationKey: claimed.deduplicationKey,
        transcript: 'Segmento zero recuperado.',
        resultRef: 'memory://0',
        completedAtUtc: DateTime.utc(2026, 8, 19, 12),
      ),
    );

    final orchestrator = ClinicalLongFormEngineStateRecoveryOrchestrator(
      checkpointStore: checkpointStore,
    );

    final recovered = await orchestrator.recoverBatch(
      manifest: manifest,
      queue: queue,
    );

    expect(recovered.promotedFromCheckpoint, 1);
    expect(recovered.requeuedInterruptedProcessing, 0);
    expect(
      recovered.queue.items[0].status,
      ClinicalLongFormBatchItemStatus.completed,
    );
    expect(recovered.queue.items[0].resultRef, 'memory://0');

    final partial = recovered.assembler.assemble(
      requireComplete: false,
    );
    expect(partial.text, 'Segmento zero recuperado.');
  });

  test('completed queue item without checkpoint is requeued, never trusted',
      () async {
    final manifest = _manifest();
    final queue = ClinicalLongFormBatchQueue.fromManifest(manifest);

    final first = queue.claimNext()!;
    queue.markCompleted(
      segmentIndex: first.segmentIndex,
      resultRef: 'opaque://lost-text',
    );

    final orchestrator = ClinicalLongFormEngineStateRecoveryOrchestrator(
      checkpointStore: _MemoryCheckpointStore(),
    );

    final recovered = await orchestrator.recoverBatch(
      manifest: manifest,
      queue: queue,
    );

    expect(recovered.requeuedMissingCheckpoint, 1);
    expect(
      recovered.queue.items[0].status,
      ClinicalLongFormBatchItemStatus.pending,
    );
    expect(recovered.queue.items[0].resultRef, isNull);
    expect(recovered.assembler.receivedSegmentCount, 0);
  });

  test('all checkpoints rebuild final transcript after process restart',
      () async {
    final manifest = _manifest();
    final originalQueue = ClinicalLongFormBatchQueue.fromManifest(manifest);
    final checkpointStore = _MemoryCheckpointStore();

    final items = <ClinicalLongFormBatchItem>[];

    for (final item in originalQueue.items) {
      await checkpointStore.save(
        ClinicalLongFormSegmentTranscriptCheckpoint(
          sessionId: manifest.sessionId,
          segmentIndex: item.segmentIndex,
          deduplicationKey: item.deduplicationKey,
          transcript: 'Segmento ${item.segmentIndex}.',
          resultRef: 'memory://${item.segmentIndex}',
          completedAtUtc: DateTime.utc(2026, 8, 19, 12).add(
            Duration(minutes: item.segmentIndex),
          ),
        ),
      );

      items.add(
        item.copyWith(
          status: ClinicalLongFormBatchItemStatus.completed,
          resultRef: 'memory://${item.segmentIndex}',
        ),
      );
    }

    final queue = ClinicalLongFormBatchQueue(
      sessionId: originalQueue.sessionId,
      maxAttempts: originalQueue.maxAttempts,
      items: items,
    );

    final orchestrator = ClinicalLongFormEngineStateRecoveryOrchestrator(
      checkpointStore: checkpointStore,
    );

    final recovered = await orchestrator.recoverBatch(
      manifest: manifest,
      queue: queue,
    );

    expect(recovered.queue.isComplete, isTrue);
    expect(recovered.assembler.isComplete, isTrue);
    expect(
      recovered.assembler.assemble().text,
      'Segmento 0.\n\nSegmento 1.',
    );
  });

  test('checkpointed runner persists checkpoint before completed queue state',
      () async {
    final manifest = _manifest();
    final queue = ClinicalLongFormBatchQueue.fromManifest(manifest);
    final assembler = ClinicalLongFormTranscriptAssembler(
      expectedSegmentCount: queue.totalCount,
    );
    final durableStore = _MemoryDurableStore();
    final checkpointStore = _MemoryCheckpointStore();

    final runner = ClinicalLongFormCheckpointedBatchRunner(
      queue: queue,
      provider: _SinglePassProvider(),
      assembler: assembler,
      durableStore: durableStore,
      checkpointStore: checkpointStore,
      locale: 'pt-BR',
      nowUtc: () => DateTime.utc(2026, 8, 19, 12),
    );

    final outcome = await runner.runUntilBlocked();

    expect(outcome.completed, 2);
    expect(queue.isComplete, isTrue);
    expect(checkpointStore.values.length, 2);
    expect(durableStore.queueWrites, isNotEmpty);
    expect(
      durableStore.queueWrites.last.isComplete,
      isTrue,
    );
    expect(assembler.isComplete, isTrue);

    await runner.dispose();
  });

  test('recovery next action follows recording and retention states', () {
    final orchestrator = ClinicalLongFormEngineStateRecoveryOrchestrator(
      checkpointStore: _MemoryCheckpointStore(),
    );

    expect(
      orchestrator.decideNextAction(
        manifest: _manifest(
          state: ClinicalLongFormRecordingState.recording,
        ),
        queue: null,
        reviewedArtifact: null,
      ),
      ClinicalLongFormEngineRecoveryAction.resumeRecordingAsNewSegment,
    );

    expect(
      orchestrator.decideNextAction(
        manifest: _manifest(),
        queue: null,
        reviewedArtifact: null,
      ),
      ClinicalLongFormEngineRecoveryAction.createBatchQueue,
    );

    final deletedArtifact = ClinicalLongFormReviewedTranscriptArtifact(
      sessionId: 'lecture_recovery_001',
      locale: 'pt-BR',
      reviewedTranscript: 'Texto aprovado.',
      reviewedAtUtc: DateTime.utc(2026, 8, 19, 12),
      sourceSegmentCount: 2,
      sourceActiveDuration: const Duration(minutes: 10),
      retentionState: ClinicalLongFormAudioRetentionState.audioDeleted,
      audioDisposition: ClinicalLongFormAudioDisposition.deleteAfterReview,
    );

    expect(
      orchestrator.decideNextAction(
        manifest: _manifest(),
        queue: null,
        reviewedArtifact: deletedArtifact,
      ),
      ClinicalLongFormEngineRecoveryAction.finalizedAudioDeleted,
    );
  });

  test('recovery/checkpoint layer has zero network and no production cutover',
      () {
    final source = <String>[
      File(
        'lib/services/audio/'
        'clinical_long_form_segment_transcript_checkpoint.dart',
      ).readAsStringSync(),
      File(
        'lib/services/audio/'
        'clinical_long_form_segment_transcript_checkpoint_store.dart',
      ).readAsStringSync(),
      File(
        'lib/services/audio/'
        'clinical_long_form_checkpointed_batch_runner.dart',
      ).readAsStringSync(),
      File(
        'lib/services/audio/'
        'clinical_long_form_engine_state_recovery_orchestrator.dart',
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
      'patientName',
      'patientDocument',
      'patientCpf',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }

    expect(
      source,
      contains('checkpointBeforeQueueCompletion = true'),
    );
    expect(
      source,
      contains('completedWithoutCheckpointAllowed = false'),
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
      isNot(contains('ClinicalLongFormCheckpointedBatchRunner')),
    );
    expect(
      recorder,
      isNot(contains('ClinicalLongFormCheckpointedBatchRunner')),
    );
    expect(
      history,
      isNot(contains(
        'ClinicalLongFormEngineStateRecoveryOrchestrator',
      )),
    );
  });
}
