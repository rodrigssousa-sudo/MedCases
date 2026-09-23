import '../architecture/architectural_runtime_harness.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final start = source.indexOf('class $className');
  expect(start, greaterThanOrEqualTo(0), reason: className);

  final next = source.indexOf('\nclass ', start + 7);
  return next < 0 ? source.substring(start) : source.substring(start, next);
}

void main() {
  testWidgets('current rendered geometry and navigation contract',
      (tester) async {
    for (final dark in [false, true]) {
      await verifyPediatricGeometry(tester, dark: dark);
    }
    await verifyPediatricShell(tester);
  });
  final tools = File('lib/screens/tools_screen.dart').readAsStringSync();

  group('Pediatria final scrollable subnav and white titles V1-B-R0-R5', () {
    test('keeps one canonical 14px tab label scale', () {
      final scale = classBlock(tools, '_PediatricsVisualScaleR3');

      expect(scale, contains('static const double tabLabel = 12.0;'));
    });

    test('subnav scrolls horizontally instead of scaling labels down', () {
      final nav = classBlock(tools, '_PediatTabRow');

      expect(nav, contains('height: 40'));
      expect(nav, contains('SingleChildScrollView('));
      expect(nav, contains('scrollDirection: Axis.horizontal'));
      expect(
        nav,
        contains('padding: EdgeInsets.zero'),
      );
      expect(nav, contains('constraints: const BoxConstraints(minWidth: 112)'));
      expect(
        nav,
        contains('padding: const EdgeInsets.symmetric(horizontal: 12)'),
      );
      expect(nav, contains('fontSize: _PediatricsVisualScaleR3.tabLabel'));

      expect(nav, isNot(contains('FittedBox(')));
      expect(nav, isNot(contains('BoxFit.scaleDown')));
      expect(nav, isNot(contains('return Expanded(')));
    });

    test('preserves separators active underline and tap behavior', () {
      final nav = classBlock(tools, '_PediatTabRow');

      expect(nav, contains('onTap: () => onSelect(i)'));
      expect(nav, contains('if (i < sections.length - 1)'));
      expect(nav,
          contains('child: Container(width: 0.7, height: 20, color: divider)'));
      expect(nav, contains('FontWeight.w700'));
      expect(nav, contains('height: 2'));
      expect(nav, contains('Color(0xFF0D6B57)'));
    });

    test('all dark tab titles use primary white', () {
      final nav = classBlock(tools, '_PediatTabRow');
      final normalized = nav.replaceAll(RegExp(r'\s+'), ' ');

      expect(
        normalized,
        contains(
          'final activeColor = dark ? const Color(0xFF0D6B57) : const Color(0xFF0D6B57);',
        ),
      );
      expect(
        normalized,
        contains(
          'final inactiveColor = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);',
        ),
      );
    });

    test('field titles are primary while hints remain delicate', () {
      final input = classBlock(tools, '_PedCompactInput');

      expect(
        'color: c.textPrimary,'.allMatches(input).length,
        greaterThanOrEqualTo(2),
      );
      expect(input, isNot(contains('color: c.textSecondary,')));

      expect(input, contains('fontSize: _PediatricsVisualScaleR3.hint'));
      expect(input, contains('fontWeight: FontWeight.w400'));
      expect(input, contains('color: c.textHint'));
      expect(input, contains('height: 40'));
    });

    test('main titles stay primary and secondary clinical copy stays gray', () {
      final section = classBlock(tools, '_PedFlatSection');
      final metric = classBlock(tools, '_PedMetricRow');
      final referenceState = classBlock(tools, '_PedSourceNoteState');
      final vital = classBlock(tools, '_PedVitalRow');

      expect(section, contains('color: c.textPrimary'));
      expect(metric, contains('color: c.textSecondary'));
      expect(referenceState, contains('color: c.textSecondary'));
      expect(vital, contains('color: c.textSecondary'));
    });

    test('preserves four localized pediatric routes and engines', () {
      for (final token in <String>[
        "const ['BIOMETRÍA', 'CRECIMIENTO', 'FUNCIÓN RENAL', 'PEWS']",
        "const ['BIOMETRIA', 'CRESCIMENTO', 'FUNÇÃO RENAL', 'PEWS']",
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
