import 'clinical_long_form_batch_transcription_provider.dart';
import 'clinical_long_form_batch_transcription_queue.dart';
import 'clinical_long_form_transcript_assembler.dart';

final class ClinicalLongFormBatchRunOutcome {
  const ClinicalLongFormBatchRunOutcome({
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

final class ClinicalLongFormBatchTranscriptionRunner {
  ClinicalLongFormBatchTranscriptionRunner({
    required ClinicalLongFormBatchQueue queue,
    required ClinicalLongFormBatchTranscriptionProvider provider,
    required ClinicalLongFormTranscriptAssembler assembler,
    required String locale,
  })  : _queue = queue,
        _provider = provider,
        _assembler = assembler,
        _locale = locale.trim() {
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
  static const bool transcriptPersistenceEnabled = false;

  final ClinicalLongFormBatchQueue _queue;
  final ClinicalLongFormBatchTranscriptionProvider _provider;
  final ClinicalLongFormTranscriptAssembler _assembler;
  final String _locale;

  ClinicalLongFormBatchQueue get queue => _queue;
  ClinicalLongFormTranscriptAssembler get assembler => _assembler;

  Future<ClinicalLongFormBatchRunOutcome> runUntilBlocked() async {
    var processed = 0;
    var completed = 0;
    var failed = 0;

    while (true) {
      final item = _queue.claimNext();
      if (item == null) {
        break;
      }

      processed++;

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

        _assembler.accept(result);

        _queue.markCompleted(
          segmentIndex: item.segmentIndex,
          resultRef: result.resultRef,
        );

        completed++;
      } on ClinicalLongFormBatchTranscriptionException catch (error) {
        _queue.markFailed(
          segmentIndex: item.segmentIndex,
          errorCode: error.code,
        );
        failed++;

        if (!error.retryable) {
          break;
        }
      } catch (_) {
        _queue.markFailed(
          segmentIndex: item.segmentIndex,
          errorCode: 'unexpected_provider_failure',
        );
        failed++;
      }
    }

    return ClinicalLongFormBatchRunOutcome(
      processed: processed,
      completed: completed,
      failed: failed,
      exhausted: _queue.exhaustedCount,
    );
  }

  Future<void> dispose() => _provider.dispose();
}
