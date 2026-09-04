import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String history;

  setUpAll(() {
    history = File('lib/screens/history_screen.dart').readAsStringSync();
  });

  group('Historia Clinica subtopbar 0.2px safety gap V1-B-R0-R1', () {
    test('uses exact screen-specific 0.2px gap after the 48px topbar', () {
      expect(
        history,
        contains(
          'MEDCASES_HISTORIA_CLINICA_SUBTOPBAR_GAP_0_2PX_V1_B_R0_R1',
        ),
      );

      final reserve = history.indexOf('const SizedBox(height: 48)');
      final gap = history.indexOf('const SizedBox(height: 0.2)', reserve);
      final nav = history.indexOf('_HcTabRow(', gap);

      expect(reserve, greaterThanOrEqualTo(0));
      expect(gap, greaterThan(reserve));
      expect(nav, greaterThan(gap));
    });

    test('keeps the homologated segmented structure intact', () {
      for (final token in <String>[
        'MEDCASES_HISTORIA_CLINICA_SUBTOPBAR_STRUCTURAL_PARITY_AVALIACAO_V1_B_R0_R1',
        'const Color(0xFFEFF2F5)',
        'const Color(0xFF2D3340)',
        'height: 44',
        'padding: const EdgeInsets.symmetric(horizontal: 8)',
        'padding: const EdgeInsets.symmetric(horizontal: 12)',
        'right: BorderSide(',
        'width: isActive ? 2 : 0.7',
        'fontSize: 11',
        'height: 1',
      ]) {
        expect(history, contains(token), reason: token);
      }
    });

    test('does not alter the retained History card contract', () {
      for (final token in <String>[
        'MEDCASES_HISTORIA_CLINICA_CANONICAL_DENSITY_CARD_SURFACE_OVERFLOW_V1_B_R0_R1',
        'color: isDark ? const Color(0xFF252930) : const Color(0xFFFFFFFF)',
        'Responsive Wrap:',
      ]) {
        expect(history, contains(token), reason: token);
      }
    });
  });
}
