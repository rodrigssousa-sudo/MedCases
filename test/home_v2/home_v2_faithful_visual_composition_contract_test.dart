import 'home_composition_runtime_harness.dart';
import 'package:flutter/material.dart';
import 'package:medcases/home_v2/components/home_v2_modules_view.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const homePath = 'lib/home_v2/home_screen_v2.dart';
  const modulesPath = 'lib/home_v2/components/home_v2_modules_view.dart';
  const chatPath = 'lib/home_v2/components/chat/inline_chat_view.dart';
  const commonPath = 'lib/home_v2/components/common/home_v2_press_surface.dart';
  const canonicalHomePath = 'lib/screens/home_screen.dart';

  late String home;
  late String modules;
  late String chat;
  late String common;
  late String canonicalHome;

  setUpAll(() {
    home = File(homePath).readAsStringSync();
    modules = File(modulesPath).readAsStringSync();
    chat = File(chatPath).readAsStringSync();
    common = File(commonPath).readAsStringSync();
    canonicalHome = File(canonicalHomePath).readAsStringSync();
  });

  String classBlock(
    String source,
    String className,
  ) {
    final marker = 'class $className ';
    final start = source.indexOf(marker);

    expect(
      start,
      greaterThanOrEqualTo(0),
      reason: 'Classe ausente: $className',
    );

    final nextClass = source.indexOf(
      '\nclass ',
      start + marker.length,
    );

    return nextClass < 0
        ? source.substring(start)
        : source.substring(start, nextClass);
  }

  group('Home V2 edge-to-edge', () {
    test('não possui margens horizontais', () {
      expect(
        home,
        contains('const horizontalPadding = 0.0;'),
      );

      expect(
        home,
        isNot(
          contains(
            'viewportWidth >= 600 ? 20.0 : 12.0',
          ),
        ),
      );
    });

    test('usa fundo cinza grafite', () {
      expect(
        home,
        contains(
          'HomeV2SurfaceTokens.pageBackground(dark)',
        ),
      );

      expect(
        common,
        contains('Color(0xFF1A1D23)'),
      );
    });
  });

  group('Espaçamentos oficiais', () {
    test('IA para Fármacos usa 5 px', () {
      final shell = classBlock(
        home,
        '_HomeV2VisualShell',
      );

      expect(
        shell
                .split(
                  'const SizedBox(height: 5)',
                )
                .length -
            1,
        1,
      );
    });

    testWidgets(
        'cluster clínico e utilidades mantêm o divisor produtivo de 0,55 px',
        (tester) async {
      await verifyHomeComposition(tester, verifyMounted: () {
        final clinical = find.byType(HomeV2ClinicalGrid).first;
        final utility = find.byType(HomeV2UtilityRow);
        expect(
            tester.getTopLeft(utility).dy - tester.getBottomLeft(clinical).dy,
            closeTo(0.55, 0.001));
      });
    });

    test('utilidades para Mi Guardia usa 5 px', () {
      final utility = classBlock(
        home,
        '_HomeV2UtilityCluster',
      );

      expect(
        utility,
        contains('const SizedBox(height: 5)'),
      );
    });
  });

  group('Superfície compartilhada', () {
    test('IA e módulos usam o mesmo componente', () {
      expect(
        modules,
        contains('HomeV2PressSurface('),
      );

      expect(
        chat,
        contains('return HomeV2PressSurface('),
      );

      expect(
        modules,
        isNot(contains('_HomeV2Surface')),
      );
    });

    test('raio é minimalista e unificado', () {
      expect(
        common,
        contains('static const double radius = 6'),
      );
    });

    test('borda normal é quase invisível', () {
      expect(
        common,
        contains(
          'static const int idleBorderAlpha = 20',
        ),
      );

      expect(
        common,
        contains(
          'widget.palette.border.withAlpha(',
        ),
      );
    });

    test('borda ganha destaque durante o toque', () {
      expect(
        common,
        contains('? widget.palette.border'),
      );

      expect(common, contains('onPointerDown:'));
      expect(common, contains('onPointerUp:'));
      expect(common, contains('onPointerCancel:'));
    });
  });

  group('Cluster clínico', () {
    testWidgets(
        'Fármacos e grades compartilham o owner produtivo sem perder módulos',
        (tester) async {
      await verifyHomeComposition(tester, verifyMounted: () {
        expect(find.byType(HomeV2PrimaryClinicalCard), findsOneWidget);
        expect(find.byType(HomeV2ClinicalGrid), findsNWidgets(2));
        final primary = find.byType(HomeV2PrimaryClinicalCard);
        final clinical = find.byType(HomeV2ClinicalGrid).first;
        expect(tester.getBottomLeft(primary).dy,
            closeTo(tester.getTopLeft(clinical).dy, 0.001));
        expect(
            tester
                .widgetList<HomeV2ClinicalGrid>(find.byType(HomeV2ClinicalGrid))
                .map((g) => g.section),
            [
              HomeV2ClinicalGridSection.toolsHistory,
              HomeV2ClinicalGridSection.patientPediatrics
            ]);
      });
    });

    testWidgets('surface atual preserva filhos e espaçamento interno',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: HomeV2ClinicalSurface(
                  dark: false,
                  primary: const SizedBox(key: ValueKey('primary'), height: 10),
                  grid: const SizedBox(key: ValueKey('grid'), height: 10)))));
      expect(
          tester.getTopLeft(find.byKey(const ValueKey('grid'))).dy -
              tester.getBottomLeft(find.byKey(const ValueKey('primary'))).dy,
          3);
      expect(tester.takeException(), isNull);
    });
  });

  group('Proprietários preservados', () {
    test('timer continua na Home canônica', () {
      expect(
        canonicalHome,
        contains(
          'class _HistorialCompactCardState',
        ),
      );

      expect(
        canonicalHome,
        contains(
          'GlobalKey<_HistorialCompactCardState>',
        ),
      );
    });

    test('camada visual não recebe motores', () {
      const forbidden = <String>[
        'FirebaseFirestore',
        'SharedPreferences',
        'NotificationService',
        'Timer.periodic',
        'WebViewController',
        'AiEngineService',
      ];

      for (final token in forbidden) {
        expect(home, isNot(contains(token)));
        expect(modules, isNot(contains(token)));
        expect(common, isNot(contains(token)));
      }
    });
  });
}
