import 'clinical_long_form_audio_contract.dart';
import 'clinical_long_form_batch_transcription_queue.dart';
import 'clinical_long_form_recording_manifest.dart';
import 'clinical_long_form_reviewed_transcript_artifact.dart';
import 'clinical_long_form_segment_transcript_checkpoint.dart';
import 'clinical_long_form_segment_transcript_checkpoint_store.dart';
import 'clinical_long_form_transcript_assembler.dart';

enum ClinicalLongFormEngineRecoveryAction {
  resumeRecordingAsNewSegment,
  createBatchQueue,
  resumeBatchTranscription,
  readyForReview,
  awaitAudioDisposition,
  retryAudioDeletion,
  finalizedKeepAudio,
  finalizedAudioDeleted,
}

final class ClinicalLongFormRecoveredBatchState {
  const ClinicalLongFormRecoveredBatchState({
    required this.queue,
    required this.assembler,
    required this.checkpointsLoaded,
    required this.promotedFromCheckpoint,
    required this.requeuedMissingCheckpoint,
    required this.requeuedInterruptedProcessing,
  });

  final ClinicalLongFormBatchQueue queue;
  final ClinicalLongFormTranscriptAssembler assembler;
  final int checkpointsLoaded;
  final int promotedFromCheckpoint;
  final int requeuedMissingCheckpoint;
  final int requeuedInterruptedProcessing;
}

final class ClinicalLongFormEngineStateRecoveryOrchestrator {
  ClinicalLongFormEngineStateRecoveryOrchestrator({
    required ClinicalLongFormSegmentTranscriptCheckpointStore checkpointStore,
  }) : _checkpointStore = checkpointStore;

  static const bool productionCutoverEnabled = false;
  static const bool remoteRecoveryEnabled = false;
  static const bool completedWithoutCheckpointAllowed = false;

  final ClinicalLongFormSegmentTranscriptCheckpointStore _checkpointStore;

  ClinicalLongFormEngineRecoveryAction decideNextAction({
    required ClinicalLongFormRecordingManifest manifest,
    required ClinicalLongFormBatchQueue? queue,
    required ClinicalLongFormReviewedTranscriptArtifact? reviewedArtifact,
  }) {
    if (reviewedArtifact != null) {
      switch (reviewedArtifact.retentionState) {
        case ClinicalLongFormAudioRetentionState.reviewedPersisted:
          return ClinicalLongFormEngineRecoveryAction.awaitAudioDisposition;
        case ClinicalLongFormAudioRetentionState.keepAudio:
          return ClinicalLongFormEngineRecoveryAction.finalizedKeepAudio;
        case ClinicalLongFormAudioRetentionState.deletePending:
        case ClinicalLongFormAudioRetentionState.deletionFailed:
          return ClinicalLongFormEngineRecoveryAction.retryAudioDeletion;
        case ClinicalLongFormAudioRetentionState.audioDeleted:
          return ClinicalLongFormEngineRecoveryAction.finalizedAudioDeleted;
      }
    }

    if (manifest.state == ClinicalLongFormRecordingState.recording ||
        manifest.state == ClinicalLongFormRecordingState.paused) {
      return ClinicalLongFormEngineRecoveryAction.resumeRecordingAsNewSegment;
    }

    if (manifest.state == ClinicalLongFormRecordingState.stopped) {
      if (queue == null) {
        return ClinicalLongFormEngineRecoveryAction.createBatchQueue;
      }
      if (queue.isComplete) {
        return ClinicalLongFormEngineRecoveryAction.readyForReview;
      }
      return ClinicalLongFormEngineRecoveryAction.resumeBatchTranscription;
    }

    return ClinicalLongFormEngineRecoveryAction.resumeRecordingAsNewSegment;
  }

  Future<ClinicalLongFormRecoveredBatchState> recoverBatch({
    required ClinicalLongFormRecordingManifest manifest,
    required ClinicalLongFormBatchQueue queue,
  }) async {
    if (manifest.sessionId != queue.sessionId) {
      throw StateError('Manifest/batch session mismatch.');
    }

    if (manifest.state != ClinicalLongFormRecordingState.stopped) {
      throw StateError(
        'Batch recovery requires stopped recording manifest.',
      );
    }

    final checkpoints = await _checkpointStore.loadAll(manifest.sessionId);

    final checkpointByIndex =
        <int, ClinicalLongFormSegmentTranscriptCheckpoint>{};

    for (final checkpoint in checkpoints) {
      if (checkpoint.sessionId != manifest.sessionId) {
        throw StateError('Checkpoint session mismatch.');
      }
      if (checkpoint.segmentIndex >= queue.totalCount) {
        throw StateError('Checkpoint index exceeds queue.');
      }

      final expectedKey = queue.items[checkpoint.segmentIndex].deduplicationKey;
      if (checkpoint.deduplicationKey != expectedKey) {
        throw StateError('Checkpoint deduplication mismatch.');
      }

      checkpointByIndex[checkpoint.segmentIndex] = checkpoint;
    }

    var promoted = 0;
    var requeuedMissing = 0;
    var requeuedProcessing = 0;

    final reconciledItems = <ClinicalLongFormBatchItem>[];

    for (final item in queue.items) {
      final checkpoint = checkpointByIndex[item.segmentIndex];

      if (checkpoint != null) {
        if (item.status != ClinicalLongFormBatchItemStatus.completed ||
            item.resultRef != checkpoint.resultRef) {
          promoted++;
        }

        reconciledItems.add(
          item.copyWith(
            status: ClinicalLongFormBatchItemStatus.completed,
            resultRef: checkpoint.resultRef,
            clearLastError: true,
          ),
        );
        continue;
      }

      if (item.status == ClinicalLongFormBatchItemStatus.completed) {
        requeuedMissing++;
        reconciledItems.add(
          item.copyWith(
            status: ClinicalLongFormBatchItemStatus.pending,
            clearResultRef: true,
            lastErrorCode: 'completed_missing_checkpoint_requeued',
          ),
        );
        continue;
      }

      if (item.status == ClinicalLongFormBatchItemStatus.processing) {
        requeuedProcessing++;
        reconciledItems.add(
          item.copyWith(
            status: ClinicalLongFormBatchItemStatus.pending,
            clearResultRef: true,
            lastErrorCode: 'interrupted_requeued',
          ),
        );
        continue;
      }

      reconciledItems.add(item);
    }

    final reconciledQueue = ClinicalLongFormBatchQueue(
      sessionId: queue.sessionId,
      maxAttempts: queue.maxAttempts,
      items: reconciledItems,
    );

    final assembler = ClinicalLongFormTranscriptAssembler(
      expectedSegmentCount: reconciledQueue.totalCount,
    );

    final orderedCheckpoints = checkpointByIndex.values.toList(growable: false)
      ..sort(
        (a, b) => a.segmentIndex.compareTo(b.segmentIndex),
      );

    for (final checkpoint in orderedCheckpoints) {
      assembler.accept(checkpoint.toBatchResult());
    }

    return ClinicalLongFormRecoveredBatchState(
      queue: reconciledQueue,
      assembler: assembler,
      checkpointsLoaded: orderedCheckpoints.length,
      promotedFromCheckpoint: promoted,
      requeuedMissingCheckpoint: requeuedMissing,
      requeuedInterruptedProcessing: requeuedProcessing,
    );
  }
}
