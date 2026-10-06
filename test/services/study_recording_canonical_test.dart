import 'package:medcases/services/audio/recording_deletion_store.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/models/study_workspace_model.dart';
import 'package:medcases/models/study_long_form_audio_handoff.dart';
import 'package:medcases/services/study/recorded_study_transcription.dart';
import 'package:medcases/services/study/study_library_service.dart';
import 'package:medcases/services/study/study_multimodal_extraction_service.dart';
import 'package:medcases/services/study/recording_source_cleanup.dart';
import 'package:medcases/screens/study_workspace_screen.dart';

Study makeStudy() => Study(
    id: 'test-study',
    title: 'Test',
    locale: 'es',
    createdAtUtc: DateTime.utc(2026));
Study insert(Study study, [String session = 'session']) =>
    study.upsertRecording(
        sessionId: session,
        title: 'Clase grabada',
        audioPaths: ['/test/audio.m4a'],
        durationMs: 20000);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RecordingDeletionStore.ownerOverride = () => 'test';
  });
  tearDown(() => RecordingDeletionStore.ownerOverride = null);
  test(
      'one session remains one source through repeated handoff/recovery insertion',
      () {
    var s = insert(makeStudy());
    final id = s.sources.single.id;
    for (var i = 0; i < 5; i++) {
      s = insert(s);
    }
    expect(s.sources.length, 1);
    expect(s.sources.single.id, id);
    expect(insert(s, 'other').sources.length, 2);
  });
  test(
      'pending cannot generate; review is not accepted; accepted text enables generation',
      () {
    var s = insert(makeStudy());
    expect(s.canGenerate, false);
    expect(s.sources.single.isAccepted, false);
    final reviewing = s.sources.single
        .transition(StudySourceState.review, extractedText: 'Reviewed text');
    s = s.copyWith(sources: [reviewing]);
    expect(s.canGenerate, false);
    s = s.copyWith(sources: [reviewing.transition(StudySourceState.accepted)]);
    expect(s.canGenerate, true);
    expect(s.canGenerate, s.acceptedSources.isNotEmpty);
  });
  test(
      'cold persistence retains deterministic identity and audio without another source',
      () async {
    await StudyLibraryService.save(insert(makeStudy()));
    final restored = (await StudyLibraryService.loadAll()).single;
    final reattached = insert(restored);
    expect(reattached.sources.length, 1);
    expect(reattached.sources.single.recordingSessionId, 'session');
    expect(reattached.sources.single.audioPaths, ['/test/audio.m4a']);
    expect(reattached.canGenerate, false);
  });
  test('saving a transcription result preserves other accepted source',
      () async {
    var s = insert(insert(makeStudy()), 'other');
    final accepted = s.sources.last
        .transition(StudySourceState.review, extractedText: 'Other text')
        .transition(StudySourceState.accepted);
    await StudyLibraryService.save(
        s.copyWith(sources: [s.sources.first, accepted]));
    await StudyLibraryService.saveSource(
        s,
        s.sources.first
            .transition(StudySourceState.review, extractedText: 'Result'));
    final result = (await StudyLibraryService.loadAll()).single;
    expect(result.sources.length, 2);
    expect(result.sources.last.isAccepted, true);
  });
  test(
      'retry reuses source and audio; detached listener receives same source after success',
      () async {
    final dir = await Directory.systemTemp.createTemp('canonical-recorder');
    addTearDown(() => dir.delete(recursive: true));
    final audio = await File('${dir.path}/master.m4a').writeAsBytes([1, 2, 3]);
    final s = makeStudy().upsertRecording(
        sessionId: 'session',
        title: 'Audio',
        audioPaths: [audio.path],
        durationMs: 20000);
    var attempt = Completer<StudyExtraction>();
    final ids = <String>[];
    final job = RecordedStudyTranscription.testing(
        study: s,
        sourceId: s.sources.single.id,
        handoff: StudyLongFormAudioHandoff(
            sessionId: 'session',
            locale: 'es',
            totalActiveDurationMs: 20000,
            segments: [
              StudyLongFormAudioSegment(
                  index: 0, path: audio.path, activeDurationMs: 20000)
            ]),
        uid: 'test',
        ownerCheck: () => true,
        execute: () => attempt.future,
        persist: (s) async {
          ids.add(s.sources.single.id);
        });
    void listener() {}
    job.addListener(listener);
    final first = job.retry();
    job.removeListener(listener);
    expect(job.busy, true);
    await Future<void>.delayed(Duration.zero);
    attempt.completeError(const SocketException('offline'));
    await first;
    expect(job.source.state, StudySourceState.retryableError);
    expect(job.canRetry, true);
    expect(job.study.canGenerate, false);
    expect(await audio.readAsBytes(), [1, 2, 3]);
    attempt = Completer<StudyExtraction>();
    job.addListener(listener);
    final second = job.retry();
    expect(job.source.errorCode, isNull);
    attempt.complete(const StudyExtraction(text: 'Ready', refs: []));
    await second;
    expect(job.source.state, StudySourceState.review);
    expect(job.study.sources.length, 1);
    expect(ids.toSet(), {s.sources.single.id});
    expect(await audio.exists(), true);
    job.removeListener(listener);
    job.dispose();
  });
  testWidgets(
      'generation button uses canonical acceptance for appearance and invocation',
      (tester) async {
    var calls = 0;
    var study = insert(makeStudy());
    Future<void> show() => tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StudyGenerateMaterialButton(
                study: study,
                busy: false,
                isEs: true,
                onGenerate: () {
                  calls++;
                }))));
    await show();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(StudyGenerateMaterialButton.enabledFor(study, false), false);
    study = study.copyWith(sources: [
      study.sources.single
          .transition(StudySourceState.review, extractedText: 'Reviewed')
          .transition(StudySourceState.accepted)
    ]);
    await show();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
    await tester.tap(find.text('Generar material'));
    expect(calls, 1);
  });
  test(
      'cleanup requires known test IDs and proven session, retains most advanced text/audio',
      () {
    final s = insert(makeStudy());
    final a = s.sources.single;
    final b = StudySource(
        id: 'legacy',
        type: a.type,
        title: a.title,
        state: StudySourceState.review,
        createdAtUtc: a.createdAtUtc,
        text: 'Retained text',
        recordingSessionId: 'session',
        audioPaths: ['/other/audio.m4a']);
    final dup = s.copyWith(sources: [a, b]);
    expect(
        previewRecordingSourceCleanup(dup, confirmedTestSourceIds: {})
            .removedSourceIds,
        isEmpty);
    final p = previewRecordingSourceCleanup(dup,
        confirmedTestSourceIds: {a.id, b.id});
    expect(p.study.sources.length, 1);
    expect(p.study.sources.single.text, 'Retained text');
    expect(p.study.sources.single.audioPaths.toSet(),
        {'/test/audio.m4a', '/other/audio.m4a'});
    final unknown = StudySource(
        id: 'unknown',
        type: a.type,
        title: a.title,
        state: a.state,
        createdAtUtc: a.createdAtUtc);
    expect(
        previewRecordingSourceCleanup(s.copyWith(sources: [a, unknown]),
            confirmedTestSourceIds: {a.id, unknown.id}).removedSourceIds,
        isEmpty);
  });
  for (final es in [false, true]) {
    testWidgets(
        '${es ? 'ES' : 'PT'} pending card exposes retry, no review/edit or fake transcript',
        (tester) async {
      var retried = false;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: StudySourceRow(
                  source: insert(makeStudy()).sources.single,
                  isEs: es,
                  text: Colors.black,
                  sub: Colors.grey,
                  accent: Colors.green,
                  onRename: () {},
                  onAccept: null,
                  onRetry: () {
                    retried = true;
                  }))));
      expect(find.text(es ? 'Transcripción pendiente' : 'Transcrição pendente'),
          findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.text(es ? 'Aceptar' : 'Aceitar'), findsNothing);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text(es ? 'Reintentar' : 'Tentar novamente'), findsOneWidget);
      await tester.tap(find.text(es ? 'Reintentar' : 'Tentar novamente'));
      await tester.pumpAndSettle();
      expect(retried, true);
    });
  }
}
