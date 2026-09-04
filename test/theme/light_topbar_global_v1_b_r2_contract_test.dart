import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Light Topbar Global V1-B-R2', () {
    late String mainSource;

    setUpAll(() {
      mainSource = File('lib/main.dart').readAsStringSync();
    });

    test('light theme receives canonical Home topbar colors', () {
      for (final token in const <String>[
        'MEDCASES_LIGHT_TOPBAR_GLOBAL_V1_B_R2',
        'backgroundColor: const Color(0xFFECF1F3)',
        'foregroundColor: const Color(0xFF05070A)',
        'surfaceTintColor: Colors.transparent',
        'shadowColor: Colors.transparent',
        'scrolledUnderElevation: 0',
        'centerTitle: true',
        'color: Color(0xFF05070A)',
        'fontWeight: FontWeight.w700',
      ]) {
        expect(mainSource, contains(token), reason: token);
      }
    });

    test('light AppBarTheme is derived from the existing theme', () {
      expect(
        mainSource,
        contains('final baseTheme ='),
      );
      expect(
        mainSource,
        contains(
          'appBarTheme: baseTheme.appBarTheme.copyWith(',
        ),
      );
      expect(
        mainSource,
        contains(
          'titleTextStyle: '
          'baseTheme.textTheme.titleLarge?.copyWith(',
        ),
      );
    });

    test('Home custom topbar preserves PRO and renders IA green', () {
      for (final token in const <String>[
        "text: currentTab == _kAiTab ? 'IA' : 'PRO'",
        'color: currentTab == _kAiTab',
        '? const Color(0xFF00C781)',
        ': const Color(0xFF059669))',
        '? const Color(0xFFFFD700)',
      ]) {
        expect(mainSource, contains(token), reason: token);
      }
    });

    test('darkTheme remains a separate untouched property', () {
      expect(
        RegExp(r'\bdarkTheme\s*:').allMatches(mainSource).length,
        greaterThanOrEqualTo(1),
      );
      expect(
        mainSource,
        isNot(
          contains(
            'darkTheme: (() {'
            '\n          // '
            'MEDCASES_LIGHT_TOPBAR_GLOBAL_V1_B_R2',
          ),
        ),
      );
    });
  });
}
