import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classSlice(String source, String name) {
  final pattern = RegExp(
    '^\\s*class\\s+${RegExp.escape(name)}\\b[^\\{]*\\{',
    multiLine: true,
  );
  final matches = pattern.allMatches(source).toList();
  expect(matches, hasLength(1));

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
  late String history;
  late String editor;
  late String mic;

  setUpAll(() {
    history = File('lib/screens/history_screen.dart').readAsStringSync();
    editor = classSlice(history, '_HistoryEditorState');
    mic = classSlice(history, '_MicControlBar');
  });

  test('teclado textual oculta completamente Ditado e IA', () {
    expect(mic, contains('final keyboardTextMode ='));
    expect(mic, contains('if (keyboardTextMode)'));
    expect(mic, contains('return const SizedBox.shrink();'));
  });

  test('barra numérica Próximo e OK precede o ocultamento', () {
    expect(
      mic.indexOf('if (numericKeyboardMode)'),
      lessThan(mic.indexOf('if (keyboardTextMode)')),
    );
    expect(mic, contains("'Próximo'"));
    expect(mic, contains("'OK'"));
    expect(mic, contains('FocusScope.of(context).unfocus()'));
  });

  test('editor reduz reservas durante digitação', () {
    expect(editor, contains('final keyboardFocusMode ='));
    expect(editor, contains('final micPad = keyboardFocusMode'));
    expect(editor, contains('? 16.0'));
    expect(editor, contains('keyboardFocusMode ? 12 : 26'));
  });

  test('botão azul de metade da largura permanece', () {
    expect(mic, contains('widthFactor: 0.5'));
    expect(mic, contains('Color(0xFF14213D)'));
  });

  test('painel grafite e callbacks permanecem', () {
    expect(mic, contains('Color(0xFF1A1D23)'));
    expect(mic, contains('Color(0xFF252930)'));
    for (final token in <String>[
      'onToggleExpand',
      'onTapSmart',
      'onTapRelato',
      'onOrganizarIA',
      'onPrevField',
      'onNextField',
    ]) {
      expect(mic, contains(token));
    }
  });
}
