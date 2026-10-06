import 'package:medcases/services/audio/recording_deletion_store.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/models/study_workspace_model.dart';
import 'package:medcases/models/study_long_form_audio_handoff.dart';
import 'package:medcases/services/study/study_library_service.dart';
import 'package:medcases/services/study/recorded_study_transcription.dart';
import 'package:medcases/services/study/study_multimodal_extraction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RecordingDeletionStore.ownerOverride = () => 'test';
  });
  tearDown(() => RecordingDeletionStore.ownerOverride = null);
  Study initial() => Study(
      id: 'incident-fixture',
      title: 'Synthetic',
      locale: 'es',
      createdAtUtc: DateTime.utc(2026));
  Study handoff(Study s,
          {String sid = 'session-37s', String title = 'Clase grabada'}) =>
      s.upsertRecording(
          sessionId: sid,
          title: title,
          audioPaths: ['/synthetic/master.m4a'],
          durationMs: 37000);

  for (final event in [
    'finalize + pending',
    'pending + cold hydration',
    'route reopen',
    'PT/ES label change',
    'recovery'
  ]) {
    test('$event retains one source for one session', () async {
      var study = handoff(initial());
      final id = study.sources.single.id;
      await StudyLibraryService.save(study);
      study = (await StudyLibraryService.loadAll()).single;
      study = handoff(study,
          title:
              event == 'PT/ES label change' ? 'Aula gravada' : 'Clase grabada');
      await StudyLibraryService.saveSource(study, study.sources.single);
      final restored = (await StudyLibraryService.loadAll()).single;
      expect(restored.sources.length, 1);
      expect(restored.sources.single.id, id);
      expect(restored.sources.single.recordingSessionId, 'session-37s');
      expect(restored.sources.single.audioPaths, ['/synthetic/master.m4a']);
    });
  }
  test('one new session increases existing source count by exactly one',
      () async {
    var study = initial();
    for (var i = 0; i < 4; i++) {
      study = handoff(study, sid: 'prior-$i');
    }
    study = handoff(study);
    study = handoff(study);
    expect(study.sources.length, 5);
    expect(
        study.sources
            .where((s) => s.recordingSessionId == 'session-37s')
            .length,
        1);
  });
  test('physical brief attempt and second recording are distinct sessions', () {
    final study = handoff(handoff(initial(), sid: 'session-3s'));
    expect(study.sources.length, 2);
    expect(study.sources.map((s) => s.recordingSessionId).toSet().length, 2);
  });
  test('retry single-flight and provider completion persist the same source',
      () async {
    final study = handoff(initial());
    await StudyLibraryService.save(study);
    final id = study.sources.single.id;
    var calls = 0;
    final provider = Completer<StudyExtraction>();
    final job = RecordedStudyTranscription.testing(
        study: study,
        sourceId: id,
        handoff: StudyLongFormAudioHandoff(
            sessionId: 'session-37s',
            locale: 'es',
            totalActiveDurationMs: 37000,
            segments: [
              StudyLongFormAudioSegment(
                  index: 0,
                  path: '/synthetic/master.m4a',
                  activeDurationMs: 37000)
            ]),
        uid: 'synthetic-owner',
        ownerCheck: () => true,
        execute: () {
          calls++;
          return provider.future;
        },
        persist: (s) async {
          await StudyLibraryService.saveSource(s, s.sources.single);
        });
    final pending = job.retry();
    await job.retry();
    await Future<void>.delayed(Duration.zero);
    provider.complete(
        const StudyExtraction(text: 'Synthetic transcript', refs: []));
    await pending;
    final restored = (await StudyLibraryService.loadAll()).single;
    expect(calls, 1);
    expect(restored.sources.length, 1);
    expect(restored.sources.single.id, id);
    expect(restored.sources.single.state, StudySourceState.review);
    expect(restored.sources.single.audioPaths, ['/synthetic/master.m4a']);
    job.dispose();
  });
}
