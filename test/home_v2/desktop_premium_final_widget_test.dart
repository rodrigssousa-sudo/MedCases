import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/screens/ai/widgets/wa_header.dart';
import '../../lib/widgets/medcases_topbar_glass.dart';
import '../../lib/screens/ai/widgets/mobile_ai_action_bar.dart';

void main() {
  for (final width in [1920.0, 1440.0, 1200.0, 1024.0]) {
    for (final dark in [false, true]) {
      for (final lang in ['pt', 'es']) {
        testWidgets('Clinical header $width dark=$dark $lang', (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var history = 0;
          var fresh = 0;
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light),
            home: Scaffold(
                endDrawer: const Drawer(),
                body: Align(
                  alignment: Alignment.topRight,
                  child: SizedBox(
                      width: (width - 74) * .6,
                      child: WaHeader(
                        lang: lang,
                        onSettings: () {},
                        onHistory: () => history++,
                        onNewChat: () => fresh++,
                        historyCount: 2,
                      )),
                )),
          ));
          expect(tester.takeException(), isNull);
          expect(tester.getSize(find.byType(WaHeader)).height, 48);
          expect(find.byType(MedcasesTopbarGlass), findsOneWidget);
          expect(find.text('MEDCASES CLINICAL', findRichText: true),
              findsOneWidget);
          await tester.tap(find.byIcon(Icons.history_rounded));
          await tester.tap(find.byIcon(Icons.add_rounded));
          expect(history, 1);
          expect(fresh, 1);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  for (final width in [768.0, 375.0]) {
    for (final dark in [false, true]) {
      for (final lang in ['pt', 'es']) {
        testWidgets('Mobile header $width dark=$dark $lang', (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: Align(
            alignment: Alignment.topCenter,
            child: MobileAiActionBar(dark: dark, lang: lang, historyCount: 0,
              hasMessages: false, hasRealAi: false, keyLoading: false,
              onHistory: () {}, onClear: () {}, onSettings: () {}),
          ))));
          expect(tester.takeException(), isNull);
          expect(find.text('MEDCASES CLINICAL', findRichText: true), findsOneWidget);
          expect(tester.getSize(find.byType(MobileAiActionBar)).height, 48);
        });
      }
    }
  }
  test('commercial split, routes and protected renderer remain at their owners',
      () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('flex: 40'));
    expect(main, contains('flex: 60'));
    expect(main, contains('showPersistentAiSplit = width >= 1024'));
    expect(main, contains('PrescripcionesScreen()'));
    expect(main, contains('DrugsScreen()'));
    final sidebar = main.substring(main.indexOf('class _DesktopSidebar '),
        main.indexOf('class _DesktopSidebarProfileButton'));
    expect(sidebar, isNot(contains("tooltip: 'Fármacos'")));
    expect(sidebar, isNot(contains("tooltip: 'Prescrições'")));
    expect(sidebar, contains("tooltip: 'MedCases Clinical'"));
    expect(sidebar, contains('width: 72'));
  });
}
