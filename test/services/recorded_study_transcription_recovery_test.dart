import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/study_workspace_model.dart';
import 'package:medcases/models/study_long_form_audio_handoff.dart';
import 'package:medcases/services/study/recorded_study_transcription.dart';
import 'package:medcases/services/study/study_multimodal_extraction_service.dart';

void main() {
  test(
      'pending transcription survives listener detach; failure retains audio and retry succeeds',
      () async {
    final dir = await Directory.systemTemp.createTemp('transcription1709-');
    final file = await File('${dir.path}/segment.m4a').writeAsBytes([1, 2, 3]);
    final source = StudySource(
        id: 'source',
        type: StudySourceType.recordedAudio,
        title: 'Audio',
        state: StudySourceState.added,
        createdAtUtc: DateTime.now());
    final study = Study(
        id: 'study',
        title: 'Study',
        locale: 'es-ES',
        createdAtUtc: DateTime.now(),
        sources: [source]);
    var completion = Completer<StudyExtraction>();
    Study? persisted;
    final job = RecordedStudyTranscription.testing(
        study: study,
        sourceId: 'source',
        uid: 'owner',
        handoff: StudyLongFormAudioHandoff(
            sessionId: 'session',
            locale: 'es-ES',
            totalActiveDurationMs: 60000,
            segments: [
              StudyLongFormAudioSegment(
                  index: 0, path: file.path, activeDurationMs: 60000)
            ]),
        ownerCheck: () => true,
        execute: () => completion.future,
        persist: (value) async {
          persisted = value;
        });
    void view() {}
    job.addListener(view);
    final first = job.retry();
    job.removeListener(view);
    await Future<void>.delayed(Duration.zero);
    expect(job.busy, isTrue);
    completion.completeError(const SocketException('offline'));
    await first;
    expect(job.canRetry, isTrue);
    expect(await file.exists(), isTrue);
    expect(persisted!.sources.single.state, StudySourceState.retryableError);
    completion = Completer<StudyExtraction>();
    job.addListener(view);
    final second = job.retry();
    completion
        .complete(const StudyExtraction(text: 'Texto preservado', refs: []));
    await second;
    expect(job.study.sources.single.state, StudySourceState.review);
    expect(job.study.sources.single.text, 'Texto preservado');
    expect(await file.exists(), isTrue);
    job.removeListener(view);
    job.dispose();
    await dir.delete(recursive: true);
  });
}
