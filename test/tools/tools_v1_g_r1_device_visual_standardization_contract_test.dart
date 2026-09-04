import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String name) {
  final start = RegExp(
    '^class\\s+${RegExp.escape(name)}\\b',
    multiLine: true,
  ).firstMatch(source);

  if (start == null) {
    throw StateError('$name ausente');
  }

  final opening = source.indexOf('{', start.end);
  if (opening < 0) {
    throw StateError('$name sem abertura');
  }

  var depth = 0;
  var quote = '';
  var state = 'code';
  var raw = false;

  for (var i = opening; i < source.length; i++) {
    final char = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';

    if (state == 'line') {
      if (char == '\n') state = 'code';
      continue;
    }

    if (state == 'block') {
      if (char == '*' && next == '/') {
        state = 'code';
        i++;
      }
      continue;
    }

    if (state == 'string') {
      if (!raw && char == '\\') {
        i++;
        continue;
      }
      if (char == quote) {
        state = 'code';
        raw = false;
      }
      continue;
    }

    if (char == '/' && next == '/') {
      state = 'line';
      i++;
      continue;
    }

    if (char == '/' && next == '*') {
      state = 'block';
      i++;
      continue;
    }

    if (char == 'r' && next.isNotEmpty && (next == "'" || next == '"')) {
      raw = true;
      quote = next;
      state = 'string';
      i++;
      continue;
    }

    if (char == "'" || char == '"') {
      quote = char;
      state = 'string';
      continue;
    }

    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(start.start, i + 1);
      }
    }
  }

  throw StateError('$name sem fechamento');
}

void main() {
  late String tools;
  late String importChip;
  late String nephro;
  late String cardio;
  late String electro;
  late String hepato;

  setUpAll(() {
    tools = File('lib/screens/tools_screen.dart').readAsStringSync();
    importChip =
        File('lib/screens/tools_patient_import.dart').readAsStringSync();
    nephro =
        File('lib/screens/nephrology_tools_screen.dart').readAsStringSync();
    cardio = File('lib/screens/cardio_tools_screen.dart').readAsStringSync();
    electro =
        File('lib/screens/electrolytes_tools_screen.dart').readAsStringSync();
    hepato =
        File('lib/screens/hepatology_tools_screen.dart').readAsStringSync();
  });

  test('TOOLS V1-G-R1 — status bar sangra a mesma cor do topbar', () {
    final owner = classBlock(tools, '_ToolsScreenState');

    expect(
      owner,
      contains('AnnotatedRegion<SystemUiOverlayStyle>('),
    );
    expect(
      owner,
      contains('statusBarColor: Color(0xFF252930)'),
    );
    expect(
      owner,
      contains('ColoredBox('),
    );
  });

  test('TOOLS V1-G-R1 — importação compartilhada é verde e delicada', () {
    final owner = classBlock(importChip, 'ToolsPatientImportChip');

    expect(owner, contains('Color(0xFF10B981)'));
    expect(owner, contains('BorderRadius.circular(12)'));
    expect(owner, isNot(contains('boxShadow:')));
    expect(owner, isNot(contains('final accent = dark ? _kCyan')));
  });

  test('TOOLS V1-G-R1 — calcular é verde e usa metade da largura', () {
    final owners = <String>[
      classBlock(nephro, '_CalcButton'),
      classBlock(cardio, '_CardioBodyState'),
      classBlock(electro, '_ElectroBodyState'),
      classBlock(hepato, '_CalcButton'),
    ];

    for (final owner in owners) {
      expect(
        owner,
        contains('TOOLS V1-G-R1-R3: calcular delicado padronizado'),
      );
      expect(owner, contains('FractionallySizedBox('));
      expect(owner, contains('widthFactor: 0.5'));
      expect(owner, contains('Color(0xFF10B981)'));
      expect(owner, contains('SizedBox('));
      expect(owner, contains('height: 42'));
    }
  });

  test('TOOLS V1-G-R1 — sexo usa masculino azul e feminino rosa', () {
    final nephroOption = classBlock(nephro, '_SexOption');
    final cardioToggle = classBlock(cardio, '_SexToggle');

    for (final owner in [nephroOption, cardioToggle]) {
      expect(owner, contains('Color(0xFF3B82F6)'));
      expect(owner, contains('Color(0xFFEC4899)'));
    }
  });

  test('TOOLS V1-G-R1 — inputs e seletores compartilham superfície', () {
    final owners = <String>[
      classBlock(nephro, '_FieldBox'),
      classBlock(nephro, '_SexToggle'),
      classBlock(cardio, '_NField'),
      classBlock(cardio, '_SexToggle'),
      classBlock(electro, '_NField'),
      classBlock(hepato, '_FieldBox'),
      classBlock(hepato, '_FieldBoxFreeText'),
      classBlock(hepato, '_ScoreSelector'),
      classBlock(hepato, '_BoolToggle'),
      classBlock(hepato, '_DialysisToggle'),
    ];

    for (final owner in owners) {
      expect(owner, contains('Color(0xFF2D3340)'));
      expect(owner, contains('Color(0xFF374151)'));
      expect(owner, contains('BorderRadius.circular(10)'));
    }
  });
}
