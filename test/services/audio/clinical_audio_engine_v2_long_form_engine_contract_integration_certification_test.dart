import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_long_form_audio_contract.dart';
import 'package:medcases/services/audio/clinical_long_form_batch_transcription_provider.dart';
import 'package:medcases/services/audio/clinical_long_form_batch_transcription_queue.dart';
import 'package:medcases/services/audio/clinical_long_form_checkpointed_batch_runner.dart';
import 'package:medcases/services/audio/clinical_long_form_durable_store.dart';
import 'package:medcases/services/audio/clinical_long_form_engine_state_recovery_orchestrator.dart';
import 'package:medcases/services/audio/clinical_long_form_local_audio_cleanup.dart';
import 'package:medcases/services/audio/clinical_long_form_recording_manifest.dart';
import 'package:medcases/services/audio/clinical_long_form_retention_finalizer.dart';
import 'package:medcases/services/audio/clinical_long_form_review_lifecycle.dart';
import 'package:medcases/services/audio/clinical_long_form_reviewed_artifact_store.dart';
import 'package:medcases/services/audio/clinical_long_form_reviewed_transcript_artifact.dart';
import 'package:medcases/services/audio/clinical_long_form_segment_transcript_checkpoint_store.dart';
import 'package:medcases/services/audio/clinical_long_form_session_directory_layout.dart';
import 'package:medcases/services/audio/clinical_long_form_session_garbage_collector.dart';
import 'package:medcases/services/audio/clinical_long_form_transcript_assembler.dart';

final class _CertificationBatchProvider
    implements ClinicalLongFormBatchTranscriptionProvider {
  const _CertificationBatchProvider();

  @override
  String get providerId => 'certification_fake_provider';

  @override
  Future<ClinicalLongFormBatchTranscriptionResult> transcribeSegment(
    ClinicalLongFormBatchTranscriptionRequest request,
  ) async {
    final transcripts = <int, String>{
      0: 'Insuficiência cardíaca é uma síndrome clínica. '
          'A paciente apresenta dispneia aos esforços.',
      1: 'Foi discutida fração de ejeção reduzida. '
          'Como exemplo farmacológico, ceftriaxona 2 g.',
      2: 'Ao final foram revisados tratamento, seguimento '
          'e sinais de alarme.',
    };

    return ClinicalLongFormBatchTranscriptionResult(
      segmentIndex: request.segmentIndex,
      deduplicationKey: request.deduplicationKey,
      transcript: transcripts[request.segmentIndex]!,
      resultRef: 'cert://${request.segmentIndex}',
    );
  }

  @override
  Future<void> dispose() async {}
}

Future<ClinicalLongFormRecordingManifest> _prepareSession({
  required Directory root,
  required String sessionId,
}) async {
  final layout = ClinicalLongFormSessionDirectoryLayout(
    rootDirectory: root,
    sessionId: sessionId,
  );
  await layout.ensureDirectories();

  final segments = <ClinicalLongFormSegmentManifest>[];

  for (var index = 0; index < 3; index++) {
    final file = layout.segmentFile(index);
    await file.writeAsBytes(
      <int>[index + 1, index + 2, index + 3],
      flush: true,
    );

    segments.add(
      ClinicalLongFormSegmentManifest(
        index: index,
        path: file.path,
        startedAtUtc: DateTime.utc(2026, 8, 19, 10).add(
          Duration(minutes: index * 5),
        ),
        activeDuration: const Duration(minutes: 5),
        completed: true,
      ),
    );
  }

  return ClinicalLongFormRecordingManifest(
    sessionId: sessionId,
    locale: 'pt-BR',
    state: ClinicalLongFormRecordingState.stopped,
    createdAtUtc: DateTime.utc(2026, 8, 19, 10),
    totalActiveDuration: const Duration(minutes: 15),
    segments: segments,
  );
}

Future<ClinicalLongFormTranscriptAssembly> _transcribeAndRecover({
  required Directory root,
  required ClinicalLongFormRecordingManifest manifest,
}) async {
  final durableStore = FileClinicalLongFormDurableStore(
    rootDirectory: root,
  );
  final checkpointStore = FileClinicalLongFormSegmentTranscriptCheckpointStore(
    rootDirectory: root,
  );

  await durableStore.saveManifest(manifest);

  final queue = ClinicalLongFormBatchQueue.fromManifest(manifest);
  await durableStore.saveBatchQueue(queue);

  final assembler = ClinicalLongFormTranscriptAssembler(
    expectedSegmentCount: queue.totalCount,
  );

  final runner = ClinicalLongFormCheckpointedBatchRunner(
    queue: queue,
    provider: const _CertificationBatchProvider(),
    assembler: assembler,
    durableStore: durableStore,
    checkpointStore: checkpointStore,
    locale: manifest.locale,
    nowUtc: () => DateTime.utc(2026, 8, 19, 11),
  );

  final outcome = await runner.runUntilBlocked();
  expect(outcome.completed, 3);
  expect(queue.isComplete, isTrue);
  expect(assembler.isComplete, isTrue);
  await runner.dispose();

  // Simulated process restart: discard the in-memory queue + assembler.
  final restoredQueue = await durableStore.loadBatchQueue(manifest.sessionId);
  expect(restoredQueue, isNotNull);

  final recovery = ClinicalLongFormEngineStateRecoveryOrchestrator(
    checkpointStore: checkpointStore,
  );

  final recovered = await recovery.recoverBatch(
    manifest: manifest,
    queue: restoredQueue!,
  );

  expect(recovered.queue.isComplete, isTrue);
  expect(recovered.assembler.isComplete, isTrue);
  expect(recovered.checkpointsLoaded, 3);

  return recovered.assembler.assemble();
}

Future<ClinicalLongFormReviewedTranscriptArtifact> _reviewAndFinalize({
  required Directory root,
  required ClinicalLongFormRecordingManifest manifest,
  required ClinicalLongFormTranscriptAssembly transcript,
  required ClinicalLongFormAudioDisposition disposition,
}) async {
  final lifecycle = ClinicalLongFormReviewLifecycle();

  lifecycle.acceptCompletedTranscript(transcript);
  lifecycle.confirmUserReview(
    reviewedTranscript: '${transcript.text}\n\n'
        'Revisado e confirmado pelo usuário.',
  );

  final artifactStore = FileClinicalLongFormReviewedArtifactStore(
    rootDirectory: root,
  );

  final finalizer = ClinicalLongFormRetentionFinalizer(
    artifactStore: artifactStore,
  );

  final layout = ClinicalLongFormSessionDirectoryLayout(
    rootDirectory: root,
    sessionId: manifest.sessionId,
  );

  final result = await finalizer.finalize(
    lifecycle: lifecycle,
    manifest: manifest,
    disposition: disposition,
    cleanup: FileClinicalLongFormAudioCleanup(
      allowedRootDirectory: layout.audioDirectory,
    ),
    reviewedAtUtc: DateTime.utc(2026, 8, 19, 11, 30),
  );

  final restored = await artifactStore.load(manifest.sessionId);
  expect(restored, isNotNull);
  expect(
    restored!.reviewedTranscript,
    contains('Revisado e confirmado pelo usuário.'),
  );

  return result.artifact;
}

void main() {
  test(
    'E2E delete flow survives restart and preserves reviewed artifact',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'medcases_engine_cert_delete_',
      );

      try {
        final manifest = await _prepareSession(
          root: root,
          sessionId: 'cert_delete_001',
        );

        final transcript = await _transcribeAndRecover(
          root: root,
          manifest: manifest,
        );

        expect(transcript.complete, isTrue);
        expect(transcript.segmentCount, 3);
        expect(transcript.text, contains('ceftriaxona 2 g'));

        final artifact = await _reviewAndFinalize(
          root: root,
          manifest: manifest,
          transcript: transcript,
          disposition: ClinicalLongFormAudioDisposition.deleteAfterReview,
        );

        expect(
          artifact.retentionState,
          ClinicalLongFormAudioRetentionState.audioDeleted,
        );

        final layout = ClinicalLongFormSessionDirectoryLayout(
          rootDirectory: root,
          sessionId: manifest.sessionId,
        );

        for (var index = 0; index < 3; index++) {
          expect(await layout.segmentFile(index).exists(), isFalse);
        }

        final checkpointDirectory = Directory(
          '${layout.sessionDirectory.path}'
          '${Platform.pathSeparator}segment_transcripts',
        );
        expect(await checkpointDirectory.exists(), isTrue);

        final collector = ClinicalLongFormSessionGarbageCollector(
          layout: layout,
        );

        await collector.collect(artifact: artifact);

        expect(await layout.manifestFile.exists(), isFalse);
        expect(await layout.batchQueueFile.exists(), isFalse);
        expect(await checkpointDirectory.exists(), isFalse);
        expect(await layout.audioDirectory.exists(), isFalse);

        expect(await layout.reviewedTranscriptFile.exists(), isTrue);
        expect(
          await layout.reviewedTranscriptBackupFile.exists(),
          isTrue,
        );

        final reviewedStore = FileClinicalLongFormReviewedArtifactStore(
          rootDirectory: root,
        );
        final afterGc = await reviewedStore.load(manifest.sessionId);

        expect(afterGc, isNotNull);
        expect(
          afterGc!.retentionState,
          ClinicalLongFormAudioRetentionState.audioDeleted,
        );
        expect(
          afterGc.reviewedTranscript,
          contains('ceftriaxona 2 g'),
        );
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'E2E keep flow preserves M4A and manifest but removes checkpoints',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'medcases_engine_cert_keep_',
      );

      try {
        final manifest = await _prepareSession(
          root: root,
          sessionId: 'cert_keep_001',
        );

        final transcript = await _transcribeAndRecover(
          root: root,
          manifest: manifest,
        );

        final artifact = await _reviewAndFinalize(
          root: root,
          manifest: manifest,
          transcript: transcript,
          disposition: ClinicalLongFormAudioDisposition.keepAudio,
        );

        expect(
          artifact.retentionState,
          ClinicalLongFormAudioRetentionState.keepAudio,
        );

        final layout = ClinicalLongFormSessionDirectoryLayout(
          rootDirectory: root,
          sessionId: manifest.sessionId,
        );

        final checkpointDirectory = Directory(
          '${layout.sessionDirectory.path}'
          '${Platform.pathSeparator}segment_transcripts',
        );

        expect(await checkpointDirectory.exists(), isTrue);

        final collector = ClinicalLongFormSessionGarbageCollector(
          layout: layout,
        );

        await collector.collect(artifact: artifact);

        for (var index = 0; index < 3; index++) {
          expect(await layout.segmentFile(index).exists(), isTrue);
        }

        expect(await layout.manifestFile.exists(), isTrue);
        expect(await layout.reviewedTranscriptFile.exists(), isTrue);
        expect(await checkpointDirectory.exists(), isFalse);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'pending deletion preserves checkpoints required for safe retry',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'medcases_engine_cert_pending_',
      );

      try {
        final manifest = await _prepareSession(
          root: root,
          sessionId: 'cert_pending_001',
        );

        await _transcribeAndRecover(
          root: root,
          manifest: manifest,
        );

        final layout = ClinicalLongFormSessionDirectoryLayout(
          rootDirectory: root,
          sessionId: manifest.sessionId,
        );

        final checkpointDirectory = Directory(
          '${layout.sessionDirectory.path}'
          '${Platform.pathSeparator}segment_transcripts',
        );

        expect(await checkpointDirectory.exists(), isTrue);

        final artifact = ClinicalLongFormReviewedTranscriptArtifact(
          sessionId: manifest.sessionId,
          locale: manifest.locale,
          reviewedTranscript: 'Texto final já revisado.',
          reviewedAtUtc: DateTime.utc(2026, 8, 19, 11, 30),
          sourceSegmentCount: 3,
          sourceActiveDuration: manifest.totalActiveDuration,
          retentionState: ClinicalLongFormAudioRetentionState.deletePending,
          audioDisposition: ClinicalLongFormAudioDisposition.deleteAfterReview,
        );

        final collector = ClinicalLongFormSessionGarbageCollector(
          layout: layout,
        );

        await collector.collect(artifact: artifact);

        expect(await checkpointDirectory.exists(), isTrue);
        expect(await layout.manifestFile.exists(), isTrue);
        for (var index = 0; index < 3; index++) {
          expect(await layout.segmentFile(index).exists(), isTrue);
        }
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  test('certified engine remains isolated from production and remote IO', () {
    final files = <String>[
      'lib/services/audio/clinical_long_form_audio_contract.dart',
      'lib/services/audio/clinical_long_form_recording_manifest.dart',
      'lib/services/audio/record_long_form_audio_provider.dart',
      'lib/services/audio/clinical_long_form_durable_store.dart',
      'lib/services/audio/clinical_long_form_batch_transcription_queue.dart',
      'lib/services/audio/clinical_long_form_batch_transcription_provider.dart',
      'lib/services/audio/clinical_long_form_checkpointed_batch_runner.dart',
      'lib/services/audio/clinical_long_form_engine_state_recovery_orchestrator.dart',
      'lib/services/audio/clinical_long_form_review_lifecycle.dart',
      'lib/services/audio/clinical_long_form_local_audio_cleanup.dart',
      'lib/services/audio/clinical_long_form_reviewed_artifact_store.dart',
      'lib/services/audio/clinical_long_form_retention_finalizer.dart',
      'lib/services/audio/clinical_long_form_session_garbage_collector.dart',
    ];

    final source =
        files.map((path) => File(path).readAsStringSync()).join('\n');

    for (final forbidden in <String>[
      'package:http',
      'Authorization',
      'Bearer ',
      'api.openai.com',
      'Firebase',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }

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
      isNot(contains('ClinicalLongFormRetentionFinalizer')),
    );
  });
}
