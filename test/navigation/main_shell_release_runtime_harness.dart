import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:medcases/main.dart';
import 'package:medcases/providers/app_provider.dart';
import 'package:medcases/services/offline_calculator_cache_service.dart';
import 'package:medcases/providers/tools_state_provider.dart';
import '../guides/guide_runtime_fixture.dart';
import '../history_clinical/history_light_runtime_harness.dart';

Future<void> verifyMainShellRuntime(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final io = await GuideHarness.open(tester);
  final p = HistoryLightProvider();
  final tools = ToolsStateProvider();
  final root = GlobalKey<NavigatorState>();
  try {
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<AppProvider>.value(value: p),
      ChangeNotifierProvider.value(value: p.uiProvider),
      ChangeNotifierProvider.value(value: p.aiChatProvider),
      ChangeNotifierProvider.value(value: tools)
    ], child: MaterialApp(navigatorKey: root, home: const MainShell())));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    for (var i = 0; i < 3 && root.currentState!.canPop(); i++) {
      root.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.tap(find.text('Menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.widget<Text>(find.text('MEDCASES PREMIUM')).style!.color,
        const Color(0xFFFFE8A6));
    expect(find.text('SUPORTE'), findsOneWidget);
    expect(find.text('PREFERÊNCIAS'), findsOneWidget);
    expect(find.text('MODO OFFLINE'), findsOneWidget);
    expect(find.text('Excluir Conta'), findsOneWidget);
    expect(
        tester
            .widgetList<Icon>(find.byType(Icon))
            .where((icon) => icon.color == const Color(0xFF009C3B))
            .length,
        greaterThanOrEqualTo(5));
    root.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.text('CRIAR RESUMO'));
    await tester.tap(find.text('CRIAR RESUMO'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Área de Estudos'), findsOneWidget);
    for (final label in [
      'Notas',
      'Histórico',
      'Gravar aula',
      'Áudio',
      'PDF',
      'Imagem',
      'Texto',
      'Gerar material'
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Notas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Área de Estudos'), findsOneWidget);
    expect(find.text('Gerar material'), findsNothing);
    await tester.tap(find.text('Estudos').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Gerar material'), findsOneWidget);
    expect(find.byType(MainShell), findsOneWidget);
    expect(tester.takeException(), isNull);
  } finally {
    await tester.pumpWidget(const SizedBox());
    OfflineCalculatorCacheService.instance.dispose();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 8));
    }
    p.dispose();
    io.provider.dispose();
    tools.dispose();
  }
}
