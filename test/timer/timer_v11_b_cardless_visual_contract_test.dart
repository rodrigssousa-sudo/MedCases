import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

int balancedClassEnd(String source, int opening) {
  var depth = 0;
  var state = 'code';
  var quote = '';
  var index = opening;

  while (index < source.length) {
    final char = source[index];
    final next = index + 1 < source.length
        ? source[index + 1]
        : '';

    if (state == 'line') {
      if (char == '\n') {
        state = 'code';
      }
    } else if (state == 'block') {
      if (char == '*' && next == '/') {
        state = 'code';
        index += 1;
      }
    } else if (state == 'string') {
      if (char == r'\') {
        index += 1;
      } else if (char == quote) {
        state = 'code';
      }
    } else {
      if (char == '/' && next == '/') {
        state = 'line';
        index += 1;
      } else if (char == '/' && next == '*') {
        state = 'block';
        index += 1;
      } else if (char == "'" || char == '"') {
        state = 'string';
        quote = char;
      } else if (char == '{') {
        depth += 1;
      } else if (char == '}') {
        depth -= 1;
        if (depth == 0) {
          return index + 1;
        }
      }
    }

    index += 1;
  }

  throw StateError('Classe sem fechamento balanceado');
}

String classBlock(String source, String className) {
  final matches = RegExp(
    '^class\\s+${RegExp.escape(className)}\\b',
    multiLine: true,
  ).allMatches(source).toList();

  if (matches.length != 1) {
    throw StateError(
      'Classe $className: ${matches.length} ocorrências',
    );
  }

  final match = matches.single;
  final opening = source.indexOf('{', match.end);

  if (opening < 0) {
    throw StateError('Abertura ausente: $className');
  }

  final end = balancedClassEnd(source, opening);
  return source.substring(match.start, end);
}

int countMatches(String source, Pattern pattern) {
  if (pattern is RegExp) {
    return pattern.allMatches(source).length;
  }

  if (pattern is String) {
    var count = 0;
    var offset = 0;

    while (true) {
      final index = source.indexOf(pattern, offset);
      if (index < 0) return count;
      count += 1;
      offset = index + pattern.length;
    }
  }

  throw ArgumentError('Pattern não suportado');
}

void main() {
  late String setup;
  late String alert;

  setUpAll(() {
    setup = classBlock(
      File('lib/screens/home_screen.dart').readAsStringSync(),
      '_PomodoroSheetState',
    );
    alert = classBlock(
      File(
        'lib/services/notification_service.dart',
      ).readAsStringSync(),
      '_NotifDialogState',
    );
  });

  group('Timer V11-B — owners e comportamento preservados', () {
    test('owner do painel e métodos canônicos permanecem', () {
      for (final token in <String>[
        '_confirm(',
        '_customField(',
        '_patientField(',
        '_preset(',
        '_primaryAction(',
        '_timerRow(',
        'initState(',
        'dispose(',
      ]) {
        expect(setup, contains(token));
      }
    });

    test('owner do alerta e adiamento permanecem', () {
      expect(alert, contains('_snooze('));
      expect(alert, contains('_channelForPayload('));
      expect(alert, contains('build('));
    });

    test('textos produtivos do painel permanecem', () {
      for (final token in <String>[
        'Timer clínico',
        'Revisão programada',
        'Tempo personalizado',
        'Paciente / Box',
        'Programar revisão',
      ]) {
        expect(setup, contains(token));
      }
    });

    test('textos produtivos do alerta permanecem', () {
      for (final token in <String>[
        'REVISÃO CLÍNICA',
        'Hora de revisar o paciente',
        'Adiar',
        'Encerrar timer',
        'Fechar',
      ]) {
        expect(alert, contains(token));
      }
    });
  });

  group('Timer V11-B — contrato visual sem cards', () {
    test('RED 01 — painel limita BoxDecoration', () {
      expect(
        countMatches(setup, 'BoxDecoration('),
        lessThanOrEqualTo(3),
      );
    });

    test('RED 02 — painel limita Border.all', () {
      expect(
        countMatches(setup, 'Border.all('),
        lessThanOrEqualTo(2),
      );
    });

    test('RED 03 — painel limita raios arredondados', () {
      expect(
        countMatches(setup, 'BorderRadius.circular('),
        lessThanOrEqualTo(6),
      );
    });

    test('RED 04 — painel possui uma única ação preenchida', () {
      expect(
        countMatches(
          setup,
          RegExp(r'\b(?:FilledButton|ElevatedButton)\b'),
        ),
        1,
      );
    });

    test('RED 05 — painel limita ações contornadas', () {
      expect(
        countMatches(setup, RegExp(r'\bOutlinedButton\b')),
        lessThanOrEqualTo(1),
      );
    });

    test('RED 06 — alerta limita BoxDecoration', () {
      expect(
        countMatches(alert, 'BoxDecoration('),
        lessThanOrEqualTo(2),
      );
    });

    test('RED 07 — alerta limita Border.all', () {
      expect(
        countMatches(alert, 'Border.all('),
        lessThanOrEqualTo(2),
      );
    });

    test('RED 08 — alerta limita raios arredondados', () {
      expect(
        countMatches(alert, 'BorderRadius.circular('),
        lessThanOrEqualTo(4),
      );
    });

    test('RED 09 — alerta possui uma única ação preenchida', () {
      expect(
        countMatches(
          alert,
          RegExp(r'\b(?:FilledButton|ElevatedButton)\b'),
        ),
        1,
      );
    });

    test('RED 10 — alerta limita ações contornadas', () {
      expect(
        countMatches(alert, RegExp(r'\bOutlinedButton\b')),
        lessThanOrEqualTo(1),
      );
    });
  });
}
