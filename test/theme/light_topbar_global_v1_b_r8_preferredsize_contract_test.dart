import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Light Topbar Global V1-B-R8', () {
    const marker = 'MEDCASES_LIGHT_TOPBAR_GLOBAL_V1_B_R8';

    const files = <String>[
      'lib/screens/calculadora_screen.dart',
      'lib/screens/internacion/internacion_screen.dart',
      'lib/widgets/medcases_webview_screen.dart',
    ];

    test('all PreferredSize owners are patched once', () {
      for (final path in files) {
        final source = File(path).readAsStringSync();
        expect(
          marker.allMatches(source).length,
          1,
          reason: path,
        );
      }
    });

    test('light branch uses canonical colors', () {
      for (final path in files) {
        final source = File(path).readAsStringSync();

        for (final token in const <String>[
          'Theme.of(context).brightness == Brightness.dark',
          'Color(0xFFECF1F3)',
          'Color(0xFF05070A)',
        ]) {
          expect(source, contains(token), reason: '$path | $token');
        }
      }
    });

    test('existing title and back contracts remain present', () {
      final calculadora = File(
        'lib/screens/calculadora_screen.dart',
      ).readAsStringSync();
      final internacao = File(
        'lib/screens/internacion/internacion_screen.dart',
      ).readAsStringSync();
      final webView = File(
        'lib/widgets/medcases_webview_screen.dart',
      ).readAsStringSync();

      expect(calculadora, contains('CALCULADORA CLÍNICA'));
      expect(calculadora, contains('Icons.arrow_back'));
      expect(internacao, contains("'PACIENTES'"));
      expect(internacao, contains('Icons.arrow_back'));
      expect(webView, contains('widget.title'));
    });

    test('central alignment remains present', () {
      for (final path in files) {
        final source = File(path).readAsStringSync();
        expect(
          source,
          contains('Alignment.center'),
          reason: path,
        );
      }
    });

    test('prior global and direct AppBar phases remain present', () {
      expect(
        File('lib/main.dart').readAsStringSync(),
        contains('MEDCASES_LIGHT_TOPBAR_GLOBAL_V1_B_R2'),
      );
      expect(
        File('lib/screens/admin_screen.dart').readAsStringSync(),
        contains('MEDCASES_LIGHT_TOPBAR_GLOBAL_V1_B_R5'),
      );
      expect(
        File('lib/screens/fontes_screen.dart').readAsStringSync(),
        contains('MEDCASES_LIGHT_TOPBAR_GLOBAL_V1_B_R5'),
      );
    });
  });
}
