import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String className) {
  final token = 'class $className';
  final start = source.indexOf(token);
  expect(start, greaterThanOrEqualTo(0), reason: className);
  final next = source.indexOf('\nclass ', start + token.length);
  return next < 0 ? source.substring(start) : source.substring(start, next);
}

void main() {
  final tools = File('lib/screens/tools_screen.dart').readAsStringSync();

  group('Pediatria internal margin +4 V1-B-R2', () {
    test('keeps approved outer geometry', () {
      final state = classBlock(tools, '_PediatricsTabContentState');
      final gap = classBlock(tools, '_PedSectionGap');
      final card = classBlock(tools, '_PedFlatSection');

      expect(
        RegExp(
          r'padding:\s*const EdgeInsets\.fromLTRB\(\s*0\.5\s*,\s*0\.1\s*,\s*0\.5\s*,\s*100\s*\)',
        ).hasMatch(state),
        isTrue,
      );
      expect(gap, contains('SizedBox(height: 3)'));
      expect(card, isNot(contains('border: Border.all(')));
    });

    test('adds exactly 4px internal margin on each lateral side', () {
      final card = classBlock(tools, '_PedFlatSection');

      expect(
        card,
        contains('padding: const EdgeInsets.fromLTRB(17, 10, 17, 10)'),
      );
      expect(
        card,
        isNot(contains('padding: const EdgeInsets.fromLTRB(13, 10, 13, 10)')),
      );
    });

    test('keeps card height rhythm and title divider', () {
      final card = classBlock(tools, '_PedFlatSection');

      expect(card, contains('borderRadius: BorderRadius.circular(8)'));
      expect(card, contains('Container(height: 0.7, color: c.border)'));
    });

    test('keeps pediatric input owner and callbacks intact', () {
      final input = classBlock(tools, '_PedCompactInput');

      expect(input, contains('TextField('));
      expect(input, contains('controller: ctrl'));
      expect(input, contains('onChanged: onChanged'));
      expect(input, contains('contentPadding:'));
    });

    test('keeps clinical engines wired', () {
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
