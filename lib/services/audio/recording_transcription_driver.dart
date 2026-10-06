import 'dart:convert';
import 'transcription_diagnostics.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../../models/study_workspace_model.dart';
import '../canonical_catalog_cipher.dart' show catalogUidHash;
import '../monthly_usage_ledger.dart';
import '../transcription_quota.dart';
import '../study/study_background_transcription_coordinator.dart';
import '../study/study_multimodal_extraction_service.dart';
import 'recording_session_controller.dart';
import 'recording_derived_audio.dart';
import 'local_transcription_slice.dart';
import 'recording_deletion_store.dart';

/// Durable job identity, per-segment results, and encrypted scoped grant.
class RecordingTranscriptionDriver {
  static const _crypto = MethodChannel('medcases/audio_at_rest_v2');
  static Map<String, Object> _identity(RecordingSessionData s) => {
        'keyId': 'private.${catalogUidHash(s.ownerUid).substring(0, 48)}',
        'sessionId': catalogUidHash(s.ownerUid),
        'assetKind': 'privateUserData',
        'logicalName': catalogUidHash('recording-job.${s.sessionId}')
      };
  static void _owner(RecordingSessionData s) {
    if (FirebaseAuth.instance.currentUser?.uid != s.ownerUid)
      throw StateError('TRANSCRIPTION_USER_CHANGED');
  }

  static Future<Map<String, dynamic>?> _openJob(RecordingSessionData s) async {
    final sealed = s.job['sealedBackground'];
    if (sealed == null) return null;
    _owner(s);
    final bytes = await _crypto.invokeMethod<Uint8List>(
        'open', {..._identity(s), 'sealedData': base64Decode(sealed)});
    _owner(s);
    if (bytes == null) throw StateError('JOB_RECOVERY_UNAVAILABLE');
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)));
  }

  /// New local captures use immutable frame slices. Legacy jobs keep their
  /// existing identity and pipeline; no already-transcribed interval is replayed.
  static Future<String> execute(
      RecordingSessionData s, Future<void> Function() checkpoint) async {
    if (s.job['localCaptureContract'] != 'transcription-only-r1' ||
        s.segments.length != 1 ||
        !(s.segments.single['path'] as String).endsWith('.aac')) {
      return _executePrepared(s, checkpoint);
    }
    _owner(s);
    if (s.job['pendingOutputCommit'] == true) {
      return (s.job['transcriptionParts'] as List)
          .map((p) => p['text'] as String)
          .join('\n\n');
    }
    final original = s.segments.single['path'] as String;
    RecordingSessionData part;
    if (s.job['pendingTranscriptionPart'] is Map) {
      part = RecordingSessionData.fromJson(
          Map<String, dynamic>.from(s.job['pendingTranscriptionPart']));
      part.job['attemptGeneration'] = s.job['attemptGeneration'];
    } else {
      final quota = await TranscriptionQuotaService.instance.refresh();
      _owner(s);
      if (!quota.rangeSupported)
        throw const TranscriptionFailure('TRANSCRIPTION_RANGE_UNAVAILABLE');
      if (quota.remainingMs <= 0)
        throw StateError('TRANSCRIPTION_LIMIT_REACHED');
      final start = s.job['transcribedFrameCount'] as int? ?? 0;
      final path = '${File(original).parent.path}/transcription_$start.aac';
      // Existing derivative from an interrupted preparation is preserved;
      // choose a fresh path, while the durable range keeps retry identity.
      var suffix = 0;
      var destination = path;
      while (await File(destination).exists()) {
        destination =
            '${File(original).parent.path}/transcription_${start}_${++suffix}.aac';
      }
      final slice = await LocalTranscriptionSlice.prepare(
          original: original,
          destination: destination,
          startFrame: start,
          allowedMs: quota.remainingMs);
      _owner(s);
      final fingerprint = s.job['originalSha256'];
      if (fingerprint != null && fingerprint != slice.originalSha256) {
        throw StateError('ORIGINAL_AUDIO_CHANGED');
      }
      s.job['originalSha256'] = slice.originalSha256;
      part = RecordingSessionData(
          sessionId: s.sessionId,
          ownerUid: s.ownerUid,
          createdAt: s.createdAt,
          language: s.language,
          mode: s.mode);
      part.phase = RecordingPhase.recorded;
      part.elapsedDurationMs = slice.durationMs;
      part.segments.add({
        'path': slice.path,
        'durationMs': slice.durationMs,
        'completed': true,
        'blockIndex': 0
      });
      part.job = {
        'recordingLayout': 'single-audio-v1',
        'transcriptionAttemptId': s.job['transcriptionAttemptId'],
        'attemptGeneration': s.job['attemptGeneration'],
        'usageOperationOverride':
            'recording-transcription-${s.sessionId}-frame-$start',
        'sliceStartFrame': start,
        'sliceEndFrame': slice.endFrame,
        'sliceTotalFrames': slice.totalFrames,
        'sliceSampleRate': slice.sampleRate,
        'originalSha256': slice.originalSha256,
        'originalDurationMs': slice.originalDurationMs,
        'transcribedUntilMs': slice.transcribedUntilMs,
        'remainingUntranscribedMs': slice.remainingMs
      };
      s.job['originalDurationMs'] = slice.originalDurationMs;
      s.job['pendingTranscriptionPart'] = part.toJson();
      await checkpoint();
    }
    final text = part.job['settlementPendingResult'] as String? ??
        await _executePrepared(part, () async {
          _owner(s);
          if (part.job['attemptGeneration'] != s.job['attemptGeneration']) {
            throw const TranscriptionFailure('CANCELLED');
          }
          s.job['pendingTranscriptionPart'] = part.toJson();
          await checkpoint();
        });
    _owner(s);
    if (part.job['attemptGeneration'] != s.job['attemptGeneration']) {
      throw const TranscriptionFailure('CANCELLED');
    }
    // Server settlement precedes advancing the cursor. Retry keeps this same
    // completed job if settlement/connection fails; no second debit or upload.
    part.transcript = text;
    part.job['settlementPendingResult'] = text;
    s.job['pendingTranscriptionPart'] = part.toJson();
    await checkpoint();
    final operation = part.job['usageOperationId'] as String;
    final usage = await MonthlyUsageLedger.instance
        .resume(operation, includeCompleted: true);
    if (usage == null) throw StateError('ACCOUNTING_FINALIZATION_FAILED');
    await usage.finish(actualMs: usage.maximumMs, success: true);
    await MonthlyUsageLedger.instance.confirmServerCompletion(usage);
    final parts = List<Map<String, dynamic>>.from(
        (s.job['transcriptionParts'] as List? ?? [])
            .map((p) => Map<String, dynamic>.from(p)));
    if (!parts.any((p) => p['startFrame'] == part.job['sliceStartFrame'])) {
      parts.add({
        'startFrame': part.job['sliceStartFrame'],
        'endFrame': part.job['sliceEndFrame'],
        'text': text,
        'usageOperationId': operation,
        'providerJobId': part.transcriptionJobId,
        'sealedBackground': part.job['sealedBackground']
      });
    }
    s.job['transcriptionParts'] = parts;
    s.job['transcribedFrameCount'] = part.job['sliceEndFrame'];
    s.job['transcribedUntilMs'] = part.job['transcribedUntilMs'];
    s.job['remainingUntranscribedMs'] = part.job['remainingUntranscribedMs'];
    s.job['pendingOutputCommit'] = true;
    s.job.remove('pendingTranscriptionPart');
    await checkpoint();
    return parts.map((p) => p['text'] as String).join('\n\n');
  }

  static Future<String> _executePrepared(
      RecordingSessionData s, Future<void> Function() checkpoint) async {
    final generation = s.job['attemptGeneration'];
    void guard() {
      _owner(s);
      if (RecordingDeletionStore.blockedCached(s.ownerUid, s.sessionId))
        throw const TranscriptionFailure('discarded_due_to_user_deletion',
            retryable: false);
      if (s.job['attemptGeneration'] != generation)
        throw const TranscriptionFailure('CANCELLED');
    }

    _owner(s);
    final continuous = s.job['recordingLayout'] == 'single-audio-v1';
    final singleAudio = continuous && s.segments.length == 1;
    final operation = s.job['usageOperationOverride'] as String? ??
        'recording-transcription-${s.sessionId}';
    final existing = await _openJob(s);
    var usage = await MonthlyUsageLedger.instance.resume(operation);
    await TranscriptionQuotaService.instance.refresh();
    guard();
    await TranscriptionQuotaService.instance.requireEligibility(
        reservationHeaders: usage?.serverHeaders ?? const {});
    guard();
    if (usage == null) {
      final quota = await TranscriptionQuotaService.instance.refresh();
      guard();
      if (quota.remainingMs <= 0) throw StateError('MONTHLY_USAGE_LIMIT');
    }
    final paths = <String>[];
    for (final segment in s.segments) {
      guard();
      markTranscriptionTime(s.job, 'T3', segment: paths.length);
      final path = continuous
          ? segment['path'] as String
          : await RecordingDerivedAudio.prepare(segment['path']);
      markTranscriptionTime(s.job, 'T4', segment: paths.length);
      guard();
      paths.add(path);
      segment['transcriptionPath'] = path;
    }
    var measuredDurationMs = 0;
    for (var i = 0; i < paths.length; i++) {
      final duration = transcriptionMediaDurationMs(
          await File(paths[i]).readAsBytes(),
          longRecording: continuous);
      s.segments[i]['transcriptionDurationMs'] = duration;
      measuredDurationMs += duration;
    }
    if (singleAudio && await File(paths.single).length() > 64 * 1024 * 1024) {
      throw const TranscriptionFailure('FILE_TOO_LARGE', retryable: false);
    }
    if (singleAudio &&
        measuredDurationMs >
            (s.job['sliceStartFrame'] != null
                ? 10 * 60 * 60 * 1000
                : 90 * 60 * 1000)) {
      throw const TranscriptionFailure('DURATION_LIMIT', retryable: false);
    }
    s.job['measuredDurationMs'] = measuredDurationMs;
    s.job['audioRoute'] =
        paths.length == 1 ? 'single_file_durable' : 'segmented_durable';
    if (existing != null && usage == null)
      throw StateError('EXISTING_JOB_RESERVATION_UNAVAILABLE');
    usage ??= await MonthlyUsageLedger.instance.begin(
        operationId: operation,
        kinds: {UsageKind.transcription},
        maximumMs: measuredDurationMs,
        verifiedMediaOnly: true,
        executionCount: s.segments.length);
    guard();
    s.transcriptionState = 'uploading';
    await checkpoint();
    markTranscriptionTime(s.job, 'T5');
    final texts = Map<String, dynamic>.from(s.job['segmentTexts'] ?? {});
    final legacyForeground = !continuous &&
        existing == null &&
        (s.job['transcriptionPipeline'] == 'foreground' || texts.isNotEmpty);
    final background = legacyForeground
        ? null
        : await StudyBackgroundTranscriptionCoordinator.tryStart(
            sourceId: s.sessionId,
            singleAudio: singleAudio,
            rangeStartFrame: s.job['sliceStartFrame'] as int?,
            rangeEndFrame: s.job['sliceEndFrame'] as int?,
            rangeTotalFrames: s.job['sliceTotalFrames'] as int?,
            rangeSampleRate: s.job['sliceSampleRate'] as int?,
            originalSha256: s.job['originalSha256'] as String?,
            attemptId: s.job['transcriptionAttemptId'] as String?,
            requireDurable: continuous,
            isEs: s.language.startsWith('es'),
            usageReservation: usage,
            existingJob: existing,
            onCreated: (job) async {
              markTranscriptionTime(s.job, 'T6');
              guard();
              final sealed = await _crypto.invokeMethod<Uint8List>('seal', {
                ..._identity(s),
                'clearText': Uint8List.fromList(utf8.encode(jsonEncode(job)))
              });
              guard();
              if (sealed == null) throw StateError('JOB_PERSISTENCE_FAILED');
              s.job['sealedBackground'] = base64Encode(sealed);
              s.transcriptionJobId = job['jobId'];
              s.job['jobCreateHttp'] = job['jobCreateHttp'];
              await checkpoint();
            },
            segments: [
                for (var i = 0; i < s.segments.length; i++)
                  StudyBackgroundSegmentSpec(
                      index: i,
                      path: paths[i],
                      mimeType: paths[i].endsWith('.wav')
                          ? 'audio/wav'
                          : paths[i].endsWith('.aac')
                              ? 'audio/aac'
                              : 'audio/mp4')
              ]);
    if (continuous && background == null) {
      throw const TranscriptionFailure('SERVER_FAILURE');
    }
    s.job['transcriptionPipeline'] =
        background == null ? 'foreground' : 'durable';
    await checkpoint();
    for (var i = 0; i < s.segments.length; i++) {
      guard();
      if (texts['$i'] != null) continue;
      s.segments[i]['attemptCount'] =
          (s.segments[i]['attemptCount'] as int? ?? 0) + 1;
      s.segments[i]['transcriptionState'] = 'processing';
      s.transcriptionState = 'processing';
      await checkpoint();
      String text;
      if (background != null) {
        text = await background.awaitTranscript(i, ensureActive: guard,
            onProgress: (progress) async {
          guard();
          s.job['progress'] = progress;
          s.segments[i]['uploadState'] = progress['currentStage'];
          s.segments[i]['jobState'] = progress['currentStage'];
          final native = Map<String, dynamic>.from(progress['transport'] ?? {});
          final timings = Map<String, dynamic>.from(s.job['timings'] ?? {});
          if (native['uploadStartedAt'] != null)
            timings['T7.$i'] = native['uploadStartedAt'];
          if (native['uploadedAt'] != null)
            timings['T8.$i'] = native['uploadedAt'];
          s.job['timings'] = timings;
          await checkpoint();
        });
      } else {
        final extraction = await StudyMultimodalExtractionService.binary(
            sourceId: s.sessionId,
            type: StudySourceType.recordedAudio,
            usageReservation: usage,
            executionIndex: i,
            fileName:
                paths[i].endsWith('.wav') ? 'segment_$i.wav' : 'segment_$i.m4a',
            mimeType: paths[i].endsWith('.wav')
                ? 'audio/wav'
                : paths[i].endsWith('.aac')
                    ? 'audio/aac'
                    : 'audio/mp4',
            bytes: await File(paths[i]).readAsBytes(),
            isEs: s.language.startsWith('es'));
        text = extraction.text;
      }
      guard();
      if (text.trim().isEmpty) throw StateError('EMPTY_SEGMENT');
      s.segments[i]['transcriptionState'] = 'completed';
      s.transcriptionState = 'partial';
      markTranscriptionTime(s.job, 'T10', segment: i);
      texts['$i'] = text;
      s.job['segmentTexts'] = texts;
      await checkpoint();
      markTranscriptionTime(s.job, 'T11', segment: i);
      await checkpoint();
    }
    // Do not cleanup the server job or local audio before the controller has
    // durably written transcript.json. Failed attempts retain the reservation
    // so reopening reattaches to the same job instead of creating a new one.
    s.job['usageOperationId'] = operation;
    await checkpoint();
    markTranscriptionTime(s.job, 'T12');
    final result = <String>[];
    int? lastBlock;
    for (var i = 0; i < s.segments.length; i++) {
      final block = (s.segments[i]['blockIndex'] as int?) ?? 0;
      if (s.mode == 'soapBlocks' && block != lastBlock) {
        final labels = s.language.startsWith('es')
            ? const [
                'Subjetivo',
                'Objetivo',
                'Evaluación',
                'Plan',
                'Medicamentos',
                'Exámenes'
              ]
            : const [
                'Subjetivo',
                'Objetivo',
                'Avaliação',
                'Plano',
                'Medicações',
                'Exames'
              ];
        result.add('[${labels[block.clamp(0, 5)]}]');
        lastBlock = block;
      }
      result.add(removeProvenTranscriptOverlap(
          i > 0 ? texts['${i - 1}'] as String : '', texts['$i'] as String,
          hasAudioOverlap: (s.segments[i]['overlapMs'] as int? ?? 0) > 0));
    }
    return result.join('\n\n');
  }

  static Future<void> cleanupDeleted(RecordingSessionData s) async {
    _owner(s);
    final jobs = <Map<String, dynamic>>[];
    final own = await _openJob(s);
    if (own != null) jobs.add(own);
    final pending = s.job['pendingTranscriptionPart'];
    if (pending is Map) {
      final part =
          RecordingSessionData.fromJson(Map<String, dynamic>.from(pending));
      final job = await _openJob(part);
      if (job != null) jobs.add(job);
    }
    for (final part in s.job['transcriptionParts'] as List? ?? []) {
      if (part['sealedBackground'] == null) continue;
      final holder = RecordingSessionData.fromJson(s.toJson());
      holder.job['sealedBackground'] = part['sealedBackground'];
      final job = await _openJob(holder);
      if (job != null) jobs.add(job);
    }
    final cleaned = <String>{};
    for (final job in jobs) {
      _owner(s);
      if (!cleaned.add(job['jobId'] as String)) continue;
      await StudyBackgroundTranscriptionCoordinator.cleanupDeletedJob(
          job, s.ownerUid, s.sessionId);
    }
  }

  static Future<void> settle(RecordingSessionData s) async {
    _owner(s);
    if (s.transcript == null) return;
    final operation = s.job['usageOperationId'];
    if (operation is! String) return;
    final usage = await MonthlyUsageLedger.instance.resume(operation);
    if (usage != null)
      await usage.finish(actualMs: usage.maximumMs, success: true);
    await RecordingSessionController.instance.refreshQuota();
  }
}
