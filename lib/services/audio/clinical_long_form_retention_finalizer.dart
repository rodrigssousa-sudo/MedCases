import 'clinical_long_form_local_audio_cleanup.dart';
import 'clinical_long_form_recording_manifest.dart';
import 'clinical_long_form_review_lifecycle.dart';
import 'clinical_long_form_reviewed_artifact_store.dart';
import 'clinical_long_form_reviewed_transcript_artifact.dart';

final class ClinicalLongFormRetentionFinalizationResult {
  const ClinicalLongFormRetentionFinalizationResult({
    required this.artifact,
    this.cleanupReport,
  });

  final ClinicalLongFormReviewedTranscriptArtifact artifact;
  final ClinicalLongFormAudioCleanupReport? cleanupReport;
}

/// Orquestra a ordem crítica:
/// 1) transcript já revisado/confirmado pelo usuário;
/// 2) persiste texto revisado;
/// 3) persiste intenção de retenção;
/// 4) só então, se escolhido, apaga áudio local;
/// 5) persiste estado final.
///
/// Nenhum provider remoto e nenhum owner produtivo importam esta classe.
final class ClinicalLongFormRetentionFinalizer {
  ClinicalLongFormRetentionFinalizer({
    required ClinicalLongFormReviewedArtifactStore artifactStore,
  }) : _artifactStore = artifactStore;

  static const bool productionCutoverEnabled = false;
  static const bool remoteSyncEnabled = false;
  static const bool deleteBeforeDurableTranscriptAllowed = false;

  final ClinicalLongFormReviewedArtifactStore _artifactStore;

  Future<ClinicalLongFormRetentionFinalizationResult> finalize({
    required ClinicalLongFormReviewLifecycle lifecycle,
    required ClinicalLongFormRecordingManifest manifest,
    required ClinicalLongFormAudioDisposition disposition,
    required ClinicalLongFormAudioCleanup cleanup,
    required DateTime reviewedAtUtc,
  }) async {
    if (lifecycle.state !=
        ClinicalLongFormReviewLifecycleState.reviewConfirmed) {
      throw StateError(
        'Retention finalization requires confirmed user review.',
      );
    }

    if (manifest.state.name != 'stopped' ||
        manifest.segments.isEmpty ||
        manifest.segments.any((segment) => !segment.completed)) {
      throw StateError(
        'Retention finalization requires completed stopped audio.',
      );
    }

    final transcript = lifecycle.reviewedTranscript?.trim();
    if (transcript == null || transcript.isEmpty) {
      throw StateError('Reviewed transcript is unavailable.');
    }

    var artifact = ClinicalLongFormReviewedTranscriptArtifact(
      sessionId: manifest.sessionId,
      locale: manifest.locale,
      reviewedTranscript: transcript,
      reviewedAtUtc: reviewedAtUtc.toUtc(),
      sourceSegmentCount: manifest.segments.length,
      sourceActiveDuration: manifest.totalActiveDuration,
      retentionState: ClinicalLongFormAudioRetentionState.reviewedPersisted,
      audioDisposition: null,
    );

    // CRITICAL GATE: durable reviewed text exists before retention action.
    await _artifactStore.save(artifact);

    lifecycle.confirmAudioDisposition(disposition);

    if (disposition == ClinicalLongFormAudioDisposition.keepAudio) {
      artifact = artifact.copyWith(
        retentionState: ClinicalLongFormAudioRetentionState.keepAudio,
        audioDisposition: disposition,
        clearCleanupError: true,
      );
      await _artifactStore.save(artifact);

      return ClinicalLongFormRetentionFinalizationResult(
        artifact: artifact,
      );
    }

    artifact = artifact.copyWith(
      retentionState: ClinicalLongFormAudioRetentionState.deletePending,
      audioDisposition: disposition,
      clearCleanupError: true,
    );
    await _artifactStore.save(artifact);

    try {
      final cleanupReport = await lifecycle.executeConfirmedDeletion(
        manifest: manifest,
        cleanup: cleanup,
      );

      artifact = artifact.copyWith(
        retentionState: ClinicalLongFormAudioRetentionState.audioDeleted,
        clearCleanupError: true,
      );
      await _artifactStore.save(artifact);

      return ClinicalLongFormRetentionFinalizationResult(
        artifact: artifact,
        cleanupReport: cleanupReport,
      );
    } catch (_) {
      artifact = artifact.copyWith(
        retentionState: ClinicalLongFormAudioRetentionState.deletionFailed,
        lastCleanupErrorCode:
            lifecycle.lastDeletionErrorCode ?? 'local_audio_cleanup_failed',
      );

      // Best effort to preserve retry metadata. Original durable reviewed
      // transcript has already been saved before any deletion attempt.
      try {
        await _artifactStore.save(artifact);
      } catch (_) {
        // Preserve original cleanup error to caller.
      }

      rethrow;
    }
  }
}
