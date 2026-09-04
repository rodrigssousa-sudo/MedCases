import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final start = source.indexOf('class $className');
  expect(start, greaterThanOrEqualTo(0), reason: className);

  final next = source.indexOf('\nclass ', start + 7);
  return next < 0 ? source.substring(start) : source.substring(start, next);
}

String methodBlock(String source, String signature, String endSignature) {
  final start = source.indexOf(signature);
  expect(start, greaterThanOrEqualTo(0), reason: signature);

  final end = source.indexOf(endSignature, start + signature.length);
  expect(end, greaterThan(start), reason: endSignature);

  return source.substring(start, end);
}

void main() {
  final tools = File('lib/screens/tools_screen.dart').readAsStringSync();

  group('Pediatria 3 tabs premium medical layout V1-B-R0-R2', () {
    test('Biometria Growth and Renal opt into quiet section headers', () {
      final biometry = methodBlock(
        tools,
        'Widget _buildBiometria(bool isEs, AppColors c)',
        'Widget _buildGrowth(bool isEs, AppColors c)',
      );
      final growth = methodBlock(
        tools,
        'Widget _buildGrowth(bool isEs, AppColors c)',
        'Widget _buildRenal(bool isEs, AppColors c)',
      );
      final renal = methodBlock(
        tools,
        'Widget _buildRenal(bool isEs, AppColors c)',
        'Widget _buildPews(bool isEs, AppColors c)',
      );

      expect('quietHeader: true'.allMatches(biometry).length, 3);
      expect('quietHeader: true'.allMatches(growth).length, 2);
      expect('quietHeader: true'.allMatches(renal).length, 1);
    });

    test('PEWS retains default section header behavior', () {
      final pews = methodBlock(
        tools,
        'Widget _buildPews(bool isEs, AppColors c)',
        '// SEÇÃO OCULTA — DOSES PEDIÁTRICAS',
      );

      expect(pews, isNot(contains('quietHeader: true')));
    });

    test(
      'quiet headers remove forced uppercase and heavy weight only on opt-in',
      () {
        final section = classBlock(tools, '_PedFlatSection');

        expect(section, contains('final bool quietHeader'));
        expect(section, contains('this.quietHeader = false'));
        expect(section, contains('quietHeader ? title : title.toUpperCase()'));
        expect(
          section,
          contains('quietHeader ? FontWeight.w700 : FontWeight.w900'),
        );
        expect(section, contains('quietHeader ? 0.0 : 0.4'));
      },
    );

    test('input labels and text use calmer medical typography', () {
      final input = classBlock(tools, '_PedCompactInput');

      expect(input, contains('fontWeight: FontWeight.w600'));
      expect(input, contains('letterSpacing: 0.1'));
      expect(input, contains('fontWeight: FontWeight.w500'));
      expect(input, contains('fontWeight: FontWeight.w400'));
      expect(input, contains('height: 40'));
    });

    test('sex selector is one professional segmented control', () {
      final sex = classBlock(tools, '_PedSexSelector');

      expect(sex, contains('height: 38'));
      expect(sex, contains('clipBehavior: Clip.antiAlias'));
      expect(sex, contains('Container(width: 0.7, height: 38, color: border)'));
      expect(sex, contains('selected ? FontWeight.w700 : FontWeight.w500'));
      expect(sex, isNot(contains('const SizedBox(width: 6)')));
    });

    test(
      'growth indicator uses full-width segmented control instead of pills',
      () {
        final growth = classBlock(tools, '_PedGrowthIndicatorToggle');

        expect(growth, contains('height: 38'));
        expect(growth, contains('clipBehavior: Clip.antiAlias'));
        expect(growth, contains('options.length * 2 - 1'));
        expect(growth, contains('return Expanded('));
        expect(
          growth,
          contains('selected ? FontWeight.w700 : FontWeight.w500'),
        );
        expect(growth, isNot(contains('SingleChildScrollView')));
        expect(
          growth,
          isNot(contains('margin: const EdgeInsets.only(right: 6)')),
        );
      },
    );

    test('metric and vital results reduce heavy typography', () {
      final metric = classBlock(tools, '_PedMetricRow');
      final vital = classBlock(tools, '_PedVitalRow');

      expect(metric, contains('fontWeight: FontWeight.w500'));
      expect(metric, contains('FontWeight.w600 : FontWeight.w700'));
      expect(metric, isNot(contains('FontWeight.w800')));

      expect(vital, contains('fontWeight: FontWeight.w500'));
      expect(vital, contains('fontWeight: FontWeight.w700'));
      expect(vital, isNot(contains('fontWeight: FontWeight.w800')));
    });

    test('shell clinical engines and localization stay frozen', () {
      for (final token in <String>[
        'const SizedBox(height: 0),',
        'padding: const EdgeInsets.fromLTRB(0.1, 0.1, 0.1, 100)',
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
