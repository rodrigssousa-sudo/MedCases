import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final start = source.indexOf('class $className');
  expect(start, greaterThanOrEqualTo(0), reason: className);
  final next = source.indexOf('\nclass ', start + 7);
  return next < 0 ? source.substring(start) : source.substring(start, next);
}

void main() {
  final tools = File('lib/screens/tools_screen.dart').readAsStringSync();

  group('Pediatria final Light surface contrast V1-B-R0', () {
    test('uses darker page and white navigation in Light mode', () {
      final state = classBlock(tools, '_PediatricsTabContentState');
      final nav = classBlock(tools, '_PediatTabRow');

      expect(
        state,
        contains(
          'p.darkMode ? const Color(0xFF1A1D23) : const Color(0xFFE7ECEF)',
        ),
      );
      expect(
        nav,
        contains(
          'dark ? const Color(0xFF2D3340) : const Color(0xFFFFFFFF)',
        ),
      );
    });

    test('keeps input surface white and Dark input unchanged', () {
      final input = classBlock(tools, '_PedCompactInput');
      expect(
        input,
        contains(
          'dark ? const Color(0xFF1F232A) : const Color(0xFFFFFFFF)',
        ),
      );
      expect(input, contains('height: 40'));
    });

    test('uses white inactive biological sex selector in Light mode', () {
      final sex = classBlock(tools, '_PedSexSelector');
      expect(
        sex,
        contains(
          'dark ? Colors.transparent : const Color(0xFFFFFFFF)',
        ),
      );
    });

    test('preserves final geometry and divider cleanup', () {
      final state = classBlock(tools, '_PediatricsTabContentState');
      final nav = classBlock(tools, '_PediatTabRow');

      expect(state, contains('const SizedBox(height: 0)'));
      expect(
        state,
        contains('padding: const EdgeInsets.fromLTRB(0.1, 0.1, 0.1, 100)'),
      );
      expect(nav, contains('height: 44'));
      expect(nav, contains('width: active ? 2 : 0.7'));

      for (final name in <String>[
        '_PedMetricRow',
        '_PedVitalRow',
        '_PedPewsSelectorFlat',
        '_PedCheckRow',
      ]) {
        final normalized = classBlock(
          tools,
          name,
        ).replaceAll(RegExp(r'\s+'), '');
        expect(normalized, isNot(contains('Border(bottom:')), reason: name);
      }
    });

    test('preserves clinical engines and PT ES', () {
      for (final token in <String>[
        'PediatricGrowthEngineV2026',
        'PediatricRenalEngineV2026',
        'BrightonPewsEngineV2026',
        'PediatricReferenceRegistryV2026',
        "const ['BIOMETRÍA', 'CRECIMIENTO', 'FUNCIÓN RENAL', 'PEWS']",
        "const ['BIOMETRIA', 'CRESCIMENTO', 'FUNÇÃO RENAL', 'PEWS']",
      ]) {
        expect(tools, contains(token), reason: token);
      }
    });
  });
}
