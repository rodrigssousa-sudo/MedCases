import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

int count(String source, String pattern) =>
    RegExp(pattern, multiLine: true).allMatches(source).length;

String blockForClass(String source, String className) {
  final match = RegExp(
    '^class\\s+${RegExp.escape(className)}\\b',
    multiLine: true,
  ).firstMatch(source);

  if (match == null) {
    throw StateError('Class not found: $className');
  }

  final brace = source.indexOf('{', match.end);
  if (brace < 0) {
    throw StateError('Opening brace not found: $className');
  }

  return _balancedBlock(source, match.start, brace);
}

String blockForMethod(
  String source,
  String className,
  String methodPattern,
) {
  final classBlock = blockForClass(source, className);
  final match = RegExp(
    methodPattern,
    multiLine: true,
  ).firstMatch(classBlock);

  if (match == null) {
    throw StateError(
      'Method not found in $className: $methodPattern',
    );
  }

  final openingParen = classBlock.indexOf(
    '(',
    match.start,
  );
  if (openingParen < 0) {
    throw StateError('Method opening parenthesis not found');
  }

  var parenDepth = 0;
  var closingParen = -1;

  for (var index = openingParen;
      index < classBlock.length;
      index += 1) {
    final char = classBlock[index];

    if (char == '(') {
      parenDepth += 1;
    } else if (char == ')') {
      parenDepth -= 1;
      if (parenDepth == 0) {
        closingParen = index;
        break;
      }
    }
  }

  if (closingParen < 0) {
    throw StateError('Method closing parenthesis not found');
  }

  final brace = classBlock.indexOf(
    '{',
    closingParen + 1,
  );

  if (brace < 0) {
    throw StateError('Method body opening brace not found');
  }

  return _balancedBlock(
    classBlock,
    match.start,
    brace,
  );
}

String _balancedBlock(
  String source,
  int start,
  int openingBrace,
) {
  var depth = 0;
  var index = openingBrace;
  var inLineComment = false;
  var inBlockComment = false;
  String? quote;

  while (index < source.length) {
    final char = source[index];
    final next =
        index + 1 < source.length ? source[index + 1] : '';

    if (inLineComment) {
      if (char == '\n') inLineComment = false;
    } else if (inBlockComment) {
      if (char == '*' && next == '/') {
        inBlockComment = false;
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
        inLineComment = true;
        index += 1;
      } else if (char == '/' && next == '*') {
        inBlockComment = true;
        index += 1;
      } else if (char == "'" || char == '"') {
        quote = char;
      } else if (char == '{') {
        depth += 1;
      } else if (char == '}') {
        depth -= 1;
        if (depth == 0) {
          return source.substring(start, index + 1);
        }
      }
    }

    index += 1;
  }

  throw StateError('Unbalanced block');
}

void main() {
  final timer = read('lib/screens/home_screen.dart');
  final notes = read('lib/screens/notes_screen.dart');

  test('ponte pública existe sem possuir engine própria', () {
    final bridge = blockForClass(
      timer,
      'ClinicalTimerExternalBridge',
    );

    expect(bridge, contains('adoptExistingNotification'));
    expect(bridge, contains('_handlers'));
    expect(bridge, isNot(contains('Timer.periodic(')));
    expect(
      bridge,
      isNot(
        contains('NotificationService.scheduleTimer('),
      ),
    );
    expect(
      bridge,
      isNot(
        contains('NotificationService.scheduleNote('),
      ),
    );
  });

  test('owner adota o mesmo notificationId na coleção canônica', () {
    final method = blockForMethod(
      timer,
      '_HistorialCompactCardState',
      r'Future<ClinicalTimerExternalRegistrationResult>\s+'
      r'_adoptExistingNotification\s*\(',
    );

    expect(
      method,
      contains(
        'Future<ClinicalTimerExternalRegistrationResult>',
      ),
    );
    expect(method, contains('notificationId: notificationId'));
    expect(method, contains('_timers.add(entry)'));
    expect(method, contains('_registerEntryCallbacks(entry)'));
    expect(method, contains('_publishTimerVisualState()'));
    expect(method, contains('await _persistTimers()'));
    expect(method, contains('_startTicker()'));
    expect(
      method,
      isNot(
        contains('NotificationService.scheduleTimer('),
      ),
    );
    expect(
      method,
      isNot(
        contains('NotificationService.scheduleNote('),
      ),
    );
    expect(
      method,
      isNot(
        contains('NotificationService.scheduleNoteAlert('),
      ),
    );
    expect(method, isNot(contains('Timer.periodic(')));
  });

  test('modelo persiste payload, idioma e origem', () {
    final entry = blockForClass(
      timer,
      '_ClinicalTimerEntry',
    );

    expect(entry, contains('final String payload'));
    expect(entry, contains('final String lang'));
    expect(entry, contains("'payload': payload"));
    expect(entry, contains("'lang': lang"));
    expect(entry, contains("'source': source"));
    expect(entry, contains("payload.startsWith('note:')"));
    expect(entry, contains("payload.startsWith('cockpit:')"));
  });

  test('lifecycle registra e remove apenas o encaminhador', () {
    final owner = blockForClass(
      timer,
      '_HistorialCompactCardState',
    );

    expect(owner, contains('ClinicalTimerExternalBridge._bind('));
    expect(owner, contains('handler: _adoptExistingNotification,'));
    expect(owner, contains('ClinicalTimerExternalBridge._unbind(this)'));
  });

  test('callbacks externos usam a mesma entrada e preservam snooze', () {
    final callbacks = blockForMethod(
      timer,
      '_HistorialCompactCardState',
      r'void\s+_registerEntryCallbacks\s*\(',
    );
    final snooze = blockForMethod(
      timer,
      '_HistorialCompactCardState',
      r'Future<void>\s+_snoozeTimerEntry\s*\(',
    );

    expect(callbacks, contains('_cancelTimerById(entry.notificationId)'));
    expect(callbacks, contains('_snoozeTimerEntry(entry, minutes)'));
    expect(snooze, contains("entry.source != 'note'"));
    expect(snooze, contains('NotificationService.scheduleNote('));
    expect(snooze, contains('payload: entry.payload'));
  });

  test('Timer existente não ganhou engine ou agendamento duplicado', () {
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
    expect(
      count(
        timer,
        r'Future<void>\s+startFromShiftConsumer\s*\(',
      ),
      1,
    );
  });

  test('Notas consome a ponte sem possuir motor paralelo', () {
    expect(
      count(
        notes,
        r'NotificationService\.scheduleNoteAlert\s*\(',
      ),
      1,
    );
    expect(
      count(
        notes,
        r'ClinicalTimerExternalBridge\.'
        r'adoptExistingNotification\s*\(',
      ),
      1,
    );
    expect(
      count(
        notes,
        r'NotificationService\.registerStopCallback\s*\(',
      ),
      0,
    );
    expect(
      count(
        notes,
        r'NotificationService\.scheduleTimer\s*\(',
      ),
      0,
    );
    expect(
      count(
        notes,
        r'Timer\.periodic\s*\(',
      ),
      0,
    );
  });
}
