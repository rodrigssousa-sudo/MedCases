import '../architecture/architectural_runtime_harness.dart';
import 'pediatric_navigation_runtime_harness.dart';
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
    testWidgets("preserves scale and productive pediatric navigation",
        (tester) async {
      for (final dark in [false, true]) {
        await verifyPediatricGeometry(tester, dark: dark);
        for (final isEs in [false, true]) {
          await verifyPediatricNavigation(tester, dark: dark, isEs: isEs);
        }
      }
    });

    testWidgets("uses 0px topbar gap and 0.1px lateral content limit",
        (tester) async {
      for (final dark in [false, true]) {
        await verifyPediatricGeometry(tester, dark: dark);
        for (final isEs in [false, true]) {
          await verifyPediatricNavigation(tester, dark: dark, isEs: isEs);
        }
      }
    });

    testWidgets("uses 1px vertical spacing between pediatric cards",
        (tester) async {
      for (final dark in [false, true]) {
        await verifyPediatricGeometry(tester, dark: dark);
        for (final isEs in [false, true]) {
          await verifyPediatricNavigation(tester, dark: dark, isEs: isEs);
        }
      }
    });

    testWidgets("preserves card colors and shape", (tester) async {
      for (final dark in [false, true]) {
        await verifyPediatricGeometry(tester, dark: dark);
        for (final isEs in [false, true]) {
          await verifyPediatricNavigation(tester, dark: dark, isEs: isEs);
        }
      }
    });

    testWidgets("preserves 44px canonical subnav geometry", (tester) async {
      for (final dark in [false, true]) {
        await verifyPediatricGeometry(tester, dark: dark);
        for (final isEs in [false, true]) {
          await verifyPediatricNavigation(tester, dark: dark, isEs: isEs);
        }
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
