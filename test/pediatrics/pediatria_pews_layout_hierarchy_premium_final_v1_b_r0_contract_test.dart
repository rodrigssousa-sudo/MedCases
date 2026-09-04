import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final start = source.indexOf('class $className');
  expect(start, greaterThanOrEqualTo(0), reason: className);

  final next = source.indexOf('\nclass ', start + 7);
  return next < 0 ? source.substring(start) : source.substring(start, next);
}

String methodBlock(String source, String signature, String endMarker) {
  final start = source.indexOf(signature);
  expect(start, greaterThanOrEqualTo(0), reason: signature);

  final end = source.indexOf(endMarker, start);
  expect(end, greaterThan(start), reason: endMarker);

  return source.substring(start, end);
}

void main() {
  final tools = File('lib/screens/tools_screen.dart').readAsStringSync();

  group('Pediatria PEWS premium layout hierarchy V1-B-R0', () {
    test(
      'result summary uses fixed score column and expanded interpretation',
      () {
        final pews = methodBlock(
          tools,
          'Widget _buildPews(bool isEs, AppColors c)',
          '// SEÇÃO OCULTA — DOSES PEDIÁTRICAS',
        );

        expect(pews, contains('width: 54'));
        expect(pews, contains('width: 46'));
        expect(pews, contains("isEs ? 'RESULTADO ACTUAL' : 'RESULTADO ATUAL'"));
        expect(pews, contains('fontSize: 13.5'));
        expect(pews, contains('height: 1.28'));
        expect(pews, contains('Expanded('));
        expect(pews, contains('Container(height: 0.7, color: c.border)'));
      },
    );

    test('group headers act as landmarks without option dividers', () {
      final selector = classBlock(tools, '_PedPewsSelectorFlat');

      expect(selector, contains('width: 3'));
      expect(selector, contains('height: 14'));
      expect(
        selector,
        contains('fontSize: _PediatricsVisualScaleR3.subsectionTitle'),
      );
      expect(selector, contains('fontWeight: FontWeight.w800'));
      expect(selector, contains('color: c.textSecondary'));
      expect(selector, isNot(contains('Border(bottom')));
    });

    test(
      'option layout reserves leading column and supports multiline text',
      () {
        final selector = classBlock(tools, '_PedPewsSelectorFlat');

        expect(
          selector,
          contains('crossAxisAlignment: CrossAxisAlignment.start'),
        );
        expect(selector, contains('width: 32'));
        expect(selector, contains('width: 24'));
        expect(selector, contains('height: 24'));
        expect(
          selector,
          contains('EdgeInsets.symmetric(horizontal: 6, vertical: 6)'),
        );
        expect(selector, contains('Expanded('));
        expect(selector, contains('fontSize: 13.5'));
        expect(selector, contains('height: 1.28'));
      },
    );

    test('selected option hierarchy is stronger but remains flat', () {
      final selector = classBlock(tools, '_PedPewsSelectorFlat');

      expect(selector, contains('active ? FontWeight.w700 : FontWeight.w500'));
      expect(
        selector,
        contains("const Color(0xFF10B981).withValues(alpha: 0.055)"),
      );
      expect(selector, contains('borderRadius: BorderRadius.circular(8)'));
      expect(selector, isNot(contains('boxShadow')));
    });

    test('PEWS modifiers receive their own hierarchy landmark', () {
      final pews = methodBlock(
        tools,
        'Widget _buildPews(bool isEs, AppColors c)',
        '// SEÇÃO OCULTA — DOSES PEDIÁTRICAS',
      );

      expect(pews, contains("'MODIFICADORES +2'"));
      expect(pews, contains('_pewsQuarterHourlyNebulizer'));
      expect(pews, contains('_pewsPersistentPostOpVomiting'));
    });

    test('clinical engines localization and zero-gap shell stay frozen', () {
      for (final token in <String>[
        'BrightonPewsEngineV2026.calculate(',
        'PediatricGrowthEngineV2026',
        'PediatricRenalEngineV2026',
        'PediatricReferenceRegistryV2026',
        "const ['BIOMETRÍA', 'CRECIMIENTO', 'FUNCIÓN RENAL', 'PEWS']",
        "const ['BIOMETRIA', 'CRESCIMENTO', 'FUNÇÃO RENAL', 'PEWS']",
        'const SizedBox(height: 0),',
        'padding: const EdgeInsets.fromLTRB(0.1, 0.1, 0.1, 100)',
      ]) {
        expect(tools, contains(token), reason: token);
      }
    });
  });
}
