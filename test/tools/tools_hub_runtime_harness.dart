import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:medcases/providers/app_provider.dart';
import 'package:medcases/providers/tools_state_provider.dart';
import 'package:medcases/screens/tools_screen.dart';
import 'package:medcases/screens/nephro_premium_workspace_screen.dart';
import 'package:medcases/screens/cardio_premium_workspace_screen.dart';
import 'package:medcases/screens/electrolytes_premium_workspace_screen.dart';
import 'package:medcases/screens/hepato_premium_workspace_screen.dart';
import '../guides/guide_runtime_fixture.dart';

class ToolsThemeProvider extends GuideAppProvider {
  ToolsThemeProvider(super.language, this.dark);
  final bool dark;
  @override
  bool get darkMode => dark;
}

Future<void> verifyToolsHub(WidgetTester tester,
    {bool dark = false, bool isEs = false}) async {
  final io = await GuideHarness.open(tester);
  final p = ToolsThemeProvider(isEs ? 'es' : 'pt', dark);
  final tools = ToolsStateProvider();
  final root = GlobalKey<NavigatorState>();
  try {
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: p),
          ChangeNotifierProvider.value(value: tools)
        ],
        child: MaterialApp(
            navigatorKey: root, home: const Scaffold(body: ToolsScreen()))));
    await tester.pumpAndSettle();
    for (final entry in <String, Type>{
      isEs ? 'Nefrología' : 'Nefrologia': NephroPremiumWorkspaceScreen,
      isEs ? 'Cardiología' : 'Cardiologia': CardioPremiumWorkspaceScreen,
      isEs ? 'Electrolitos' : 'Eletrólitos': ElectrolytesPremiumWorkspaceScreen,
      isEs ? 'Hepatología' : 'Hepatologia': HepatoPremiumWorkspaceScreen
    }.entries) {
      final label = find.text(entry.key);
      final scroll = find.byType(Scrollable).first;
      tester.state<ScrollableState>(scroll).position.jumpTo(0);
      await tester.pump();
      await tester.scrollUntilVisible(label, 200,
          scrollable: scroll, maxScrolls: 30);
      expect(label, findsOneWidget);
      final title = tester.widget<Text>(label);
      expect(title.style!.fontSize, 13);
      expect(title.style!.fontWeight, FontWeight.w800);
      expect(title.style!.color,
          dark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A));
      final row =
          find.ancestor(of: label, matching: find.byType(InkWell)).first;
      final icons = tester.widgetList<Icon>(
          find.descendant(of: row, matching: find.byType(Icon)));
      expect(icons, hasLength(2));
      for (final icon in icons) {
        expect(icon.color, const Color(0xFF009C3B));
      }
      expect(icons.first.size, 20);
      expect(icons.last.size, 18);
      expect(
          tester.widgetList<ColoredBox>(find.byType(ColoredBox)).any((w) =>
              w.color ==
              (dark ? const Color(0xFF1A1D23) : const Color(0xFFECF0F4))),
          isTrue);
      final badge = find.descendant(
          of: row,
          matching: find.byWidgetPredicate((w) =>
              w is Container &&
              w.constraints?.minWidth == 38 &&
              w.constraints?.maxWidth == 38));
      expect(badge, findsOneWidget);
      expect(tester.getSize(badge), const Size(38, 38));
      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(find.byType(entry.value), findsOneWidget);
      expect(root.currentState!.canPop(), isTrue);
      root.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ToolsScreen), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  } finally {
    await tester.pumpWidget(const SizedBox());
    p.dispose();
    tools.dispose();
    io.provider.dispose();
  }
}
