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

  group('Pediatria topbar subnav zero gap final V1-B-R0-R2', () {
    test('uses 0px spacer immediately before pediatric subnav', () {
      final state = classBlock(tools, '_PediatricsTabContentState');
      final normalized = state.replaceAll(RegExp(r'\s+'), ' ');

      expect(normalized, contains('const SizedBox(height: 0), _PediatTabRow('));
      expect(
        normalized,
        isNot(contains('const SizedBox(height: 5), _PediatTabRow(')),
      );
    });

    test('preserves 44px pediatric subnav geometry', () {
      final nav = classBlock(tools, '_PediatTabRow');

      expect(nav, contains('height: 44'));
      expect(
        nav,
        contains('padding: const EdgeInsets.symmetric(horizontal: 8)'),
      );
      expect(
        nav,
        contains('padding: const EdgeInsets.symmetric(horizontal: 12)'),
      );
      expect(nav, contains('right: i < sections.length - 1'));
    });

    test('preserves 0.1px content geometry below subnav', () {
      final state = classBlock(tools, '_PediatricsTabContentState');
      expect(
        state,
        contains('padding: const EdgeInsets.fromLTRB(0.1, 0.1, 0.1, 100)'),
      );
    });

    test('preserves bilingual pediatric sections', () {
      expect(
        tools,
        contains("const ['BIOMETRÍA', 'CRECIMIENTO', 'FUNCIÓN RENAL', 'PEWS']"),
      );
      expect(
        tools,
        contains("const ['BIOMETRIA', 'CRESCIMENTO', 'FUNÇÃO RENAL', 'PEWS']"),
      );
    });

    test('preserves pediatric clinical engine bindings', () {
      for (final token in <String>[
        'PediatricGrowthEngineV2026',
        'PediatricRenalEngineV2026',
        'BrightonPewsEngineV2026',
        'PediatricReferenceRegistryV2026',
      ]) {
        expect(tools, contains(token), reason: token);
      }
    });
  });
}
