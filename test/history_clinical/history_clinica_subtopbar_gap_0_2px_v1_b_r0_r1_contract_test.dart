import 'history_release_runtime_harness.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String history;

  setUpAll(() {
    history = File('lib/screens/history_screen.dart').readAsStringSync();
  });

  group('Historia Clinica subtopbar 0.2px safety gap V1-B-R0-R1', () {
    testWidgets('48px reserve meets the current 40px strip without the retired gap', (tester) async {
      expect(history, contains('MEDCASES_HISTORIA_CLINICA_SUBTOPBAR_GAP_0_2PX_V1_B_R0_R1'));
      final reserve = history.indexOf('const SizedBox(height: 48)');
      expect(reserve, greaterThanOrEqualTo(0));
      final nav = history.indexOf('_HcTabRow(', reserve);
      expect(nav, greaterThan(reserve));
      await verifyHistoryNavigation(tester);
    });

    testWidgets('current equal segments retain selection, divider and navigation', (tester) async {
      await verifyHistoryNavigation(tester, dark: true);
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
