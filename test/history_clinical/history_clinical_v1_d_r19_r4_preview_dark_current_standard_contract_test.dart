import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classSlice(String source, String name) {
  final pattern = RegExp(
    '^\\s*class\\s+${RegExp.escape(name)}\\b[^\\{]*\\{',
    multiLine: true,
  );
  final matches = pattern.allMatches(source).toList();
  expect(matches, hasLength(1), reason: name);

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
  late String preview;
  late String header;
  late String section;
  late String item;
  late String highlight;
  late String meta;

  setUpAll(() {
    history = File(
      'lib/screens/history_screen.dart',
    ).readAsStringSync();
    preview = classSlice(history, '_HistoryPreviewSheet');
    header = classSlice(history, '_PreviewDocHeader');
    section = classSlice(history, '_PreviewSection');
    item = classSlice(history, '_PreviewItem');
    highlight = classSlice(history, '_PreviewItemHighlight');
    meta = classSlice(history, '_MetaChip');
  });

  test('superfície raiz é grafite e usa o novo raio', () {
    expect(preview, contains('Color(0xFF1A1D23)'));
    expect(preview, contains('Radius.circular(22)'));
    expect(preview, isNot(contains('Radius.circular(24)')));
  });

  test('header principal é plano e sem gradiente', () {
    expect(preview, isNot(contains('LinearGradient(')));
    expect(preview, contains('Color(0xFF252930)'));
    expect(preview, contains('Navigator.pop(context)'));
  });

  test('documento e seções são cardless', () {
    expect(header, isNot(contains('0xFFF8FAFB')));
    expect(header, contains('bottom: BorderSide('));
    expect(section, isNot(contains('BoxShadow(')));
    expect(section, isNot(contains('color: Colors.white')));
    expect(section, contains('bottom: BorderSide('));
  });

  test('texto clínico usa contraste escuro atual', () {
    expect(item, isNot(contains('Color(0xFF222222)')));
    expect(item, contains('Color(0xFFE8F0EC)'));
    expect(highlight, contains('Color(0xFF252930)'));
    expect(highlight, contains('left: BorderSide('));
  });

  test('metadados usam superfície discreta', () {
    expect(meta, contains('Color(0xFF2D3340)'));
    expect(meta, contains('Color(0xFF374151)'));
  });

  test('conteúdo e comportamento produtivos permanecem', () {
    for (final token in <String>[
      'DraggableScrollableSheet(',
      'controller: ctrl',
      'static bool _hasAny',
      'static String _outcomeLabel',
      'Documento gerado em',
      'Documento generado el',
      'history.outcome',
    ]) {
      expect(preview, contains(token), reason: token);
    }

    for (final token in <String>[
      'history.patientSex',
      'history.category',
    ]) {
      expect(header, contains(token), reason: token);
    }
  });
}
