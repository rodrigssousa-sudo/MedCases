import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String classBlock(String s, String name) {
  final a = s.indexOf('class $name');
  expect(a, greaterThanOrEqualTo(0), reason: name);
  final b = s.indexOf('\nclass ', a + 7);
  return b < 0 ? s.substring(a) : s.substring(a, b);
}

void main() {
  final tools = File('lib/screens/tools_screen.dart').readAsStringSync();

  test('Pediatria uses 12px subnav label', () {
    final scale = classBlock(tools, '_PediatricsVisualScaleR3');
    final nav = classBlock(tools, '_PediatTabRow');
    expect(scale, contains('static const double tabLabel = 12.0;'));
    expect(scale, isNot(contains('static const double tabLabel = 14.0;')));
    expect(nav, contains('height: 40'));
    expect(nav, contains('SingleChildScrollView('));
    expect(nav, contains('scrollDirection: Axis.horizontal'));
    expect(nav, contains('constraints: const BoxConstraints(minWidth: 112)'));
    expect(nav, contains('fontSize: _PediatricsVisualScaleR3.tabLabel'));
    expect(nav, contains('bottom: 9'));
    expect(nav, contains('onTap: () => onSelect(i)'));
  });

  test('Pediatria uses 19.2px lateral gutter with vertical geometry frozen',
      () {
    final state = classBlock(tools, '_PediatricsTabContentState');
    expect(state,
        contains('padding: const EdgeInsets.fromLTRB(19.2, 0.1, 19.2, 100)'));
    expect(
        state,
        isNot(contains(
            'padding: const EdgeInsets.fromLTRB(0.1, 0.1, 0.1, 100)')));
  });

  test('PT ES routes and pediatric clinical engines remain', () {
    for (final token in const <String>[
      "const ['BIOMETRÍA', 'CRECIMIENTO', 'FUNCIÓN RENAL', 'PEWS']",
      "const ['BIOMETRIA', 'CRESCIMENTO', 'FUNÇÃO RENAL', 'PEWS']",
      'return _buildBiometria(isEs, c)',
      'return _buildGrowth(isEs, c)',
      'return _buildRenal(isEs, c)',
      'return _buildPews(isEs, c)',
      'PediatricGrowthEngineV2026',
      'PediatricRenalEngineV2026',
      'BrightonPewsEngineV2026',
      'PediatricReferenceRegistryV2026',
    ]) {
      expect(tools, contains(token), reason: token);
    }
  });
}
