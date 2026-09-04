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

  group('Pediatria final type scale and card geometry V1-B-R0', () {
    test('raises local pediatric text scale exactly 3px', () {
      final scale = classBlock(tools, '_PediatricsVisualScaleR3');

      for (final token in <String>[
        'static const double tabLabel = 14.0',
        'static const double sectionLabel = 13.0',
        'static const double body = 14.5',
        'static const double micro = 11.5',
        'static const double inputText = 15.5',
        'static const double hint = 14.0',
        'static const double option = 14.5',
        'static const double result = 15.5',
      ]) {
        expect(scale, contains(token), reason: token);
      }

      expect(
        classBlock(tools, '_PedMetricRow'),
        contains('fontSize: valueSmall ? 13.5'),
      );
      expect(
        classBlock(tools, '_PedNavRow'),
        contains('fontSize: 14.5'),
      );
      expect(
        classBlock(tools, '_PedNavRow'),
        contains('fontSize: 11.5'),
      );
    });

    test('uses 0px topbar gap and 0.1px lateral content limit', () {
      final state = classBlock(tools, '_PediatricsTabContentState');

      expect(state, contains('const SizedBox(height: 0)'));
      expect(
        state,
        contains(
          'padding: const EdgeInsets.fromLTRB(0.1, 0.1, 0.1, 100)',
        ),
      );
    });

    test('uses 1px vertical spacing between pediatric cards', () {
      expect(
        classBlock(tools, '_PedSectionGap'),
        contains('SizedBox(height: 1)'),
      );
    });

    test('preserves card colors and shape', () {
      final card = classBlock(tools, '_PedFlatSection');

      expect(
        card,
        contains(
          'c.dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF)',
        ),
      );
      expect(
        card,
        contains(
          'c.dark ? const Color(0xFF374151) : const Color(0xFFD8DEE7)',
        ),
      );
      expect(card, contains('BorderRadius.circular(8)'));
      expect(card, contains('padding: const EdgeInsets.fromLTRB(13, 10, 13, 10)'));
      expect(card, isNot(contains('BoxShadow')));
    });

    test('preserves 44px canonical subnav geometry', () {
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
      expect(nav, contains('width: active ? 2 : 0.7'));
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
