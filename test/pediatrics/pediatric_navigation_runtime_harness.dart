import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:medcases/providers/app_provider.dart';
import 'package:medcases/screens/tools_screen.dart';
import '../guides/guide_runtime_fixture.dart';
import '../tools/tools_hub_runtime_harness.dart';

Future<void> verifyPediatricNavigation(WidgetTester tester,
    {bool dark = false, bool isEs = false}) async {
  final io = await GuideHarness.open(tester);
  final p = ToolsThemeProvider(isEs ? 'es' : 'pt', dark);
  try {
    await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
        value: p,
        child:
            const MaterialApp(home: Scaffold(body: PediatricsTabContent()))));
    await tester.pumpAndSettle();
    final labels = isEs
        ? ['BIOMETRÍA', 'CRECIMIENTO', 'FUNCIÓN RENAL', 'PEWS']
        : ['BIOMETRIA', 'CRESCIMENTO', 'FUNÇÃO RENAL', 'PEWS'];
    for (final label in labels) {
      final f = find.text(label);
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pumpAndSettle();
      for (final other in labels) {
        final t = tester.widget<Text>(find.text(other));
        expect(t.style!.fontSize, 12);
        expect(t.style!.fontWeight, FontWeight.w700);
        expect(
            t.style!.color,
            other == label
                ? const Color(0xFF0D6B57)
                : (dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)));
      }
      final tile =
          find.ancestor(of: f, matching: find.byType(AnimatedContainer)).first;
      expect(tester.getSize(tile).height, closeTo(39.3, 0.001));
      expect(tester.getSize(tile).width, greaterThanOrEqualTo(112));
    }
    // Exercise every existing option in each selector through the real callback;
    // labels come from the current approved UI, not newly invented clinical data.
    final selectors = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_PedPewsSelectorFlat');
    expect(selectors, findsNWidgets(3));
    for (var group = 0; group < 3; group++) {
      final initial = tester.widget(selectors.at(group)) as dynamic;
      final options = List<String>.from(initial.options as List);
      expect(options, hasLength(4));
      for (var i = 0; i < 4; i++) {
        final option = find.descendant(
            of: selectors.at(group), matching: find.text(options[i]));
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pumpAndSettle();
        final current = tester.widget(selectors.at(group)) as dynamic;
        expect(current.value, i);
        final text = tester.widget<Text>(option);
        expect(text.style!.fontWeight, FontWeight.w700);
        final tile = find
            .ancestor(of: option, matching: find.byType(AnimatedContainer))
            .first;
        final container = tester.widget<AnimatedContainer>(tile);
        expect((container.decoration as BoxDecoration).color,
            const Color(0xFF0D6B57).withValues(alpha: 0.055));
      }
    }
    expect(tester.takeException(), isNull);
  } finally {
    await tester.pumpWidget(const SizedBox());
    p.dispose();
    io.provider.dispose();
  }
}
