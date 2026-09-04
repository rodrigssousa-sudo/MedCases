import 'dart:io';

import 'clinical_long_form_batch_transcription_provider.dart';
import 'clinical_long_form_remote_batch_sandbox_provider.dart';
import 'clinical_long_form_secure_plaintext_staging_lifecycle.dart';

final class ClinicalLongFormSealedBatchTranscriptionRequest {
  const ClinicalLongFormSealedBatchTranscriptionRequest({
    required this.sessionId,
    required this.locale,
    required this.segmentIndex,
    required this.sealedSegmentPath,
    required this.deduplicationKey,
    this.previousContext,
  });

  final String sessionId;
  final String locale;
  final int segmentIndex;
  final String sealedSegmentPath;
  final String deduplicationKey;
  final String? previousContext;

  void validate() {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,96}$').hasMatch(sessionId)) {
      throw ArgumentError.value(sessionId, 'sessionId');
    }
    if (locale.trim().isEmpty || locale.length > 40) {
      throw ArgumentError.value(locale, 'locale');
    }
    if (segmentIndex < 0 || segmentIndex > 99999) {
      throw ArgumentError.value(segmentIndex, 'segmentIndex');
    }
    if (!sealedSegmentPath.toLowerCase().endsWith('.m4a.sealed')) {
      throw ArgumentError.value(
        sealedSegmentPath,
        'sealedSegmentPath',
      );
    }
    if (deduplicationKey.trim().isEmpty || deduplicationKey.length > 240) {
      throw ArgumentError.value(
        deduplicationKey,
        'deduplicationKey',
      );
    }

    final context = previousContext;
    if (context != null && context.length > 1200) {
      throw ArgumentError.value(
        context.length,
        'previousContext.length',
      );
    }
  }
}

/// Sandbox-only bridge from an encrypted durable M4A segment to the existing
/// remote batch provider.
///
/// The sealed source never goes to the remote provider. A plaintext staging
/// lease is opened locally, used exactly once, and deleted by the Build 25
/// lifecycle in `finally` on success, failure, or expiry.
final class ClinicalLongFormStagingToBackendSandboxAdapter {
  ClinicalLongFormStagingToBackendSandboxAdapter({
    required ClinicalLongFormSecurePlaintextStagingLifecycle stagingLifecycle,
    required ClinicalLongFormRemoteBatchSandboxProvider remoteProvider,
  })  : _stagingLifecycle = stagingLifecycle,
        _remoteProvider = remoteProvider;

  static const bool productionPersistenceIntegrationEnabled = false;
  static const bool productionCutoverEnabled = false;
  static const bool productionAudioOwnersWired = false;
  static const bool realPatientAudioEnabled = false;
  static const bool actualNetworkCreatedByThisAdapter = false;
  static const bool plaintextPathDurablyPersisted = false;
  static const bool sealedSourceSentToProvider = false;
  static const bool delegateMustRemainSandboxProvider = true;
  static const bool stagingLeaseRequired = true;
  static const bool stagingLeaseSingleUseRequired = true;
  static const int stagingMaximumPlaintextLifetimeSeconds =
      ClinicalLongFormSecurePlaintextStagingLifecycle
          .maximumPlaintextLifetimeSeconds;

  final ClinicalLongFormSecurePlaintextStagingLifecycle _stagingLifecycle;
  final ClinicalLongFormRemoteBatchSandboxProvider _remoteProvider;

  Future<ClinicalLongFormBatchTranscriptionResult> transcribeSealedSegment(
    ClinicalLongFormSealedBatchTranscriptionRequest request,
  ) async {
    request.validate();

    final sealedSource = File(request.sealedSegmentPath);

    ClinicalLongFormPlaintextStagingLease lease;
    try {
      lease = await _stagingLifecycle.createLease(
        sessionId: request.sessionId,
        segmentIndex: request.segmentIndex,
        sealedSource: sealedSource,
      );
    } on Object {
      throw const ClinicalLongFormBatchTranscriptionException(
        'secure_plaintext_staging_open_failed',
      );
    }

    return lease.useOnce<ClinicalLongFormBatchTranscriptionResult>(
      (stagingFile) async {
        final stagedRequest = ClinicalLongFormBatchTranscriptionRequest(
          sessionId: request.sessionId,
          locale: request.locale,
          segmentIndex: request.segmentIndex,
          segmentPath: stagingFile.path,
          deduplicationKey: request.deduplicationKey,
          previousContext: request.previousContext,
        );
        stagedRequest.validate();

        final result = await _remoteProvider.transcribeSegment(stagedRequest);
        result.validateAgainst(stagedRequest);
        return result;
      },
    );
  }

  Future<void> dispose() => _remoteProvider.dispose();
}
