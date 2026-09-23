import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:medcases/providers/app_provider.dart';
import 'package:medcases/providers/tools_state_provider.dart';
import 'package:medcases/home_v2/home_screen_v2.dart';
import 'package:medcases/home_v2/components/home_v2_modules_view.dart';
import '../guides/guide_runtime_fixture.dart';
import 'home_release_runtime_harness.dart';

Future<void> verifyHomeComposition(WidgetTester tester,
    {void Function()? verifyMounted}) async {
  final io = await GuideHarness.open(tester);
  final p = HomeRuntimeProvider('pt', false);
  final tools = ToolsStateProvider();
  final calls = <String>[];
  try {
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: p),
          ChangeNotifierProvider.value(value: tools),
          ChangeNotifierProvider.value(value: p.uiProvider),
          ChangeNotifierProvider.value(value: p.aiChatProvider)
        ],
        child: MaterialApp(
            home: Scaffold(
                body: HomeScreenV2(
                    onTabChange: (i) => calls.add('tab:$i'),
                    onSubTabChange: (_) {},
                    openProtocol: (_) {},
                    onOpenNotes: () {},
                    onOpenClinicalGuide: () => calls.add('guide'),
                    onOpenSimulation: () => calls.add('simulation'),
                    onOpenVaccine: () => calls.add('vaccine'))))));
    await tester.pumpAndSettle();
    expect(find.byType(HomeV2ClinicalSurface), findsNothing);
    expect(find.byType(HomeV2PrimaryClinicalCard), findsOneWidget);
    final grids = tester
        .widgetList<HomeV2ClinicalGrid>(find.byType(HomeV2ClinicalGrid))
        .toList();
    expect(grids.map((g) => g.section), [
      HomeV2ClinicalGridSection.toolsHistory,
      HomeV2ClinicalGridSection.patientPediatrics
    ]);
    final primary = find.byType(HomeV2PrimaryClinicalCard);
    final clinical = find.byType(HomeV2ClinicalGrid).first;
    final utility = find.byType(HomeV2UtilityRow);
    final patient = find.byType(HomeV2ClinicalGrid).last;
    expect(tester.getTopLeft(utility).dy - tester.getBottomLeft(clinical).dy,
        closeTo(0.55, 0.001));
    expect(tester.getBottomLeft(primary).dy,
        closeTo(tester.getTopLeft(clinical).dy, 0.001));
    expect(tester.getTopLeft(patient).dy,
        greaterThan(tester.getTopLeft(utility).dy));
    expect(tester.getBottomLeft(patient).dy,
        lessThan(tester.getBottomLeft(utility).dy));
    final root = tester.widget<HomeScreenV2>(find.byType(HomeScreenV2));
    for (final element in [primary, clinical, utility, patient]) {
      expect(
          tester.element(element).findAncestorWidgetOfExactType<HomeScreenV2>(),
          same(root));
    }
    final bg = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .where((w) => w.color == const Color(0xFFE0E6E9));
    expect(bg, isNotEmpty);
    final dividers = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .where((w) => w.height == 0.55 && w.child is ColoredBox);
    expect(dividers, hasLength(2));
    await tester.ensureVisible(find.text('H. CLÍNICA'));
    await tester.tap(find.text('H. CLÍNICA'));
    await tester.pumpAndSettle();
    expect(calls, contains('tab:3'));
    verifyMounted?.call();
    expect(tester.takeException(), isNull);
  } finally {
    await tester.pumpWidget(const SizedBox());
    p.dispose();
    tools.dispose();
    io.provider.dispose();
  }
}
