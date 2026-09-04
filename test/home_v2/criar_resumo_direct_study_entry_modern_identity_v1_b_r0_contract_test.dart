import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final token = 'class $className';
  final start = source.indexOf(token);
  expect(start, greaterThanOrEqualTo(0), reason: className);
  final next = source.indexOf('\nclass ', start + token.length);
  return next < 0 ? source.substring(start) : source.substring(start, next);
}

void main() {
  final main = File('lib/main.dart').readAsStringSync();

  group('Criar Resumo direct Study entry modern identity V1-B-R0', () {
    test('opens the shared workspace directly on Study', () {
      final owner = classBlock(main, '_NotesAudioWorkspaceState');

      expect(owner, contains('int _section = 1;'));
      expect(owner, isNot(contains('int _section = 0;')));
      expect(owner, contains('index: _section'));
      expect(owner, contains('StudyWorkspaceScreen(isEs: isEs)'));
    });

    test('uses Study-area identity in PT and ES', () {
      final owner = classBlock(main, '_NotesAudioWorkspaceState');

      expect(
        owner,
        contains("isEs ? 'Área de Estudio' : 'Área de Estudos'"),
      );
      expect(
        owner,
        isNot(contains("isEs ? 'Crear Resumen' : 'Criar Resumo'")),
      );
    });

    test('preserves Notes Study and History navigation', () {
      final owner = classBlock(main, '_NotesAudioWorkspaceState');

      for (final token in <String>[
        "label: 'Notas'",
        "label: isEs ? 'Estudio' : 'Estudos'",
        "label: isEs ? 'Historial' : 'Histórico'",
        'onTap: () => setState(() => _section = 0)',
        'onTap: () => setState(() => _section = 1)',
        'onTap: () => setState(() => _section = 2)',
        'StudyWorkspaceScreen(isEs: isEs)',
        'StudyHistoryScreen(isEs: isEs)',
      ]) {
        expect(owner, contains(token), reason: token);
      }
    });

    test('preserves Home create-summary entry route to shared workspace', () {
      expect(main, contains('void _onOpenNotes() => _onTabChange(10);'));
      expect(
        main,
        contains('_NotesAudioWorkspace(onBack: _closeNotesWorkspace)'),
      );
    });
  });
}
