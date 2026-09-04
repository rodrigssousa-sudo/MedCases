import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classSlice(String source, String name) {
  final pattern = RegExp(
    '^\\s*class\\s+${RegExp.escape(name)}\\b[^\\{]*\\{',
    multiLine: true,
  );
  final matches = pattern.allMatches(source).toList();
  expect(matches, hasLength(1), reason: 'owner $name deve existir uma vez');

  final opening = source.indexOf('{', matches.single.start);
  var depth = 0;
  var quote = '';
  var inString = false;
  var escaped = false;

  for (var index = opening; index < source.length; index++) {
    final char = source[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == quote) {
        inString = false;
      }
      continue;
    }
    if (char == "'" || char == '"') {
      inString = true;
      quote = char;
      continue;
    }
    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(matches.single.start, index + 1);
      }
    }
  }
  fail('owner $name sem fechamento');
}

void main() {
  late String owner;

  setUpAll(() {
    final source = File(
      'lib/screens/history_screen.dart',
    ).readAsStringSync();
    owner = classSlice(source, '_MicControlBar');
  });

  test('owner não possui override duplicado', () {
    expect(owner, isNot(contains('@override\n  @override')));
  });

  test('fechado ocupa metade da largura e permanece azul', () {
    expect(owner, contains('widthFactor: 0.5'));
    expect(owner, contains('Color(0xFF14213D)'));
    expect(owner, contains('if (!expanded)'));
  });

  test('aberto usa grafite e não o grande card azul', () {
    expect(owner, contains('Color(0xFF1A1D23)'));
    expect(owner, contains('Color(0xFF252930)'));
    expect(owner.split('Color(0xFF14213D)').length - 1, 1);
    expect(owner.split('Color(0xFF147D64)').length - 1, 1);
  });

  test('ações abertas são segmentadas e navegação é compacta', () {
    expect(owner.split('VerticalDivider(').length - 1, 2);
    expect(owner.split('IconButton(').length - 1, 2);
    expect(owner, isNot(contains('_FieldNavBar(')));
  });

  test('callbacks produtivos permanecem', () {
    for (final token in <String>[
      'onToggleExpand',
      'onTapSmart',
      'onTapRelato',
      'onOrganizarIA',
      'onPrevField',
      'onNextField',
    ]) {
      expect(owner, contains(token));
    }
  });

  test('barra numérica Próximo e OK permanece', () {
    expect(owner, contains('numericKeyboardMode'));
    expect(owner, contains('focusedWidget is EditableText'));
    expect(owner, contains("'Próximo'"));
    expect(owner, contains("'OK'"));
    expect(owner, contains('FocusScope.of(context).unfocus()'));
  });

  test('estados de ditado e processamento permanecem', () {
    for (final token in <String>[
      'smartActive',
      'sttListening',
      'relatoActive',
      'aiProcessing',
      'smartInterim',
      'relatoInterim',
    ]) {
      expect(owner, contains(token));
    }
  });
}
