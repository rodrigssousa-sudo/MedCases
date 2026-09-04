import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String read(String p) => File(p).readAsStringSync();

void main() {
  final main = read('lib/main.dart');
  final notes = read('lib/screens/notes_screen.dart');
  final notif = read('lib/services/notification_service.dart');
  final fire = read('lib/services/firestore_service.dart');
  final timer = read('lib/screens/home_screen.dart');

  final editorStart = notes.indexOf('class NoteEditorSheetState');
  final pickerStart = notes.indexOf('class _NoteAlertPicker', editorStart);
  if (editorStart < 0 || pickerStart <= editorStart) {
    throw StateError('Editor state boundaries not found');
  }
  final editorState = notes.substring(editorStart, pickerStart);

  test('editor usa paleta clínica e campos neutros', () {
    for (final t in ['0xFF1A1D23','0xFF252930','0xFF2D3340','0xFF374151','0xFF00C781','0xFF008F66']) {
      expect(notes, contains(t));
    }
    expect(notes, isNot(contains('final inputBg = dark ? nc.dark')));
    expect(notes, contains('final noteAccent = nc.border'));
    expect(notes, contains('NOTES V2.6B — EDITOR CLÍNICO HOME/TIMER'));
  });

  test('usa ID real devolvido pelo Firestore', () {
    expect(
      editorState,
      contains('final savedNoteId = await FirestoreService.saveNote('),
    );
    expect(editorState, contains('noteId: savedNoteId'));
    expect(
      editorState,
      isNot(
        contains(
          'DateTime.now().millisecondsSinceEpoch.toString()',
        ),
      ),
    );
    expect(
      RegExp(r'Future<void>\s+_save\s*\(\)')
          .allMatches(editorState)
          .length,
      1,
    );
    expect(fire, contains('static Future<String> saveNote('));
  });

  test('exclusão usa callback do owner produtivo', () {
    expect(notes, contains('final Future<void> Function()? onDelete'));
    expect(notes, contains('final delete = widget.onDelete;'));
    expect(notes, contains('await delete();'));
    expect(notes, contains('if (!context.mounted) return;'));
    expect(notes, contains('showDialog<bool>('));
    expect(main, contains('onDelete: note == null'));
    expect(main, isNot(contains("note!['id']")));
    expect(main, contains('_deleteNote('));
  });

  test('lembrete permanece nota e não Timer clínico', () {
    expect(notes, contains('NotificationService.scheduleNoteAlert('));
    expect(notif, contains('=> scheduleNote('));
    expect(notes, contains('Lembrete da anotação'));
    expect(notes, contains('Recordatorio de la anotación'));
    expect(notes, isNot(contains('startFromShiftConsumer(')));
    expect(timer, contains('class _HistorialCompactCardState'));
  });

  test('tags e cores não dominam as superfícies', () {
    expect(notes, contains('Identificação visual'));
    expect(notes, contains('color: surface'));
    expect(notes, contains('color: noteAccent'));
    expect(notes, contains('width: 4'));
    expect(notes, contains('Tags (opcional)'));
  });
}
