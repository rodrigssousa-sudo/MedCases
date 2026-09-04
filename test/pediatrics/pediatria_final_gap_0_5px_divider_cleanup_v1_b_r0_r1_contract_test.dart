import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source() => File('lib/screens/tools_screen.dart').readAsStringSync();

String classBlock(String text, String name) {
  final start = text.indexOf('class $name');
  expect(start, greaterThanOrEqualTo(0));
  final next = text.indexOf('\nclass ', start + 7);
  return next < 0 ? text.substring(start) : text.substring(start, next);
}

void main() {
  final tools = source();

  group('Pediatria final polish V1-B-R0-R1', () {
    test('uses final 0px gap directly before subnav', () {
      final state = classBlock(tools, '_PediatricsTabContentState');
      final gap = state.indexOf('const SizedBox(height: 0)');
      final nav = state.indexOf('_PediatTabRow(', gap);
      expect(gap, greaterThanOrEqualTo(0));
      expect(nav, greaterThan(gap));
    });

    test('removes repeated row separators', () {
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

    test('retains section and subnav hierarchy lines', () {
      expect(
        classBlock(tools, '_PedFlatSection'),
        contains('Container(height: 0.7, color: c.border)'),
      );
      final nav = classBlock(tools, '_PediatTabRow');
      expect(nav, contains('if (i < sections.length - 1)'));
      expect(nav, contains('bottom: 9'));
    });

    test('retains clinical and keyboard contracts', () {
      for (final token in <String>[
        'PediatricGrowthEngineV2026',
        'PediatricRenalEngineV2026',
        'BrightonPewsEngineV2026',
        'PediatricReferenceRegistryV2026',
        'CKiD U25',
        'CKiD bedside 2009',
        'MEDCASES_PEDS_2026_KEYBOARD_DISMISS_V1_B_R6_R1',
        'ScrollViewKeyboardDismissBehavior.onDrag',
      ]) {
        expect(tools, contains(token), reason: token);
      }
    });
  });
}
