import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

int count(String source, String pattern) =>
    RegExp(pattern, multiLine: true).allMatches(source).length;

String methodBlock(String source, String className, String methodName) {
  final classMatch = RegExp(
    '^class\\s+${RegExp.escape(className)}\\b',
    multiLine: true,
  ).firstMatch(source);
  if (classMatch == null) {
    throw StateError('Class not found: $className');
  }

  final methodMatch = RegExp(
    'Future<void>\\s+${RegExp.escape(methodName)}'
    '\\s*\\(\\)\\s*async\\s*\\{',
    multiLine: true,
  ).firstMatch(source.substring(classMatch.start));
  if (methodMatch == null) {
    throw StateError('Method not found: $methodName');
  }

  final absoluteStart = classMatch.start + methodMatch.start;
  final openingBrace = source.indexOf(
    '{',
    absoluteStart,
  );
  if (openingBrace < 0) {
    throw StateError('Opening brace not found: $methodName');
  }

  var depth = 0;
  var index = openingBrace;
  var lineComment = false;
  var blockComment = false;
  String? quote;

  while (index < source.length) {
    final char = source[index];
    final next =
        index + 1 < source.length ? source[index + 1] : '';

    if (lineComment) {
      if (char == '\n') lineComment = false;
    } else if (blockComment) {
      if (char == '*' && next == '/') {
        blockComment = false;
        index += 1;
      }
    } else if (quote != null) {
      if (char == r'\') {
        index += 1;
      } else if (char == quote) {
        quote = null;
      }
    } else {
      if (char == '/' && next == '/') {
        lineComment = true;
        index += 1;
      } else if (char == '/' && next == '*') {
        blockComment = true;
        index += 1;
      } else if (char == "'" || char == '"') {
        quote = char;
      } else if (char == '{') {
        depth += 1;
      } else if (char == '}') {
        depth -= 1;
        if (depth == 0) {
          return source.substring(absoluteStart, index + 1);
        }
      }
    }

    index += 1;
  }

  throw StateError('Unbalanced method: $methodName');
}

void main() {
  final notes = read('lib/screens/notes_screen.dart');
  final timer = read('lib/screens/home_screen.dart');
  final notification = read(
    'lib/services/notification_service.dart',
  );

  final save = methodBlock(
    notes,
    'NoteEditorSheetState',
    '_save',
  );

  test('editor importa apenas a ponte pública do Timer', () {
    expect(
      count(
        notes,
        r'''import\s+["'][^"']*notification_service\.dart["']\s*;''',
      ),
      1,
    );
    expect(
      notes,
      contains(
        "import 'home_screen.dart' "
        'show ClinicalTimerExternalBridge;',
      ),
    );
    expect(
      count(
        notes,
        r'import\s+'
        r"'home_screen\.dart'\s+show\s+"
        r'ClinicalTimerExternalBridge\s*;',
      ),
      1,
    );
  });

  test('salvamento agenda uma única notificação de nota', () {
    expect(
      count(
        save,
        r'NotificationService\.scheduleNoteAlert\s*\(',
      ),
      1,
    );
    expect(
      save,
      contains(
        'final savedNoteId = '
        'await FirestoreService.saveNote(',
      ),
    );
    expect(save, contains('noteId: savedNoteId'));
    expect(
      notification,
      contains('=> scheduleNote('),
    );
  });

  test('mesmo notificationId é entregue à ponte canônica', () {
    expect(
      save,
      contains(
        'ClinicalTimerExternalBridge.'
        'adoptExistingNotification(',
      ),
    );
    expect(save, contains('notificationId: notifId'));
    expect(save, contains(r"payload: 'note:$savedNoteId'"));
    expect(save, contains('seconds: alertSeconds'));
    expect(save, contains('label: displayTitle'));
    expect(save, contains('lang: widget.lang'));
  });

  test('Notas não mantém callback Parar paralelo', () {
    expect(
      save,
      isNot(
        contains(
          'NotificationService.registerStopCallback(',
        ),
      ),
    );
    expect(
      count(
        notes,
        r'NotificationService\.registerStopCallback\s*\(',
      ),
      0,
    );
    expect(
      timer,
      contains('_registerEntryCallbacks(entry)'),
    );
  });

  test('adoção recusada cancela a notificação órfã', () {
    expect(save, contains('if (!registration.accepted)'));
    expect(
      save,
      contains(
        'await NotificationService.cancel(notifId)',
      ),
    );
    expect(
      RegExp(
        r"'Anotação salva, mas o lembrete não pôde ser '\s*"
        r"'adicionado ao Timer\.'",
      ).hasMatch(save),
      isTrue,
    );
    expect(
      RegExp(
        r"'Anotación guardada, pero el recordatorio no '\s*"
        r"'pudo añadirse al Timer\.'",
      ).hasMatch(save),
      isTrue,
    );
  });

  test('integração não cria engine ou agendamento paralelo', () {
    expect(
      count(
        timer,
        r'NotificationService\.scheduleTimer\s*\(',
      ),
      1,
    );
    expect(
      count(
        timer,
        r'Timer\.periodic\s*\(',
      ),
      3,
    );
    expect(save, isNot(contains('Timer.periodic(')));
    expect(
      save,
      isNot(
        contains(
          'NotificationService.scheduleTimer(',
        ),
      ),
    );
  });

  test('payload usa o ID canônico retornado pelo Firestore', () {
    expect(save, contains(r"payload: 'note:$savedNoteId'"));
    expect(
      save,
      isNot(
        contains(
          'DateTime.now().millisecondsSinceEpoch',
        ),
      ),
    );
  });
}
