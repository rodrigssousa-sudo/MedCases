import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Light Topbar Global V1-B-R16-R5-R13', () {
    const marker = 'MEDCASES_LIGHT_TOPBAR_GLOBAL_V1_B_R16_R5_R13';

    const files = <String>[
      'lib/screens/history_screen.dart',
      'lib/screens/library_screen.dart',
      'lib/screens/tools_screen.dart',
    ];

    test('custom topbars contain light-only branches', () {
      for (final path in files) {
        final source = File(path).readAsStringSync();

        expect(source, contains(marker), reason: path);
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
        expect(
          source,
          contains('Brightness.dark'),
          reason: path,
        );
      }
    });

    test('custom owners and theme bridges remain present', () {
      final history = File(
        'lib/screens/history_screen.dart',
      ).readAsStringSync();

      expect(
        history,
        contains('class _HcTopbarBg'),
      );
      expect(
        history,
        contains('final bool isDark;'),
      );
      expect(
        history,
        contains('isDark: Theme.of('),
      );
      expect(
        history,
        contains('late final'),
      );
      expect(
        history,
        contains(
          'return DecoratedBox(decoration: _kDecoration);',
        ),
      );
      expect(
        history,
        isNot(contains(
          'return const DecoratedBox('
          'decoration: _kDecoration);',
        )),
      );
      expect(
        history,
        isNot(contains('const _HcTopbarBg(')),
      );
      expect(
        history,
        isNot(contains('late static const')),
      );
      expect(
        history,
        isNot(contains('late const')),
      );
      expect(
        history,
        isNot(contains('static const late')),
      );
      expect(
        history,
        isNot(contains('static late const')),
      );
      expect(
        history,
        isNot(contains('const late final')),
      );
      expect(
        history,
        contains('late final'),
      );
      final library = File(
        'lib/screens/library_screen.dart',
      ).readAsStringSync();

      expect(
        library,
        contains('class _LibraryTopbarBg'),
      );
      expect(
        library,
        contains(
          'return DecoratedBox(decoration: _kDecoration);',
        ),
      );
      expect(
        library,
        isNot(contains(
          'return const DecoratedBox('
          'decoration: _kDecoration);',
        )),
      );
      expect(
        File('lib/screens/tools_screen.dart').readAsStringSync(),
        contains('class _ToolsTopbarBg'),
      );
    });

    test('history false title semantics remain present', () {
      final source = File(
        'lib/screens/history_screen.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('_dateFilterLabel'),
      );
      expect(
        source,
        anyOf(
          contains('MOTIVO DE CONSULTA'),
          contains('MOTIVO DA CONSULTA'),
        ),
      );
    });

    test('previous topbar phases remain present', () {
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
      expect(
        File('lib/screens/calculadora_screen.dart').readAsStringSync(),
        contains('MEDCASES_LIGHT_TOPBAR_GLOBAL_V1_B_R8'),
      );
      expect(
        File(
          'lib/screens/internacion/internacion_screen.dart',
        ).readAsStringSync(),
        contains('MEDCASES_LIGHT_TOPBAR_GLOBAL_V1_B_R8'),
      );
      expect(
        File('lib/widgets/medcases_webview_screen.dart').readAsStringSync(),
        contains('MEDCASES_LIGHT_TOPBAR_GLOBAL_V1_B_R8'),
      );
    });
  });
}
