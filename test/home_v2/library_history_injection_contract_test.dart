import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;
  late String legacySource;

  setUpAll(() {
    source = File('lib/home_v2/home_screen_v2.dart').readAsStringSync();
    legacySource = File('lib/screens/home_screen.dart').readAsStringSync();
  });

  group('Injeção Biblioteca e História Clínica na Home V2', () {
    test('HomeScreen preserva slot opcional canônico', () {
      expect(
        legacySource,
        contains('final Widget? libraryHistoryRow;'),
      );
      expect(
        legacySource,
        contains('this.libraryHistoryRow,'),
      );
      expect(
        legacySource,
        contains('widget.libraryHistoryRow ??'),
      );
    });

    test('monta exatamente uma fachada canônica na Home V2', () {
      expect(
        RegExp(
          r'\bHomeLibraryHistoryRow\s*\(',
        ).allMatches(source).length,
        1,
      );
      expect(source, isNot(contains('libraryHistoryRow:')));
    });

    test('preserva callback real do MainShell', () {
      final start = source.indexOf(
        'HomeLibraryHistoryRow(',
      );

      expect(start, greaterThanOrEqualTo(0));

      final fragment = source.substring(
        start,
        (start + 250).clamp(0, source.length),
      );

      expect(fragment, contains('dark: dark'));
      expect(fragment, contains('isEs: isEs'));
      expect(fragment, contains('onTabChange: onTabChange'));
    });
  });
}
