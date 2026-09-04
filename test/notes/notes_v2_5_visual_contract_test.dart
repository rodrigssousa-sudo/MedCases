import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  final mainSource = _read('lib/main.dart');
  final notesSource = _read('lib/screens/notes_screen.dart');
  final notificationSource = _read('lib/services/notification_service.dart');

  test('geometria funcional sem 75 px route-level', () {
    expect(mainSource, contains('initialChildSize: 0.52'));
    expect(mainSource, contains('minChildSize: 0.36'));
    expect(mainSource, contains('maxChildSize: 0.92'));
    expect(mainSource, isNot(contains('constraints: const BoxConstraints.tightFor(height: _notesIdleHeight)')));
  });

  test('paleta clínica Home/Timer presente', () {
    for (final token in ['0xFF1A1D23','0xFF252930','0xFF2D3340','0xFF374151','0xFF00C781','0xFF008F66']) {
      expect(mainSource, contains(token));
    }
  });

  test('layout legado removido do owner de Notas', () {
    expect(mainSource, contains('// NOTES V2.5B VISUAL OWNER'));
    expect(mainSource, isNot(contains('// NOTES V2.5B VISUAL OWNER\n      gradient:')));
    expect(mainSource, contains('Buscar anotaciones...'));
    expect(mainSource, contains('height: 42'));
  });

  test('card neutro preserva data, marcador de cor e exclusão confirmada', () {
    expect(mainSource, contains('// NOTES V2.5B NOTE CARD'));
    expect(mainSource, contains('// NOTES V2.5B EMPTY STATE'));
    expect(mainSource, contains('Icons.note_alt_outlined'));
    expect(mainSource, contains('Icons.delete_outline_rounded'));
    expect(mainSource, contains("final dateStr = _formatDate("));
    expect(mainSource, contains("final nc = _panelColorFromHex(hex);"));
    expect(mainSource, contains('color: noteAccent'));
    expect(mainSource, contains('showDialog('));
    expect(mainSource, contains("isEs ? 'Eliminar nota' : 'Excluir anotação'"));
    expect(mainSource, contains("isEs ? 'Eliminar' : 'Excluir'"));
  });

  test('owners e serviços permanecem', () {
    expect(notesSource, contains('class NoteEditorSheet'));
    expect(mainSource, contains('FirestoreService.notesStream'));
    expect(mainSource, contains('FirestoreService.deleteNote'));
    expect(notificationSource, contains('scheduleNote'));
    expect(notificationSource, contains('medcases_notes'));
  });

  test('PT e ES preservados', () {
    for (final label in ['Minhas Anotações','Mis Anotaciones','Nova','Nueva','Buscar anotações...','Buscar anotaciones...']) {
      expect(mainSource, contains(label));
    }
  });
}
