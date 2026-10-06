import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/models/study_workspace_model.dart';
import 'package:medcases/services/audio/recording_deletion_store.dart';
import 'package:medcases/services/study/study_library_service.dart';
import 'package:medcases/services/study/study_visual_generation.dart';
import 'study_active_audio_test.dart' show base, add, accept;

StudyArtifact result(String id, Study s) => StudyArtifact(
    id: id,
    type: StudyArtifactType.visualSummary,
    title: 'Resumo visual',
    content: jsonEncode(
        {'title': 'Síndrome de Cushing', 'overview': 'Exemplo educativo.'}),
    createdAtUtc: DateTime.utc(2026),
    sourceIds: s.acceptedSources.map((s) => s.id).toList());
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RecordingDeletionStore.ownerOverride = () => 'u1';
  });
  tearDown(() => RecordingDeletionStore.ownerOverride = null);
  test('identity isolates owner, locale, source, session and content', () {
    final a = accept(add(base(), 'A'), 'A');
    final id = StudyVisualGeneration.identity(a, false);
    expect(StudyVisualGeneration.identity(a, false), id);
    expect(StudyVisualGeneration.identity(a, true), isNot(id));
    expect(StudyVisualGeneration.identity(a.copyWith(ownerUid: 'u2'), false),
        isNot(id));
    final b = accept(add(a, 'B'), 'B');
    expect(StudyVisualGeneration.identity(b, false), isNot(id));
    expect(
        StudyVisualGeneration.identity(b.activateAudio('recording_A'), false),
        id);
  });
  test('concurrent click and completed retry call provider once', () async {
    final s = accept(add(base(), 'once'), 'once');
    final c = Completer<StudyArtifact>();
    var calls = 0;
    Future<StudyArtifact> generate() {
      calls++;
      return c.future;
    }

    final a = StudyVisualGeneration.run('once', generate),
        b = StudyVisualGeneration.run('once', generate);
    c.complete(result('once', s));
    expect(await a, same(await b));
    expect(await StudyVisualGeneration.run('once', generate), same(await a));
    expect(calls, 1);
  });
  for (final code in ['provider_timeout', 'provider_5xx']) {
    test('$code fails safely and explicit retry can succeed', () async {
      final s = accept(add(base(), code), code);
      var calls = 0;
      Future<StudyArtifact> generate() async {
        calls++;
        if (calls == 1) throw StateError(code);
        return result(code, s);
      }

      await expectLater(
          StudyVisualGeneration.run(code, generate), throwsStateError);
      expect((await StudyVisualGeneration.run(code, generate)).id, code);
      expect(calls, 2);
    });
  }
  test('late visual A persists once while B stays active; reload historical A',
      () async {
    final a = accept(add(base(), 'visualA'), 'visualA');
    await StudyLibraryService.save(a);
    final id = StudyVisualGeneration.identity(a, false);
    final artifact = result(id, a);
    final b = accept(add(a, 'visualB'), 'visualB');
    await StudyLibraryService.save(b);
    await StudyLibraryService.saveArtifact(a, artifact);
    await StudyLibraryService.saveArtifact(a, artifact);
    final loaded = (await StudyLibraryService.loadAll()).single;
    expect(loaded.activeSourceId, 'recording_visualB');
    expect(loaded.activeArtifacts, isEmpty);
    expect(loaded.artifacts.length, 1);
    expect(
        loaded
            .activateAudio('recording_visualA')
            .activeArtifacts
            .single
            .content,
        artifact.content);
  });
  test('persistence owner failure never assigns artifact to another user',
      () async {
    final s = accept(add(base(), 'owner'), 'owner');
    final v = result('owner', s);
    RecordingDeletionStore.ownerOverride = () => 'u2';
    expect(() => StudyLibraryService.saveArtifact(s, v), throwsStateError);
  });
  for (final type in [
    StudyArtifactType.fullSummary,
    StudyArtifactType.oralExam
  ]) {
    test(
        '${type.name} retry stays single-flight and late result stays on source',
        () async {
      final a = accept(add(base(), type.name), type.name);
      await StudyLibraryService.save(a);
      final id = StudyVisualGeneration.identity(a, false, type: type);
      expect(id, isNot(StudyVisualGeneration.identity(a, false)));
      expect(id, isNot(StudyVisualGeneration.identity(a, true, type: type)));
      final pending = Completer<StudyArtifact>();
      var calls = 0;
      Future<StudyArtifact> generate() {
        calls++;
        return pending.future;
      }

      final first = StudyVisualGeneration.run(id, generate);
      final second = StudyVisualGeneration.run(id, generate);
      final artifact = StudyArtifact(
          id: id,
          type: type,
          title: 'Synthetic',
          content: 'Synthetic educational material.',
          createdAtUtc: DateTime.utc(2026),
          sourceIds: a.acceptedSources.map((s) => s.id).toList());
      pending.complete(artifact);
      expect(await first, same(await second));
      expect(await StudyVisualGeneration.run(id, generate), same(artifact));
      expect(calls, 1);
      final b = accept(add(a, 'later_${type.name}'), 'later_${type.name}');
      await StudyLibraryService.save(b);
      await StudyLibraryService.saveArtifact(a, artifact);
      await StudyLibraryService.saveArtifact(a, artifact);
      final restored = (await StudyLibraryService.loadAll()).single;
      expect(restored.activeSourceId, b.activeSourceId);
      expect(restored.activeArtifacts, isEmpty);
      expect(restored.artifacts.where((v) => v.id == id), hasLength(1));
      expect(
          restored.activateAudio(a.activeSourceId!).activeArtifacts.single.id,
          id);
    });
  }
  test('empty context is rejected before provider', () {
    expect(
        () => StudyVisualGeneration.identity(base(), false), throwsStateError);
  });
}
