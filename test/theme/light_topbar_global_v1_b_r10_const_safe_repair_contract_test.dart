import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Light Topbar Global V1-B-R10', () {
    const r8Marker = 'MEDCASES_LIGHT_TOPBAR_GLOBAL_V1_B_R8';

    const files = <String>[
      'lib/screens/calculadora_screen.dart',
      'lib/screens/internacion/internacion_screen.dart',
      'lib/widgets/medcases_webview_screen.dart',
    ];

    test('R8 light-only patch remains present once per owner', () {
      for (final path in files) {
        final source = File(path).readAsStringSync();

        expect(
          r8Marker.allMatches(source).length,
          1,
          reason: path,
        );
        expect(
          source,
          contains(
            'Theme.of(context).brightness == Brightness.dark',
          ),
          reason: path,
        );
        expect(
          source,
          contains('Color(0xFFECF1F3)'),
          reason: path,
        );
        expect(
          source,
          contains('Color(0xFF05070A)'),
          reason: path,
        );
      }
    });

    test('known invalid const anchors were removed', () {
      final calculadora = File(
        'lib/screens/calculadora_screen.dart',
      ).readAsStringSync();
      final internacao = File(
        'lib/screens/internacion/internacion_screen.dart',
      ).readAsStringSync();
      final webView = File(
        'lib/widgets/medcases_webview_screen.dart',
      ).readAsStringSync();

      expect(
        calculadora,
        isNot(
          contains(
            'const Text(\n'
            "                    'CALCULADORA CLÍNICA'",
          ),
        ),
      );
      expect(
        internacao,
        isNot(
          contains(
            'const Text(\n'
            "                      'PACIENTES'",
          ),
        ),
      );
      expect(
        webView,
        contains('widget.title'),
      );
    });

    test('existing navigation contracts remain present', () {
      final calculadora = File(
        'lib/screens/calculadora_screen.dart',
      ).readAsStringSync();
      final internacao = File(
        'lib/screens/internacion/internacion_screen.dart',
      ).readAsStringSync();
      final webView = File(
        'lib/widgets/medcases_webview_screen.dart',
      ).readAsStringSync();

      expect(calculadora, contains('Icons.arrow_back'));
      expect(internacao, contains('Icons.arrow_back'));
      expect(
        webView,
        isNot(contains('MEDCASES_V1_B_R10_ADDED_BACK')),
      );
    });

    test('previous global and direct phases remain present', () {
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
