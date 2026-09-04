import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

String classBlock(String source, String name) {
  final m = RegExp(
    '^class\\s+${RegExp.escape(name)}\\b',
    multiLine: true,
  ).firstMatch(source);
  expect(m, isNotNull, reason: name);
  final open = source.indexOf('{', m!.start);
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(m.start, i + 1);
    }
  }
  fail('Unclosed $name');
}

void main() {
  late String nefro;
  late String cardio;
  late String electro;
  late String hepato;

  setUpAll(() {
    nefro = read('lib/screens/nephrology_tools_screen.dart');
    cardio = read('lib/screens/cardio_tools_screen.dart');
    electro = read('lib/screens/electrolytes_tools_screen.dart');
    hepato = read('lib/screens/hepatology_tools_screen.dart');
  });

  test('light section headings use graphite hierarchy', () {
    expect(classBlock(nefro, '_SectionLabel'), contains('Color(0xFF334155)'));
    expect(classBlock(cardio, '_InputCard'), contains('Color(0xFF334155)'));
    expect(classBlock(electro, '_InputCard'), contains('Color(0xFF334155)'));
    expect(classBlock(hepato, '_SectionLabel'), contains('Color(0xFF334155)'));
  });

  test('cardio sex selector is light-surface aware', () {
    final sex = classBlock(cardio, '_SexToggle');
    expect(
      sex,
      contains('MEDCASES_FERRAMENTAS_CARDIO_LIGHT_SEX_SELECTOR_V1_B_R0_R3'),
    );
    expect(
      sex,
      contains('color: isDk ? const Color(0xFF2D3340) : Colors.white'),
    );
    expect(sex, contains('Color(0xFFD8E0E7)'));
    expect(sex, contains('Color(0xFFEFF6FF)'));
    expect(sex, contains('Color(0xFF1D4ED8)'));
    expect(sex, contains('Color(0xFFFDF2F8)'));
    expect(sex, contains('Color(0xFFBE185D)'));
    expect(sex, contains('onTap: () => onChanged(false)'));
    expect(sex, contains('onTap: () => onChanged(true)'));
  });

  test('cardio risk selectors are white or mint in light mode', () {
    final risk = classBlock(cardio, '_ToggleRow');
    expect(
      risk,
      contains('MEDCASES_FERRAMENTAS_CARDIO_LIGHT_RISK_SELECTOR_V1_B_R0_R3'),
    );
    expect(risk, contains('final dark = Theme.of(context).brightness'));
    expect(risk, contains('Color(0xFFECFDF5)'));
    expect(risk, contains('Color(0xFF047857)'));
    expect(risk, contains('Color(0xFFD8E0E7)'));
    expect(risk, contains('Color(0xFF111318)'));
    expect(risk, contains('onTap: () => item.onChanged(!item.value)'));
  });

  test('dark selector colors remain explicitly available', () {
    final sex = classBlock(cardio, '_SexToggle');
    final risk = classBlock(cardio, '_ToggleRow');
    expect(sex, contains('Color(0xFF2D3340)'));
    expect(sex, contains('Color(0xFF374151)'));
    expect(sex, contains('Color(0xFF3B82F6)'));
    expect(sex, contains('Color(0xFFEC4899)'));
    expect(risk, contains('Color(0xFF2D3340)'));
    expect(risk, contains('Color(0xFF374151)'));
  });

  test('premium results contract is still present in all four tabs', () {
    for (final source in [nefro, cardio, electro, hepato]) {
      final card = classBlock(source, '_ResultCard');
      expect(
        card,
        contains(
          'MEDCASES_FERRAMENTAS_RESULTS_CANONICAL_PREMIUM_COMPACT_LAYOUT_V1_B_R0',
        ),
      );
      expect(card, contains('BorderRadius.circular(8)'));
      expect(classBlock(source, '_DeeplinkButton'), contains('height: 42'));
    }
  });

  test('keyboard and shared-state contracts remain present', () {
    for (final source in [nefro, cardio, electro, hepato]) {
      expect(source, contains('decoration: TextDecoration.none'));
      expect(source, contains('Icons.arrow_forward_rounded'));
      expect(source, contains('context.watch<ToolsStateProvider>()'));
      expect(source, contains('Scrollable.ensureVisible('));
    }
  });
}
