import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String read(String p) => File(p).readAsStringSync();
String owner(String main) {
  final a = main.indexOf('class _NotesAudioWorkspaceState');
  final b = main.indexOf('\nclass _NotesAudioWorkspaceTab', a);
  expect(a, greaterThanOrEqualTo(0));
  expect(b, greaterThan(a));
  return main.substring(a, b);
}

void main() {
  test('workspace is Notes Studies History only', () {
    final m = read('lib/main.dart');
    final o = owner(m);
    expect(RegExp(r'_NotesAudioWorkspaceTab\s*\(').allMatches(o).length, 3);
    expect(o, isNot(contains("label: isEs ? 'Audio' : 'Áudio'")));
    expect(o, isNot(contains('_NotesAudioWorkspaceAudio(')));
    expect(o, contains("label: isEs ? 'Estudio' : 'Estudos'"));
    expect(o, contains("label: isEs ? 'Historial' : 'Histórico'"));
    expect(o, contains('StudyWorkspaceScreen('));
    expect(o, contains('StudyHistoryScreen('));
  });
  test('audio remains inside Study', () {
    final s = read('lib/screens/study_workspace_screen.dart');
    expect(s, contains('NotesAudioLongFormLocalRuntimeScreen('));
    expect(s, contains('StudySourceType.recordedAudio'));
    expect(s, contains('StudySourceType.uploadedAudio'));
  });
  test('library supports delete', () {
    final l = read('lib/services/study/study_library_service.dart');
    final s = read('lib/screens/study_workspace_screen.dart');
    expect(l, contains('static Future<void> deleteById(String studyId) async'));
    expect(l, contains('removeWhere((item) => item.id == normalized)'));
    expect(s, contains('StudyLibraryService.deleteById(study.id)'));
    expect(s, contains('Icons.delete_outline_rounded'));
    expect(
      RegExp(r'Future<void> _openLibrary\(\) async').allMatches(s).length,
      1,
    );
  });
  test('history is functional and deletable', () {
    final h = read('lib/screens/study_history_screen.dart');
    expect(h, contains('StudyLibraryService.loadAll()'));
    expect(h, contains('StudyLibraryService.deleteById(study.id)'));
    expect(h, contains('Histórico de estudos'));
    expect(h, contains('Excluir do histórico'));
  });
  test('notes premium empty state keeps CRUD', () {
    final m = read('lib/main.dart');
    expect(m, contains('Sua área de notas'));
    expect(m, contains('Tu espacio de notas'));
    expect(m, contains('BorderRadius.circular(8)'));
    expect(m, contains('width: 0.7'));
    expect(m, contains('FirestoreService.notesStream(uid)'));
    expect(
      m,
      contains('FirestoreService.deleteNote(uid: uid, noteId: noteId)'),
    );
  });
  test('clinical audio gates remain closed', () {
    final c = read(
      'lib/services/audio/clinical_long_form_remote_audio_consent_store.dart',
    );
    final p = read(
      'lib/services/audio/clinical_long_form_remote_transcription_policy.dart',
    );
    expect(c, contains('productionCallsiteWired = false'));
    expect(c, contains('productionRemoteAudioEnabled = false'));
    expect(p, contains('realPatientAudioAllowed = false'));
    expect(p, contains('remoteAudioTransmissionEnabledInProduction = false'));
  });
}
