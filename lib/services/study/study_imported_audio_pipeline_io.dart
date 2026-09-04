import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/study_workspace_model.dart';
import '../audio/clinical_long_form_audio_contract.dart';
import '../audio/clinical_long_form_batch_transcription_provider.dart';
import '../audio/clinical_long_form_batch_transcription_queue.dart';
import '../audio/clinical_long_form_checkpointed_batch_runner.dart';
import '../audio/clinical_long_form_durable_store.dart';
import '../audio/clinical_long_form_engine_state_recovery_orchestrator.dart';
import '../audio/clinical_long_form_recording_manifest.dart';
import '../audio/clinical_long_form_segment_transcript_checkpoint_store.dart';
import '../audio/clinical_long_form_transcript_assembler.dart';
import 'study_background_transcription_coordinator.dart';
import 'study_multimodal_extraction_service.dart';

final class StudyImportedAudioPipelineResult {
  const StudyImportedAudioPipelineResult({
    required this.extraction,
    required this.jobId,
    required this.segmentCount,
  });

  final StudyExtraction extraction;
  final String jobId;
  final int segmentCount;
}

final class _StudyImportedAudioSegment {
  const _StudyImportedAudioSegment({
    required this.index,
    required this.path,
    required this.startMs,
    required this.durationMs,
  });

  final int index;
  final String path;
  final int startMs;
  final int durationMs;

  int get endMs => startMs + durationMs;
}

final class _StudyEducationalSegmentProvider
    implements ClinicalLongFormBatchTranscriptionProvider {
  const _StudyEducationalSegmentProvider({
    required this.sourceId,
    required this.isEs,
    required this.backgroundSession,
  });

  final String sourceId;
  final bool isEs;
  final StudyBackgroundTranscriptionSession? backgroundSession;

  @override
  String get providerId => 'study_educational_gemini_segmented';

  @override
  Future<ClinicalLongFormBatchTranscriptionResult> transcribeSegment(
    ClinicalLongFormBatchTranscriptionRequest request,
  ) async {
    request.validate();

    final file = File(request.segmentPath);
    if (!await file.exists()) {
      throw const ClinicalLongFormBatchTranscriptionException(
        'study_imported_segment_missing',
        retryable: false,
      );
    }

    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw const ClinicalLongFormBatchTranscriptionException(
          'study_imported_segment_empty',
          retryable: false,
        );
      }

      if (backgroundSession != null) {
        final transcript =
            await backgroundSession!.awaitTranscript(request.segmentIndex);
        return ClinicalLongFormBatchTranscriptionResult(
          segmentIndex: request.segmentIndex,
          deduplicationKey: request.deduplicationKey,
          transcript: transcript,
          resultRef:
              'study-background://${request.sessionId}/${request.segmentIndex}',
        );
      }

      final extraction = await StudyMultimodalExtractionService.binary(
        sourceId: sourceId,
        type: StudySourceType.uploadedAudio,
        fileName:
            'segment_${request.segmentIndex.toString().padLeft(5, '0')}.m4a',
        mimeType: 'audio/mp4',
        bytes: bytes,
        isEs: isEs,
      );

      final transcript = extraction.text.trim();
      if (transcript.isEmpty) {
        throw const ClinicalLongFormBatchTranscriptionException(
          'study_imported_segment_transcript_empty',
        );
      }

      return ClinicalLongFormBatchTranscriptionResult(
        segmentIndex: request.segmentIndex,
        deduplicationKey: request.deduplicationKey,
        transcript: transcript,
        resultRef: 'study-local://${request.sessionId}/${request.segmentIndex}',
      );
    } on ClinicalLongFormBatchTranscriptionException {
      rethrow;
    } catch (_) {
      throw const ClinicalLongFormBatchTranscriptionException(
        'study_imported_segment_transcription_failed',
      );
    }
  }

  @override
  Future<void> dispose() async {}
}

final class StudyImportedAudioPipeline {
  const StudyImportedAudioPipeline._();

  static const MethodChannel _channel =
      MethodChannel('medcases/study_imported_audio_segmenter_v1');

  static const int maxDurationMs = 4 * 60 * 60 * 1000;
  static const int targetSegmentDurationMs = 5 * 60 * 1000;

  static bool get nativePhysicalSegmentationAvailable => Platform.isIOS;

  static Future<StudyImportedAudioPipelineResult> process({
    required String sourceId,
    required String fileName,
    required String sourcePath,
    required int fileSize,
    required bool isEs,
  }) async {
    if (!Platform.isIOS) {
      throw UnsupportedError(
        'study_imported_audio_native_segmentation_unavailable',
      );
    }
    if (sourcePath.trim().isEmpty || fileSize <= 0) {
      throw StateError('study_imported_audio_source_invalid');
    }

    final jobId = _stableJobId(fileName: fileName, fileSize: fileSize);

    final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
      'segmentAudio',
      <String, Object?>{
        'jobId': jobId,
        'sourcePath': sourcePath,
        'maxDurationMs': maxDurationMs,
        'segmentDurationMs': targetSegmentDurationMs,
      },
    );

    if (raw == null) {
      throw StateError('study_imported_audio_segmenter_empty_response');
    }

    final durationMs = _asInt(raw['durationMs']);
    final rawSegments = raw['segments'];

    if (durationMs == null ||
        durationMs <= 0 ||
        durationMs > maxDurationMs ||
        rawSegments is! List ||
        rawSegments.isEmpty) {
      throw StateError('study_imported_audio_segmenter_invalid_response');
    }

    final segments = <_StudyImportedAudioSegment>[];

    for (var i = 0; i < rawSegments.length; i++) {
      final item = rawSegments[i];
      if (item is! Map) {
        throw StateError('study_imported_audio_segment_invalid');
      }

      final index = _asInt(item['index']);
      final path = item['path'] as String?;
      final startMs = _asInt(item['startMs']);
      final segmentDurationMs = _asInt(item['durationMs']);

      if (index != i ||
          path == null ||
          path.trim().isEmpty ||
          startMs == null ||
          startMs < 0 ||
          segmentDurationMs == null ||
          segmentDurationMs <= 0 ||
          segmentDurationMs > targetSegmentDurationMs + 5000) {
        throw StateError('study_imported_audio_segment_invalid');
      }

      segments.add(
        _StudyImportedAudioSegment(
          index: index!,
          path: path,
          startMs: startMs,
          durationMs: segmentDurationMs,
        ),
      );
    }

    _validateCoverage(segments, durationMs);

    final coveredDurationMs = segments.last.endMs;
    debugPrint(
      '[StudyImportedAudioCoverage] '
      'durationMs=$durationMs '
      'coveredDurationMs=$coveredDurationMs '
      'segments=${segments.length}/${segments.length}',
    );

    final root = await _stateRoot();
    final durableStore = FileClinicalLongFormDurableStore(rootDirectory: root);
    final backgroundSession =
        await StudyBackgroundTranscriptionCoordinator.tryStart(
      sourceId: sourceId,
      isEs: isEs,
      segments: <StudyBackgroundSegmentSpec>[
        for (final segment in segments)
          StudyBackgroundSegmentSpec(
            index: segment.index,
            path: segment.path,
            mimeType: 'audio/mp4',
          ),
      ],
    );

    final checkpointStore =
        FileClinicalLongFormSegmentTranscriptCheckpointStore(
      rootDirectory: root,
    );

    final manifest = ClinicalLongFormRecordingManifest(
      sessionId: jobId,
      locale: isEs ? 'es' : 'pt-BR',
      state: ClinicalLongFormRecordingState.stopped,
      createdAtUtc: DateTime.now().toUtc(),
      totalActiveDuration: Duration(milliseconds: durationMs),
      segments: segments
          .map(
            (segment) => ClinicalLongFormSegmentManifest(
              index: segment.index,
              path: segment.path,
              startedAtUtc: DateTime.fromMillisecondsSinceEpoch(
                segment.startMs,
                isUtc: true,
              ),
              activeDuration: Duration(milliseconds: segment.durationMs),
              completed: true,
            ),
          )
          .toList(growable: false),
    );

    await durableStore.saveManifest(manifest);

    var queue = await durableStore.loadBatchQueue(jobId);
    ClinicalLongFormTranscriptAssembler assembler;

    if (queue == null || queue.totalCount != segments.length) {
      queue = ClinicalLongFormBatchQueue.fromManifest(manifest);
      await durableStore.saveBatchQueue(queue);
      assembler = ClinicalLongFormTranscriptAssembler(
        expectedSegmentCount: queue.totalCount,
      );
    } else {
      final recovery = ClinicalLongFormEngineStateRecoveryOrchestrator(
        checkpointStore: checkpointStore,
      );
      final recovered = await recovery.recoverBatch(
        manifest: manifest,
        queue: queue,
      );
      queue = recovered.queue;
      assembler = recovered.assembler;
      await durableStore.saveBatchQueue(queue);
    }

    if (!queue.isComplete) {
      final runner = ClinicalLongFormCheckpointedBatchRunner(
        queue: queue,
        provider: _StudyEducationalSegmentProvider(
          sourceId: sourceId,
          isEs: isEs,
          backgroundSession: backgroundSession,
        ),
        assembler: assembler,
        durableStore: durableStore,
        checkpointStore: checkpointStore,
        locale: manifest.locale,
      );

      try {
        await runner.runUntilBlocked();
      } finally {
        await runner.dispose();
      }
    }

    if (!queue.isComplete || !assembler.isComplete) {
      throw StateError(
        'study_imported_audio_incomplete_'
        '${queue.completedCount}_${queue.totalCount}',
      );
    }

    final assembly = assembler.assemble();

    if (!assembly.complete ||
        assembly.segmentCount != segments.length ||
        assembly.expectedSegmentCount != segments.length ||
        assembly.text.trim().isEmpty) {
      throw StateError('study_imported_audio_assembly_incomplete');
    }

    final refs = segments
        .map(
          (segment) => SourceRef(
            sourceId: sourceId,
            sourceType: StudySourceType.uploadedAudio,
            timestampStartMs: segment.startMs,
            timestampEndMs: segment.endMs,
          ),
        )
        .toList(growable: false);

    if (backgroundSession != null) {
      await backgroundSession.cleanup();
    }

    return StudyImportedAudioPipelineResult(
      extraction: StudyExtraction(
        text: assembly.text.trim(),
        refs: List<SourceRef>.unmodifiable(refs),
      ),
      jobId: jobId,
      segmentCount: segments.length,
    );
  }

  static Future<void> cleanup(String jobId) async {
    if (jobId.trim().isEmpty) return;

    if (Platform.isIOS) {
      await _channel.invokeMethod<void>(
        'deleteJob',
        <String, Object?>{'jobId': jobId},
      );
    }

    final root = await _stateRoot();
    final state = Directory(
      '${root.path}${Platform.pathSeparator}$jobId',
    );

    if (await state.exists()) {
      await state.delete(recursive: true);
    }
  }

  static Future<Directory> _stateRoot() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(
      '${support.path}${Platform.pathSeparator}'
      'MedCasesStudyImportedAudioState',
    );

    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  static void _validateCoverage(
    List<_StudyImportedAudioSegment> segments,
    int durationMs,
  ) {
    var expectedStart = 0;

    for (final segment in segments) {
      if ((segment.startMs - expectedStart).abs() > 1500) {
        throw StateError('study_imported_audio_segment_gap');
      }
      expectedStart = segment.endMs;
    }

    if ((expectedStart - durationMs).abs() > 3000) {
      throw StateError('study_imported_audio_segment_end_mismatch');
    }
  }

  static String _stableJobId({
    required String fileName,
    required int fileSize,
  }) {
    final input = '$fileName|$fileSize';
    var hash = 0xcbf29ce484222325;

    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }

    return 'studyimp_${hash.toRadixString(16).padLeft(16, '0')}';
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}
