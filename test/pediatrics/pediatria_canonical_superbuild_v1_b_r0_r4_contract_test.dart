import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final start = source.indexOf('class $className');
  expect(start, greaterThanOrEqualTo(0), reason: 'missing $className');
  final open = source.indexOf('{', start);
  expect(open, greaterThan(start));

  var depth = 0;
  var i = open;
  var inString = false;
  var quote = '';
  var lineComment = false;
  var blockComment = false;

  while (i < source.length) {
    if (lineComment) {
      if (source[i] == '\n') lineComment = false;
      i++;
      continue;
    }
    if (blockComment) {
      if (i + 1 < source.length && source.substring(i, i + 2) == '*/') {
        blockComment = false;
        i += 2;
      } else {
        i++;
      }
      continue;
    }
    if (inString) {
      if (source[i] == r'\') {
        i += 2;
        continue;
      }
      if (source[i] == quote) inString = false;
      i++;
      continue;
    }
    if (i + 1 < source.length && source.substring(i, i + 2) == '//') {
      lineComment = true;
      i += 2;
      continue;
    }
    if (i + 1 < source.length && source.substring(i, i + 2) == '/*') {
      blockComment = true;
      i += 2;
      continue;
    }
    if (source[i] == "'" || source[i] == '"') {
      inString = true;
      quote = source[i];
      i++;
      continue;
    }

    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
    i++;
  }

  throw StateError('unclosed $className');
}

void main() {
  final tools = File('lib/screens/tools_screen.dart').readAsStringSync();
  final home = File('lib/screens/home_screen.dart').readAsStringSync();

  group('Pediatria canonical superbuild V1-B-R0-R4', () {
    test('keeps productive topbar frozen at 48/16', () {
      final shellStart = home.indexOf('class _PediatricsShell');
      final adultStart = home.indexOf('// ADULTO SHELL', shellStart);
      expect(shellStart, greaterThanOrEqualTo(0));
      expect(adultStart, greaterThan(shellStart));
      final shell = home.substring(shellStart, adultStart);

      expect(shell, contains('MEDCASES_PEDIATRIA_HOME_TOPBAR_V1_B_R0'));
      expect(shell, isNot(contains('Size.fromHeight(48)')));
      expect(shell, contains('height: topPad + 48'));
      expect(shell, contains('height: 48'));
      expect(shell, contains('fontSize: 16'));
      expect(shell, contains('const Expanded(child: PediatricsTabContent())'));
    });

    test('uses final 0px gap and 44px four-segment navigation', () {
      expect(
        tools,
        contains(
          'MEDCASES_PEDIATRIA_CANONICAL_SUPERBUILD_V1_B_R0_R4_TRANSACTIONAL',
        ),
      );
      final tab = classBlock(tools, '_PediatTabRow');

      expect(tab, contains('height: 44'));
      expect(tab, contains('Color(0xFF2D3340)'));
      expect(tab, contains('Color(0xFFFFFFFF)'));
      expect(
        tab,
        contains('padding: const EdgeInsets.symmetric(horizontal: 8)'),
      );
      expect(tab, isNot(contains('return Expanded(')));
      expect(tab, contains('alignment: Alignment.center'));
      expect(
        tab,
        contains('padding: const EdgeInsets.symmetric(horizontal: 12)'),
      );
      expect(tab, contains('right: i < sections.length - 1'));
      expect(tab, contains('width: 0.7'));
      expect(tab, contains('width: active ? 2 : 0.7'));
      expect(tab, contains('fontSize: _PediatricsVisualScaleR3.tabLabel'));
      expect(tab, contains('height: 1'));
      expect(tab, contains('FontWeight.w800'));
      expect(tab, contains('FontWeight.w600'));
      expect(tab, isNot(contains('BoxFit.scaleDown')));
      expect(tab, contains('SingleChildScrollView('));
      expect(tab, isNot(contains('minWidth: 92')));
      expect(tab, contains('BoxConstraints(minWidth: 112)'));

      final state = classBlock(tools, '_PediatricsTabContentState');
      expect(state, contains('const SizedBox(height: 0)'));
      expect(
        state,
        contains('padding: const EdgeInsets.fromLTRB(0.1, 0.1, 0.1, 100)'),
      );
    });

    test('keeps PT ES section labels and all four clinical routes', () {
      final state = classBlock(tools, '_PediatricsTabContentState');

      expect(
        state,
        contains("const ['BIOMETRÍA', 'CRECIMIENTO', 'FUNCIÓN RENAL', 'PEWS']"),
      );
      expect(
        state,
        contains("const ['BIOMETRIA', 'CRESCIMENTO', 'FUNÇÃO RENAL', 'PEWS']"),
      );
      expect(state, contains('return _buildBiometria(isEs, c)'));
      expect(state, contains('return _buildGrowth(isEs, c)'));
      expect(state, contains('return _buildRenal(isEs, c)'));
      expect(state, contains('return _buildPews(isEs, c)'));
    });

    test('uses local compact pediatric density and compact inputs', () {
      final scale = classBlock(tools, '_PediatricsVisualScaleR3');
      expect(scale, contains('static const double tabLabel = 14.0'));
      expect(scale, contains('static const double sectionLabel = 13.0'));
      expect(scale, contains('static const double body = 14.5'));
      expect(scale, contains('static const double micro = 11.5'));
      expect(scale, contains('static const double inputText = 15.5'));
      expect(scale, contains('static const double hint = 14.0'));
      expect(scale, contains('static const double option = 14.5'));
      expect(scale, contains('static const double result = 15.5'));

      final input = classBlock(tools, '_PedCompactInput');
      expect(input, contains('height: 40'));
      expect(input, contains('borderRadius: BorderRadius.circular(8)'));
      expect(input, contains('fontSize: _PediatricsVisualScaleR3.inputText'));
      expect(input, contains('fontSize: _PediatricsVisualScaleR3.hint'));

      final state = classBlock(tools, '_PediatricsTabContentState');
      expect(state, contains('_PedCompactInput('));
      expect(state, isNot(contains('_LabeledInput(')));
    });

    test('compacts selectors sections metrics and PEWS without cards', () {
      final gap = classBlock(tools, '_PedSectionGap');
      final section = classBlock(tools, '_PedFlatSection');
      final metric = classBlock(tools, '_PedMetricRow');
      final sex = classBlock(tools, '_PedSexSelector');
      final growth = classBlock(tools, '_PedGrowthIndicatorToggle');
      final pewsSelector = classBlock(tools, '_PedPewsSelectorFlat');

      expect(gap, contains('SizedBox(height: 1)'));
      expect(section, contains('size: quietHeader ? 14 : 15'));
      expect(section, contains('SizedBox(height: quietHeader ? 7 : 5)'));
      expect(metric, contains('EdgeInsets.symmetric(vertical: 8)'));
      expect(sex, contains('height: 38'));
      expect(sex, contains('_PediatricsVisualScaleR3.option'));
      expect(growth, contains('height: 38'));
      expect(growth, contains('options.length * 2 - 1'));
      expect(growth, contains('return Expanded('));
      expect(
        pewsSelector,
        contains('EdgeInsets.symmetric(horizontal: 6, vertical: 6)'),
      );
      expect(pewsSelector, contains('width: 32'));
      expect(pewsSelector, contains('height: 24'));
    });

    test('keeps pediatric clinical engines and keyboard behavior intact', () {
      for (final token in <String>[
        'PediatricGrowthEngineV2026',
        'PediatricRenalEngineV2026',
        'BrightonPewsEngineV2026',
        'PediatricReferenceRegistryV2026',
        'CKiD U25',
        'CKiD bedside 2009',
        'MEDCASES_PEDS_2026_KEYBOARD_DISMISS_V1_B_R6_R1',
        'MEDCASES_PEDS_2026_REMOVE_DUPLICATE_NAV_V1_B_R7',
        'FocusManager.instance.primaryFocus?.unfocus()',
        'ScrollViewKeyboardDismissBehavior.onDrag',
      ]) {
        expect(tools, contains(token), reason: 'missing $token');
      }
    });
  });
}
