import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_long_form_audio_contract.dart';
import 'package:medcases/services/audio/clinical_long_form_batch_transcription_provider.dart';
import 'package:medcases/services/audio/clinical_long_form_batch_transcription_queue.dart';
import 'package:medcases/services/audio/clinical_long_form_batch_transcription_runner.dart';
import 'package:medcases/services/audio/clinical_long_form_recording_manifest.dart';
import 'package:medcases/services/audio/clinical_long_form_transcript_assembler.dart';

ClinicalLongFormRecordingManifest _manifest() {
  return ClinicalLongFormRecordingManifest(
    sessionId: 'lecture_batch_001',
    locale: 'pt-BR',
    state: ClinicalLongFormRecordingState.stopped,
    createdAtUtc: DateTime.utc(2026, 8, 19, 10),
    totalActiveDuration: const Duration(minutes: 13),
    segments: <ClinicalLongFormSegmentManifest>[
      ClinicalLongFormSegmentManifest(
        index: 0,
        path: '/local/lecture_batch_001_000.m4a',
        startedAtUtc: DateTime.utc(2026, 8, 19, 10),
        activeDuration: const Duration(minutes: 5),
        completed: true,
      ),
      ClinicalLongFormSegmentManifest(
        index: 1,
        path: '/local/lecture_batch_001_001.m4a',
        startedAtUtc: DateTime.utc(2026, 8, 19, 10, 5),
        activeDuration: const Duration(minutes: 5),
        completed: true,
      ),
      ClinicalLongFormSegmentManifest(
        index: 2,
        path: '/local/lecture_batch_001_002.m4a',
        startedAtUtc: DateTime.utc(2026, 8, 19, 10, 10),
        activeDuration: const Duration(minutes: 3),
        completed: true,
      ),
    ],
  );
}

final class _FakeBatchProvider
    implements ClinicalLongFormBatchTranscriptionProvider {
  _FakeBatchProvider({
    required this.transcripts,
    this.failOnceAtSegment,
    this.nonRetryableAtSegment,
  });

  final Map<int, String> transcripts;
  final int? failOnceAtSegment;
  final int? nonRetryableAtSegment;

  final Map<int, int> calls = <int, int>{};
  final List<ClinicalLongFormBatchTranscriptionRequest> requests =
      <ClinicalLongFormBatchTranscriptionRequest>[];

  @override
  String get providerId => 'fake_batch_provider';

  @override
  Future<ClinicalLongFormBatchTranscriptionResult> transcribeSegment(
    ClinicalLongFormBatchTranscriptionRequest request,
  ) async {
    requests.add(request);
    calls[request.segmentIndex] = (calls[request.segmentIndex] ?? 0) + 1;

    if (nonRetryableAtSegment == request.segmentIndex) {
      throw const ClinicalLongFormBatchTranscriptionException(
        'unsupported_audio',
        retryable: false,
      );
    }

    if (failOnceAtSegment == request.segmentIndex &&
        calls[request.segmentIndex] == 1) {
      throw const ClinicalLongFormBatchTranscriptionException(
        'temporary_failure',
      );
    }

    return ClinicalLongFormBatchTranscriptionResult(
      segmentIndex: request.segmentIndex,
      deduplicationKey: request.deduplicationKey,
      transcript: transcripts[request.segmentIndex]!,
      resultRef: 'memory://segment-${request.segmentIndex}',
    );
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  test('provider contract validates M4A request identity', () {
    const valid = ClinicalLongFormBatchTranscriptionRequest(
      sessionId: 'lecture_batch_001',
      locale: 'pt-BR',
      segmentIndex: 0,
      segmentPath: '/local/lecture_000.m4a',
      deduplicationKey: 'lecture_batch_001:segment:0',
    );

    expect(valid.validate, returnsNormally);

    const invalid = ClinicalLongFormBatchTranscriptionRequest(
      sessionId: 'lecture_batch_001',
      locale: 'pt-BR',
      segmentIndex: 0,
      segmentPath: '/local/lecture_000.wav',
      deduplicationKey: 'lecture_batch_001:segment:0',
    );

    expect(invalid.validate, throwsArgumentError);
  });

  test('runner transcribes in order and assembles one final lecture', () async {
    final queue = ClinicalLongFormBatchQueue.fromManifest(
      _manifest(),
    );
    final assembler = ClinicalLongFormTranscriptAssembler(
      expectedSegmentCount: queue.totalCount,
    );
    final provider = _FakeBatchProvider(
      transcripts: const <int, String>{
        0: 'Introdução à insuficiência cardíaca.',
        1: 'Agora discutimos fração de ejeção e congestão.',
        2: 'Por fim, tratamento e seguimento.',
      },
    );

    final runner = ClinicalLongFormBatchTranscriptionRunner(
      queue: queue,
      provider: provider,
      assembler: assembler,
      locale: 'pt-BR',
    );

    final outcome = await runner.runUntilBlocked();

    expect(outcome.processed, 3);
    expect(outcome.completed, 3);
    expect(outcome.failed, 0);
    expect(queue.isComplete, isTrue);
    expect(assembler.isComplete, isTrue);

    final finalTranscript = assembler.assemble();

    expect(finalTranscript.complete, isTrue);
    expect(finalTranscript.segmentCount, 3);
    expect(
      finalTranscript.text,
      'Introdução à insuficiência cardíaca.\n\n'
      'Agora discutimos fração de ejeção e congestão.\n\n'
      'Por fim, tratamento e seguimento.',
    );

    expect(
      provider.requests.map((request) => request.segmentIndex),
      <int>[0, 1, 2],
    );

    expect(provider.requests[0].previousContext, isNull);
    expect(
      provider.requests[1].previousContext,
      contains('insuficiência cardíaca'),
    );

    await runner.dispose();
  });

  test('retry reuses stable deduplication key and does not duplicate text',
      () async {
    final queue = ClinicalLongFormBatchQueue.fromManifest(
      _manifest(),
    );
    final assembler = ClinicalLongFormTranscriptAssembler(
      expectedSegmentCount: queue.totalCount,
    );
    final provider = _FakeBatchProvider(
      failOnceAtSegment: 1,
      transcripts: const <int, String>{
        0: 'Segmento zero.',
        1: 'Segmento um.',
        2: 'Segmento dois.',
      },
    );

    final runner = ClinicalLongFormBatchTranscriptionRunner(
      queue: queue,
      provider: provider,
      assembler: assembler,
      locale: 'pt-BR',
    );

    final outcome = await runner.runUntilBlocked();

    expect(outcome.failed, 1);
    expect(outcome.completed, 3);
    expect(provider.calls[1], 2);
    expect(queue.isComplete, isTrue);

    final segmentOneRequests = provider.requests
        .where((request) => request.segmentIndex == 1)
        .toList(growable: false);

    expect(segmentOneRequests, hasLength(2));
    expect(
      segmentOneRequests[0].deduplicationKey,
      segmentOneRequests[1].deduplicationKey,
    );

    expect(
      assembler.assemble().text,
      'Segmento zero.\n\nSegmento um.\n\nSegmento dois.',
    );

    await runner.dispose();
  });

  test('non-retryable failure blocks final assembly', () async {
    final queue = ClinicalLongFormBatchQueue.fromManifest(
      _manifest(),
    );
    final assembler = ClinicalLongFormTranscriptAssembler(
      expectedSegmentCount: queue.totalCount,
    );
    final provider = _FakeBatchProvider(
      nonRetryableAtSegment: 1,
      transcripts: const <int, String>{
        0: 'Segmento zero.',
        1: 'Segmento um.',
        2: 'Segmento dois.',
      },
    );

    final runner = ClinicalLongFormBatchTranscriptionRunner(
      queue: queue,
      provider: provider,
      assembler: assembler,
      locale: 'pt-BR',
    );

    final outcome = await runner.runUntilBlocked();

    expect(outcome.completed, 1);
    expect(outcome.failed, 1);
    expect(queue.isComplete, isFalse);
    expect(assembler.isComplete, isFalse);

    expect(
      () => assembler.assemble(),
      throwsStateError,
    );

    final partial = assembler.assemble(requireComplete: false);
    expect(partial.complete, isFalse);
    expect(partial.text, 'Segmento zero.');

    await runner.dispose();
  });

  test('assembler accepts identical replay but rejects conflict', () {
    final assembler = ClinicalLongFormTranscriptAssembler(
      expectedSegmentCount: 1,
    );

    const first = ClinicalLongFormBatchTranscriptionResult(
      segmentIndex: 0,
      deduplicationKey: 'lecture:segment:0',
      transcript: 'Ceftriaxona 2 g.',
      resultRef: 'memory://0',
    );

    const replay = ClinicalLongFormBatchTranscriptionResult(
      segmentIndex: 0,
      deduplicationKey: 'lecture:segment:0',
      transcript: '  Ceftriaxona   2 g. ',
      resultRef: 'memory://0-retry',
    );

    const conflicting = ClinicalLongFormBatchTranscriptionResult(
      segmentIndex: 0,
      deduplicationKey: 'lecture:segment:0',
      transcript: 'Ceftriaxona 2 mg.',
      resultRef: 'memory://0-conflict',
    );

    assembler.accept(first);
    expect(() => assembler.accept(replay), returnsNormally);
    expect(() => assembler.accept(conflicting), throwsStateError);

    expect(
      assembler.assemble().text,
      'Ceftriaxona 2 g.',
    );
  });

  test('batch provider layer has zero network and zero transcript persistence',
      () {
    final source = <String>[
      File(
        'lib/services/audio/'
        'clinical_long_form_batch_transcription_provider.dart',
      ).readAsStringSync(),
      File(
        'lib/services/audio/'
        'clinical_long_form_batch_transcription_runner.dart',
      ).readAsStringSync(),
      File(
        'lib/services/audio/'
        'clinical_long_form_transcript_assembler.dart',
      ).readAsStringSync(),
    ].join('\n');

    for (final forbidden in <String>[
      'package:http',
      'dart:io',
      'WebSocket',
      'HttpClient',
      'Authorization',
      'Bearer ',
      'api.openai.com',
      'Firebase',
      'writeAsString',
      'writeAsBytes',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }

    expect(
      source,
      contains('static const bool productionCutoverEnabled = false'),
    );
    expect(
      source,
      contains('static const bool remoteProviderImplemented = false'),
    );
    expect(
      source,
      contains('static const bool transcriptPersistenceEnabled = false'),
    );

    final main = File('lib/main.dart').readAsStringSync();
    final recorder =
        File('lib/services/clinical_recorder_service.dart').readAsStringSync();
    final history = File('lib/screens/history_screen.dart').readAsStringSync();

    expect(
      main,
      isNot(contains('ClinicalLongFormBatchTranscriptionRunner')),
    );
    expect(
      recorder,
      isNot(contains('ClinicalLongFormBatchTranscriptionRunner')),
    );
    expect(
      history,
      isNot(contains('ClinicalLongFormTranscriptAssembler')),
    );
  });
}
