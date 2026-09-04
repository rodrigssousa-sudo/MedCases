import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'bottom nav IA uses 31.5 logical slot while preserving 54x54 visual asset',
    () {
      final source = File('lib/main.dart').readAsStringSync();

      const expected = '''
                      width: 54,
                      height: 31.5,
                      child: OverflowBox(
                        alignment: Alignment.bottomCenter,
                        minWidth: 54,
                        maxWidth: 54,
                        minHeight: 54,
                        maxHeight: 54,
''';

      const stale = '''
                      width: 54,
                      height: 32.5,
                      child: OverflowBox(
                        alignment: Alignment.bottomCenter,
                        minWidth: 54,
                        maxWidth: 54,
                        minHeight: 54,
                        maxHeight: 54,
''';

      expect(source, contains(expected));
      expect(source, isNot(contains(stale)));
      expect(source, contains("'assets/icons/home_v2/ic_ia.svg'"));
      expect(
        source,
        contains('''
                          width: 54,
                          height: 54,
                          fit: BoxFit.contain,
'''),
      );
    },
  );
}
