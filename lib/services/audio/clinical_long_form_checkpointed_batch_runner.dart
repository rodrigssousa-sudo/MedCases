import 'clinical_long_form_batch_transcription_provider.dart';
import 'clinical_long_form_batch_transcription_queue.dart';
import 'clinical_long_form_durable_store.dart';
import 'clinical_long_form_segment_transcript_checkpoint.dart';
import 'clinical_long_form_segment_transcript_checkpoint_store.dart';
import 'clinical_long_form_transcript_assembler.dart';

final class ClinicalLongFormCheckpointedBatchRunOutcome {
  const ClinicalLongFormCheckpointedBatchRunOutcome({
    required this.processed,
    required this.completed,
    required this.failed,
    required this.exhausted,
  });

  final int processed;
  final int completed;
  final int failed;
  final int exhausted;
}

/// Crash-safe batch ordering:
/// 1. claim item;
/// 2. persist queue processing state;
/// 3. provider result;
/// 4. persist segment transcript checkpoint;
/// 5. accept in assembler;
/// 6. mark queue completed;
/// 7. persist queue completed state.
///
/// Therefore after any crash the recovery orchestrator can reconcile
/// checkpoint-vs-queue without losing final segment text.
final class ClinicalLongFormCheckpointedBatchRunner {
  ClinicalLongFormCheckpointedBatchRunner({
    required ClinicalLongFormBatchQueue queue,
    required ClinicalLongFormBatchTranscriptionProvider provider,
    required ClinicalLongFormTranscriptAssembler assembler,
    required ClinicalLongFormDurableStore durableStore,
    required ClinicalLongFormSegmentTranscriptCheckpointStore checkpointStore,
    required String locale,
    DateTime Function()? nowUtc,
  })  : _queue = queue,
        _provider = provider,
        _assembler = assembler,
        _durableStore = durableStore,
        _checkpointStore = checkpointStore,
        _locale = locale.trim(),
        _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()) {
    if (_locale.isEmpty) {
      throw ArgumentError.value(locale, 'locale');
    }
    if (_assembler.expectedSegmentCount != _queue.totalCount) {
      throw StateError(
        'Assembler expected segment count must match queue.',
      );
    }
  }

  static const bool productionCutoverEnabled = false;
  static const bool remoteProviderImplemented = false;
  static const bool checkpointBeforeQueueCompletion = true;

  final ClinicalLongFormBatchQueue _queue;
  final ClinicalLongFormBatchTranscriptionProvider _provider;
  final ClinicalLongFormTranscriptAssembler _assembler;
  final ClinicalLongFormDurableStore _durableStore;
  final ClinicalLongFormSegmentTranscriptCheckpointStore _checkpointStore;
  final String _locale;
  final DateTime Function() _nowUtc;

  Future<ClinicalLongFormCheckpointedBatchRunOutcome> runUntilBlocked() async {
    var processed = 0;
    var completed = 0;
    var failed = 0;

    while (true) {
      final item = _queue.claimNext();
      if (item == null) {
        break;
      }

      processed++;
      await _durableStore.saveBatchQueue(_queue);

      final request = ClinicalLongFormBatchTranscriptionRequest(
        sessionId: _queue.sessionId,
        locale: _locale,
        segmentIndex: item.segmentIndex,
        segmentPath: item.segmentPath,
        deduplicationKey: item.deduplicationKey,
        previousContext: _assembler.trailingContext(),
      );

      request.validate();

      try {
        final result = await _provider.transcribeSegment(request);
        result.validateAgainst(request);

        final checkpoint = ClinicalLongFormSegmentTranscriptCheckpoint(
          sessionId: _queue.sessionId,
          segmentIndex: result.segmentIndex,
          deduplicationKey: result.deduplicationKey,
          transcript: result.transcript,
          resultRef: result.resultRef,
          completedAtUtc: _nowUtc().toUtc(),
        );

        // Critical durability ordering.
        await _checkpointStore.save(checkpoint);

        _assembler.accept(result);

        _queue.markCompleted(
          segmentIndex: item.segmentIndex,
          resultRef: result.resultRef,
        );
        await _durableStore.saveBatchQueue(_queue);
        completed++;
      } on ClinicalLongFormBatchTranscriptionException catch (error) {
        _queue.markFailed(
          segmentIndex: item.segmentIndex,
          errorCode: error.code,
        );
        await _durableStore.saveBatchQueue(_queue);
        failed++;

        if (!error.retryable) {
          break;
        }
      } catch (_) {
        _queue.markFailed(
          segmentIndex: item.segmentIndex,
          errorCode: 'unexpected_provider_failure',
        );
        await _durableStore.saveBatchQueue(_queue);
        failed++;
      }
    }

    return ClinicalLongFormCheckpointedBatchRunOutcome(
      processed: processed,
      completed: completed,
      failed: failed,
      exhausted: _queue.exhaustedCount,
    );
  }

  Future<void> dispose() => _provider.dispose();
}
