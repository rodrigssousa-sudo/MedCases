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
  late String owner;

  setUpAll(() {
    final history = File(
      'lib/screens/history_screen.dart',
    ).readAsStringSync();
    owner = classSlice(history, '_EvolutionEditorCardState');
  });

  test('card externo desaparece', () {
    expect(owner, contains('return Padding('));
    expect(owner, isNot(contains('return Container(')));
  });

  test('tipos são texto, sem preenchimento e com linha verde', () {
    expect(owner, contains('SingleChildScrollView('));
    expect(owner, contains('scrollDirection: Axis.horizontal'));
    expect(owner, contains('bottom: BorderSide('));
    expect(owner, contains('Color(0xFF10B981)'));
    expect(
      owner,
      contains(
        'decoration: BoxDecoration(\n'
        '                      border: Border(',
      ),
    );
    expect(owner, isNot(contains('backgroundColor')));
    expect(owner, isNot(contains('gradient:')));
    expect(owner, isNot(contains('ChoiceChip(')));
    expect(owner, isNot(contains('FilterChip(')));
  });

  test('seletor possui tamanho padrão maior', () {
    expect(owner, contains('height: 42'));
    expect(owner, contains('fontSize: MedTypography.sectionLabelSize'));
  });

  test('inputs são grafite com texto branco-claro', () {
    expect(owner, contains('fillColor: const Color(0xFF252930)'));
    expect(owner.split('TextField(').length - 1, 2);
    expect(
      owner.split('color: Color(0xFFE8F0EC)').length - 1,
      2,
    );
    expect(owner, contains('? const Color(0xFFE8F0EC)'));
    expect(owner, contains('Colors.white38'));
    expect(owner, contains('focusedBorder: OutlineInputBorder('));
  });

  test('nota possui altura confortável', () {
    expect(owner, contains('minLines: 4'));
    expect(owner, contains('maxLines: 7'));
  });

  test('data, exclusão, atualização e idiomas permanecem', () {
    for (final token in <String>[
      'DateTime.tryParse(widget.evo.date)',
      'widget.onDelete',
      '_update()',
      '_authorCtrl',
      '_textCtrl',
      "context.read<AppProvider>().lang",
      '_typeLabelsEs',
      '_typeLabels',
      "evol_author_hint",
      "evol_text_hint",
    ]) {
      expect(owner, contains(token), reason: token);
    }
  });
}
