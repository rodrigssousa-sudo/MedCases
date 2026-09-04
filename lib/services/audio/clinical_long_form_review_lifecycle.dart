import 'clinical_long_form_local_audio_cleanup.dart';
import 'clinical_long_form_recording_manifest.dart';
import 'clinical_long_form_transcript_assembler.dart';

enum ClinicalLongFormAudioDisposition {
  deleteAfterReview,
  keepAudio,
}

enum ClinicalLongFormReviewLifecycleState {
  awaitingTranscript,
  readyForReview,
  reviewConfirmed,
  deleteConfirmedPending,
  keepConfirmed,
  audioDeleted,
  deletionFailed,
}

final class ClinicalLongFormReviewLifecycle {
  ClinicalLongFormReviewLifecycle({
    this.defaultDisposition =
        ClinicalLongFormAudioDisposition.deleteAfterReview,
  });

  static const bool productionCutoverEnabled = false;
  static const bool autoDeleteWithoutUserConfirmation = false;
  static const bool transcriptPersistenceEnabled = false;

  final ClinicalLongFormAudioDisposition defaultDisposition;

  ClinicalLongFormReviewLifecycleState _state =
      ClinicalLongFormReviewLifecycleState.awaitingTranscript;

  String? _reviewedTranscript;
  ClinicalLongFormAudioDisposition? _confirmedDisposition;
  String? _lastDeletionErrorCode;

  ClinicalLongFormReviewLifecycleState get state => _state;
  String? get reviewedTranscript => _reviewedTranscript;
  ClinicalLongFormAudioDisposition? get confirmedDisposition =>
      _confirmedDisposition;
  String? get lastDeletionErrorCode => _lastDeletionErrorCode;

  bool get canDeleteAudio =>
      _state == ClinicalLongFormReviewLifecycleState.deleteConfirmedPending ||
      _state == ClinicalLongFormReviewLifecycleState.deletionFailed;

  bool get audioRetentionFinalized =>
      _state == ClinicalLongFormReviewLifecycleState.keepConfirmed ||
      _state == ClinicalLongFormReviewLifecycleState.audioDeleted;

  void acceptCompletedTranscript(
    ClinicalLongFormTranscriptAssembly assembly,
  ) {
    if (_state != ClinicalLongFormReviewLifecycleState.awaitingTranscript) {
      throw StateError('Transcript already accepted.');
    }
    if (!assembly.complete) {
      throw StateError(
        'User review requires complete long-form transcript.',
      );
    }

    final transcript = _normalizeTranscript(assembly.text);
    if (transcript.isEmpty) {
      throw StateError('Completed transcript cannot be empty.');
    }

    _reviewedTranscript = transcript;
    _state = ClinicalLongFormReviewLifecycleState.readyForReview;
  }

  /// O texto revisado continua somente em memória nesta foundation.
  void confirmUserReview({
    required String reviewedTranscript,
  }) {
    if (_state != ClinicalLongFormReviewLifecycleState.readyForReview) {
      throw StateError('Review is not ready for confirmation.');
    }

    final normalized = _normalizeTranscript(reviewedTranscript);
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        reviewedTranscript,
        'reviewedTranscript',
      );
    }

    _reviewedTranscript = normalized;
    _state = ClinicalLongFormReviewLifecycleState.reviewConfirmed;
  }

  void confirmAudioDisposition(
    ClinicalLongFormAudioDisposition disposition,
  ) {
    if (_state != ClinicalLongFormReviewLifecycleState.reviewConfirmed) {
      throw StateError(
        'Audio disposition requires confirmed user review.',
      );
    }

    _confirmedDisposition = disposition;
    _lastDeletionErrorCode = null;

    if (disposition == ClinicalLongFormAudioDisposition.keepAudio) {
      _state = ClinicalLongFormReviewLifecycleState.keepConfirmed;
      return;
    }

    _state = ClinicalLongFormReviewLifecycleState.deleteConfirmedPending;
  }

  Future<ClinicalLongFormAudioCleanupReport> executeConfirmedDeletion({
    required ClinicalLongFormRecordingManifest manifest,
    required ClinicalLongFormAudioCleanup cleanup,
  }) async {
    if (!canDeleteAudio) {
      throw StateError(
        'Audio deletion requires explicit delete-after-review '
        'confirmation.',
      );
    }

    if (_confirmedDisposition !=
        ClinicalLongFormAudioDisposition.deleteAfterReview) {
      throw StateError('Audio retention policy forbids deletion.');
    }

    try {
      final report = await cleanup.deleteCompletedAudio(manifest);

      if (!report.complete) {
        throw StateError('Audio cleanup report is incomplete.');
      }

      _lastDeletionErrorCode = null;
      _state = ClinicalLongFormReviewLifecycleState.audioDeleted;
      return report;
    } catch (_) {
      _lastDeletionErrorCode = 'local_audio_cleanup_failed';
      _state = ClinicalLongFormReviewLifecycleState.deletionFailed;
      rethrow;
    }
  }

  static String _normalizeTranscript(String value) {
    return value.trim().replaceAll(RegExp(r'[ \t]+'), ' ');
  }
}
