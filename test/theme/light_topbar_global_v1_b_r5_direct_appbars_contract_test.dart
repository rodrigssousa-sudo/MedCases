import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Light Topbar Global V1-B-R5', () {
    const marker = 'MEDCASES_LIGHT_TOPBAR_GLOBAL_V1_B_R5';

    const files = <String>[
      'lib/screens/admin_screen.dart',
      'lib/screens/fontes_screen.dart',
    ];

    test('both direct AppBar owners are patched exactly once', () {
      for (final path in files) {
        final source = File(path).readAsStringSync();
        expect(
          marker.allMatches(source).length,
          1,
          reason: path,
        );
      }
    });

    test('light branch uses the canonical Home topbar contract', () {
      for (final path in files) {
        final source = File(path).readAsStringSync();

        for (final token in const <String>[
          'Theme.of(context).brightness == Brightness.dark',
          'const Color(0xFFECF1F3)',
          'const Color(0xFF05070A)',
          'Colors.transparent',
          'FontWeight.w700',
          '? null : true',
        ]) {
          expect(source, contains(token), reason: '$path | $token');
        }
      }
    });

    test('PreferredSize owners remain untouched in this phase', () {
      const protected = <String>[
        'lib/screens/calculadora_screen.dart',
        'lib/screens/internacion/internacion_screen.dart',
        'lib/widgets/medcases_webview_screen.dart',
      ];

      for (final path in protected) {
        final source = File(path).readAsStringSync();
        expect(
          source,
          isNot(contains(marker)),
          reason: path,
        );
      }
    });

    test('global light theme layer remains present', () {
      final mainSource = File('lib/main.dart').readAsStringSync();

      expect(
        mainSource,
        contains('MEDCASES_LIGHT_TOPBAR_GLOBAL_V1_B_R2'),
      );
      expect(
        mainSource,
        contains(
          'backgroundColor: const Color(0xFFECF1F3)',
        ),
      );
    });
  });
}
