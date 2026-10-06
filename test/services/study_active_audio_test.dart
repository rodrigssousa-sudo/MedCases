import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/models/study_workspace_model.dart';
import 'package:medcases/services/audio/recording_deletion_store.dart';
import 'package:medcases/services/study/study_library_service.dart';

Study base() => Study(
    id: 'study',
    title: 'Synthetic',
    locale: 'pt',
    createdAtUtc: DateTime.utc(2026),
    ownerUid: 'u1');
Study add(Study s, String id) => s.upsertRecording(
    sessionId: id, title: id, audioPaths: ['/$id.m4a'], durationMs: 32000);
Study accept(Study s, String id) => s.copyWith(
    sources: s.sources
        .map((x) => x.recordingSessionId == id
            ? x
                .transition(StudySourceState.review,
                    extractedText: 'Synthetic $id.')
                .transition(StudySourceState.accepted)
            : x)
        .toList());
StudyArtifact artifact(String id, String source) => StudyArtifact(
    id: id,
    type: StudyArtifactType.fullSummary,
    title: 'Summary',
    content: 'Synthetic summary.',
    createdAtUtc: DateTime.utc(2026),
    sourceIds: [source]);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? owner;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    owner = 'u1';
    RecordingDeletionStore.ownerOverride = () => owner;
  });
  tearDown(() => RecordingDeletionStore.ownerOverride = null);
  test('A complete then B: only B operational, A and derivatives retained', () {
    var s = accept(add(base(), 'A'), 'A');
    s = s.copyWith(artifacts: [artifact('a', 'recording_A')]);
    s = add(s, 'B');
    expect(s.operationalSources.map((x) => x.id), ['recording_B']);
    expect(s.historicalAudioSources.single.text, 'Synthetic A.');
    expect(s.artifacts.length, 1);
    expect(s.activeArtifacts, isEmpty);
    expect(s.canGenerate, false);
  });
  test('B explicit reactivation restores source-specific materials', () {
    var s = accept(add(base(), 'A'), 'A');
    s = s.copyWith(artifacts: [artifact('a', 'recording_A')]);
    s = add(s, 'B').activateAudio('recording_A');
    expect(s.acceptedSources.single.id, 'recording_A');
    expect(s.activeArtifacts.single.id, 'a');
  });
  test('C late A result and artifact cannot retarget B', () async {
    final a = add(base(), 'A');
    await StudyLibraryService.save(a);
    final b = add(a, 'B');
    await StudyLibraryService.save(b);
    await StudyLibraryService.saveSource(
        a,
        a.sources.single
            .transition(StudySourceState.review, extractedText: 'A result.'));
    await StudyLibraryService.saveArtifact(a, artifact('late', 'recording_A'));
    final s = (await StudyLibraryService.loadAll()).single;
    expect(s.activeSourceId, 'recording_B');
    expect(s.sources.singleWhere((x) => x.id == 'recording_B').text, isEmpty);
    expect(s.historicalAudioSources.single.text, 'A result.');
    expect(s.activeArtifacts, isEmpty);
  });
  test('D three recordings give one active and two historical', () {
    final s = add(add(add(base(), 'A'), 'B'), 'C');
    expect(s.operationalSources.length, 1);
    expect(s.historicalAudioSources.length, 2);
  });
  test('E cold persistence restores pointer and all source metadata', () async {
    final s = add(add(base(), 'A'), 'B');
    await StudyLibraryService.save(s);
    final r = (await StudyLibraryService.loadAll()).single;
    expect(r.activeSourceId, s.activeSourceId);
    expect(r.sources.map((x) => x.audioPaths.single), ['/A.m4a', '/B.m4a']);
    expect(r.sources.every((x) => x.audioDurationMs == 32000), true);
  });
  test('F account switch cannot read or write prior owner data', () async {
    final s = add(base(), 'A');
    await StudyLibraryService.save(s);
    owner = 'u2';
    expect(await StudyLibraryService.loadAll(), isEmpty);
    expect(() => StudyLibraryService.save(s), throwsStateError);
    owner = null;
    expect(await StudyLibraryService.loadAll(), isEmpty);
    owner = 'u1';
    expect((await StudyLibraryService.loadAll()).single.sources.length, 1);
  });
  test('legacy unowned bytes remain intact without exposure', () async {
    final raw = jsonEncode([
      {'id': 'legacy', 'sources': [], 'artifacts': []}
    ]);
    final p = await SharedPreferences.getInstance();
    await p.setString('medcases.study.library.v1', raw);
    expect(await StudyLibraryService.loadAll(), isEmpty);
    await StudyLibraryService.save(add(base(), 'A'));
    expect(p.getString('medcases.study.library.v1'), raw);
  });
  test('source-set matching excludes mixed historical artifacts', () {
    var s = accept(add(base(), 'A'), 'A');
    s = accept(add(s, 'B'), 'B');
    expect(s.buildContext(isEs: false), isNot(contains('Synthetic A.')));
    expect(
        s.artifactMatchesSelection(StudyArtifact(
            id: 'mixed',
            type: StudyArtifactType.fullSummary,
            title: 'x',
            content: 'x',
            createdAtUtc: DateTime.utc(2026),
            sourceIds: ['recording_A', 'recording_B'])),
        false);
  });
  test('explicitly cleared active source never auto-reactivates history', () async {
    final s = add(add(base(), 'A'), 'B').copyWith(clearActiveSource: true);
    await StudyLibraryService.save(s);
    final restored = (await StudyLibraryService.loadAll()).single;
    expect(restored.activeSourceId, isNull);
    expect(restored.operationalSources, isEmpty);
    expect(restored.historicalAudioSources.length, 2);
  });
  test('reactivated study remains the selected workspace after reload', () async {
    final s = add(base(), 'A');
    await StudyLibraryService.save(s);
    await StudyLibraryService.save(Study(id:'other',title:'Other',locale:'pt',createdAtUtc:DateTime.utc(2027),ownerUid:'u1'));
    await StudyLibraryService.save(s.activateAudio('recording_A'));
    expect(await StudyLibraryService.activeStudyId(), 'study');
  });

}
