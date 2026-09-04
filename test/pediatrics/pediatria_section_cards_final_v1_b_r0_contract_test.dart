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

  group('Pediatria section cards final V1-B-R0', () {
    test('wraps every pediatric clinical section in canonical card surface',
        () {
      final section = classBlock(tools, '_PedFlatSection');

      expect(section, contains('width: double.infinity'));
      expect(section, contains('padding: const EdgeInsets.fromLTRB(13, 10, 13, 10)'));
      expect(
        section,
        contains(
          'c.dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF)',
        ),
      );
      expect(
        section,
        contains(
          'c.dark ? const Color(0xFF374151) : const Color(0xFFD8DEE7)',
        ),
      );
      expect(section, contains('width: 0.7'));
      expect(section, contains('BorderRadius.circular(8)'));

      expect(section, isNot(contains('BoxShadow')));
      expect(section, isNot(contains('boxShadow:')));
    });

    test('keeps one structural divider inside each section card', () {
      final section = classBlock(tools, '_PedFlatSection');

      expect(
        section,
        contains('Container(height: 0.7, color: c.border)'),
      );
    });

    test('preserves page, nav and final 5px geometry', () {
      final state = classBlock(tools, '_PediatricsTabContentState');
      final nav = classBlock(tools, '_PediatTabRow');

      expect(
        state,
        contains(
          'p.darkMode ? const Color(0xFF1A1D23) : const Color(0xFFE7ECEF)',
        ),
      );
      expect(state, contains('const SizedBox(height: 0)'));

      expect(
        nav,
        contains(
          'dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF)',
        ),
      );
      expect(nav, contains('height: 40'));
      expect(nav, contains('bottom: 9'));
    });

    test('keeps repeated row separators removed', () {
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

        expect(
          normalized,
          isNot(contains('Border(bottom:')),
          reason: name,
        );
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
