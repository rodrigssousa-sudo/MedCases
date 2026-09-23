import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:medcases/main.dart';
import 'package:medcases/providers/app_provider.dart';
import 'package:medcases/providers/tools_state_provider.dart';
import 'package:medcases/services/offline_calculator_cache_service.dart';
import '../guides/guide_runtime_fixture.dart';
import '../history_clinical/history_light_runtime_harness.dart';

class _ThemeProvider extends HistoryLightProvider {
  @override
  bool get darkMode => uiProvider.darkMode;
}

Widget providers(
        HistoryLightProvider p, ToolsStateProvider tools, Widget child) =>
    MultiProvider(providers: [
      ChangeNotifierProvider<AppProvider>.value(value: p),
      ChangeNotifierProvider.value(value: p.uiProvider),
      ChangeNotifierProvider.value(value: p.aiChatProvider),
      ChangeNotifierProvider.value(value: tools),
    ], child: child);
void setMode(HistoryLightProvider p, bool dark) {
  p.uiProvider
      .syncValues(lang: 'pt', darkMode: p.darkMode, hapticEnabled: false);
  if (p.darkMode != dark) p.toggleDarkMode();
}

Future<void> verifyRootTheme(WidgetTester tester) async {
  final io = await GuideHarness.open(tester);
  final p = _ThemeProvider();
  final tools = ToolsStateProvider();
  final boot = Completer<void>();
  final field = TextEditingController(text: 'CAMPO_TESTE');
  try {
    await tester.pumpWidget(
        providers(p, tools, MedCasesApp(firebaseInit: boot.future)));
    await tester.pump();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    unawaited(app.navigatorKey!.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(body: TextField(controller: field)))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    for (final dark in [false, true, false]) {
      setMode(p, dark);
      await tester.pump();
      final current = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(current.themeMode, dark ? ThemeMode.dark : ThemeMode.light);
      final theme = Theme.of(tester.element(find.byType(TextField)));
      expect(theme.brightness, dark ? Brightness.dark : Brightness.light);
      expect(theme.colorScheme.primary,
          dark ? const Color(0xFF0D6B57) : const Color(0xFF0F172A));
      expect(theme.colorScheme.secondary, const Color(0xFF0D6B57));
      expect(theme.colorScheme.surface,
          dark ? const Color(0xFF252930) : Colors.white);
      expect(theme.colorScheme.onSurface,
          dark ? Colors.white : const Color(0xFF0F172A));
      expect(theme.colorScheme.outline,
          dark ? const Color(0xFF374151) : const Color(0xFFCBD5E1));
      expect(theme.scaffoldBackgroundColor,
          dark ? const Color(0xFF1A1D23) : const Color(0xFFF4F7FA));
      expect(
          contrastRatio(theme.colorScheme.onSurface, theme.colorScheme.surface),
          greaterThan(7));
      expect(tester.widget<TextField>(find.byType(TextField)).controller,
          same(field));
      expect(field.text, 'CAMPO_TESTE');
    }
    expect(tester.takeException(), isNull);
  } finally {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 21));
    field.dispose();
    p.dispose();
    tools.dispose();
    io.provider.dispose();
  }
}

Future<void> verifyShellTheme(WidgetTester tester,
    {required bool desktop}) async {
  tester.view.physicalSize = Size(desktop ? 1280 : 390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final io = await GuideHarness.open(tester);
  final p = _ThemeProvider();
  final tools = ToolsStateProvider();
  final root = GlobalKey<NavigatorState>();
  try {
    for (final dark in [false, true]) {
      setMode(p, dark);
      await tester.pumpWidget(providers(
          p,
          tools,
          MaterialApp(
              navigatorKey: root,
              theme: dark ? ThemeData.dark() : ThemeData.light(),
              home: const MainShell())));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      for (var i = 0; i < 3 && root.currentState!.canPop(); i++) {
        root.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
      if (desktop) {
        Finder icon(String label) => find.descendant(
            of: find.byTooltip(label), matching: find.byType(Icon));
        await tester.tap(find.byTooltip('Início'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
            tester.widget<Icon>(icon('Início')).color, const Color(0xFF009C3B));
        expect(
            tester.widget<Icon>(icon('H. Clínica')).color,
            dark
                ? Colors.white.withValues(alpha: 0.88)
                : const Color(0xFF4B5563));
        final tile = find.descendant(
            of: find.byTooltip('Início'),
            matching: find.byType(AnimatedContainer));
        expect(tester.getSize(tile), const Size(44, 44));
        await tester.tap(find.byTooltip('H. Clínica'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.widget<Icon>(icon('H. Clínica')).color,
            const Color(0xFF009C3B));
        expect(
            tester.widget<Icon>(icon('Início')).color,
            dark
                ? Colors.white.withValues(alpha: 0.88)
                : const Color(0xFF4B5563));
        expect(find.text('MINHAS'), findsOneWidget);
      } else {
        final brand = tester
            .widgetList<RichText>(find.byType(RichText))
            .where((w) => w.text.toPlainText() == 'MEDCASES PRO')
            .single;
        final spans = (brand.text as TextSpan).children!.cast<TextSpan>();
        expect(spans.first.style!.color,
            dark ? Colors.white : const Color(0xFF05070A));
        expect(spans.last.style!.color, const Color(0xFF009C3B));
        for (final span in spans) {
          expect(span.style!.fontSize, 16);
          expect(span.style!.fontWeight, FontWeight.w900);
          expect(span.style!.letterSpacing, 1.2);
        }
        await tester.tap(find.text('Menu'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('SUPORTE'), findsOneWidget);
        expect(tester.widget<Text>(find.text('MEDCASES PREMIUM')).style!.color,
            const Color(0xFFFFE8A6));
        root.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(tester.takeException(), isNull);
    }
  } finally {
    await tester.pumpWidget(const SizedBox());
    OfflineCalculatorCacheService.instance.dispose();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 8));
    }
    p.dispose();
    tools.dispose();
    io.provider.dispose();
  }
}

Future<void> verifyProfileTheme(WidgetTester tester) async {
  final io = await GuideHarness.open(tester);
  final p = _ThemeProvider();
  try {
    for (final dark in [false, true]) {
      setMode(p, dark);
      await tester.pumpWidget(MaterialApp(
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          home: ProfileAccountScreen(p: p)));
      await tester.pumpAndSettle();
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .where((w) => ['Nome completo', 'Profissão', 'Instituição']
              .contains(w.decoration?.labelText))
          .toList();
      expect(fields, hasLength(3));
      for (final field in fields) {
        expect(field.cursorColor, const Color(0xFF10B981));
        expect(field.decoration!.fillColor,
            dark ? const Color(0xFF181D25) : Colors.white);
        expect(field.style!.color,
            dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A));
        expect(field.style!.fontSize, 12.5);
        expect(
            (field.decoration!.focusedBorder! as OutlineInputBorder).borderSide,
            const BorderSide(color: Color(0xFF10B981), width: 1));
        expect(
            (field.decoration!.enabledBorder! as OutlineInputBorder).borderSide,
            BorderSide(
                color:
                    (dark ? const Color(0xFF374151) : const Color(0xFFD8DEE7))
                        .withValues(alpha: 0.42),
                width: 0.55));
        expect(contrastRatio(field.style!.color!, field.decoration!.fillColor!),
            greaterThan(7));
      }
      final save = find.ancestor(
          of: find.text('Salvar dados'), matching: find.byType(FilledButton));
      final b = tester.widget<FilledButton>(save);
      expect(b.style!.backgroundColor!.resolve({}), const Color(0xFF0D6B57));
      expect(b.style!.backgroundColor!.resolve({WidgetState.disabled}),
          const Color(0xFF0D6B57).withValues(alpha: 0.45));
      expect(b.style!.foregroundColor!.resolve({}), Colors.white);
      expect(b.onPressed, isNotNull);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      expect(find.text('Informe um nome válido.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    }
    expect(tester.takeException(), isNull);
  } finally {
    await tester.pumpWidget(const SizedBox());
    p.dispose();
    io.provider.dispose();
  }
}
