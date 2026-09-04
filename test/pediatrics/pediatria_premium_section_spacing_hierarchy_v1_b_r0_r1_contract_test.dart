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

  group('Pediatria premium final hierarchy V1-B-R0-R1', () {
    test('uses one pixel between cards without moving their outer edges', () {
      expect(
        classBlock(tools, '_PedSectionGap'),
        contains('SizedBox(height: 1)'),
      );

      final state = classBlock(tools, '_PediatricsTabContentState');
      expect(
        state,
        contains(
          'padding: const EdgeInsets.fromLTRB(0.1, 0.1, 0.1, 100)',
        ),
      );
      expect(state, contains('const SizedBox(height: 0)'));
    });

    test('recedes all section-card content three more horizontal pixels', () {
      final section = classBlock(tools, '_PedFlatSection');

      expect(
        section,
        contains('padding: const EdgeInsets.fromLTRB(13, 10, 13, 10)'),
      );
      expect(
        section,
        contains(
          'c.dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF)',
        ),
      );
      expect(section, contains('BorderRadius.circular(8)'));
      expect(section, isNot(contains('BoxShadow')));
    });

    test('uses explicit premium typography hierarchy', () {
      final scale = classBlock(tools, '_PediatricsVisualScaleR3');

      for (final token in <String>[
        'static const double sectionTitle = 14.0',
        'static const double sectionLabel = 13.0',
        'static const double subsectionTitle = 12.5',
        'static const double body = 14.5',
        'static const double micro = 11.5',
        'static const double inputText = 15.5',
        'static const double option = 14.5',
        'static const double result = 15.5',
      ]) {
        expect(scale, contains(token), reason: token);
      }

      expect(
        classBlock(tools, '_PedFlatSection'),
        contains('fontSize: _PediatricsVisualScaleR3.sectionTitle'),
      );
    });

    test('gives PEWS subgroup titles a separate hierarchy role', () {
      final pews = classBlock(tools, '_PedPewsSelectorFlat');

      expect(
        RegExp(
          r'fontSize:\s*_PediatricsVisualScaleR3\.subsectionTitle',
        ).allMatches(pews).length,
        1,
      );
      expect(pews, contains('fontWeight: FontWeight.w800'));
      expect(pews, contains('color: c.textSecondary'));
    });

    test('keeps clinical results visually above source notes', () {
      final scale = classBlock(tools, '_PediatricsVisualScaleR3');

      expect(scale, contains('static const double result = 15.5'));
      expect(scale, contains('static const double micro = 11.5'));

      final source = classBlock(tools, '_PedSourceNoteState');
      expect(source, contains('_PediatricsVisualScaleR3.micro'));
    });

    test('preserves canonical subnav and clinical engines', () {
      final nav = classBlock(tools, '_PediatTabRow');
      expect(nav, contains('height: 44'));
      expect(nav, contains('right: i < sections.length - 1'));
      expect(nav, contains('width: active ? 2 : 0.7'));

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
