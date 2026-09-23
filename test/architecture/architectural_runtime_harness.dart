import 'package:medcases/screens/nephro_score_detail_screen.dart';
import 'package:medcases/screens/cardio_score_detail_screen.dart';
import 'package:medcases/screens/hepato_score_detail_screen.dart';
import 'package:medcases/screens/electrolytes_score_detail_screen.dart';
import 'package:medcases/screens/history_screen.dart';
import 'package:medcases/models/clinical_history_model.dart';
import 'package:medcases/screens/home_screen.dart'
    show PediatricsMainShellWorkspace;
import '../history_clinical/history_release_runtime_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:medcases/services/study/study_first_use_notice_service.dart';
import 'package:medcases/main.dart' show MainShell;
import 'package:medcases/providers/app_provider.dart';
import 'package:medcases/providers/tools_state_provider.dart';
import 'package:medcases/screens/tools_screen.dart';
import 'package:medcases/screens/study_workspace_screen.dart';
import 'package:medcases/widgets/meu_plantao_dashboard.dart';
import '../guides/guide_runtime_fixture.dart';
import '../tools/tools_hub_runtime_harness.dart';

Future<void> verifyToolsShell(WidgetTester tester,
    {bool dark = false, bool embedded = false}) async {
  final io = await GuideHarness.open(tester);
  final p = ToolsThemeProvider('pt', dark);
  final tools = ToolsStateProvider();
  final nav = GlobalKey<NavigatorState>();
  tester.view.padding = FakeViewPadding(top: 24);
  tester.view.devicePixelRatio = 1;
  try {
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: p),
          ChangeNotifierProvider.value(value: tools)
        ],
        child: MaterialApp(
            navigatorKey: nav,
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: const Scaffold(body: Text('ORIGEM_TESTE')))));
    nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(body: ToolsScreen(hideHeader: embedded))));
    await tester.pumpAndSettle();
    expect(find.byType(ToolsScreen), findsOneWidget);
    expect(
        find.ancestor(
            of: find.text('Cardiologia'), matching: find.byType(Material)),
        findsWidgets);
    if (embedded) {
      expect(find.text('+SCORES'), findsNothing);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
      expect(tester.getTopLeft(find.byType(ListView)).dy, 0);
      nav.currentState!.pop();
    } else {
      final title = find.text('+SCORES');
      expect(title, findsOneWidget);
      final text = tester.widget<Text>(title);
      expect(text.style!.fontSize, 16);
      expect(text.style!.fontWeight, FontWeight.w900);
      expect(text.style!.color, dark ? Colors.white : const Color(0xFF05070A));
      final content =
          find.ancestor(of: title, matching: find.byType(Positioned)).first;
      final position = tester.widget<Positioned>(content);
      expect(position.top, 24);
      expect(position.height, 48);
      expect(tester.getTopLeft(find.byType(ListView)).dy, 72);
      final back = find.byIcon(Icons.arrow_back_ios_new_rounded);
      final hit =
          find.ancestor(of: back, matching: find.byType(GestureDetector)).first;
      expect(tester.getSize(hit), const Size(36, 36));
      await tester.tap(back);
    }
    await tester.pumpAndSettle();
    expect(find.text('ORIGEM_TESTE'), findsOneWidget);
    expect(find.byType(ToolsScreen), findsNothing);
    expect(tester.takeException(), isNull);
    // Root embedding retains the published back-to-Home notifier contract.
    if (!embedded) {
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AppProvider>.value(value: p),
            ChangeNotifierProvider.value(value: tools)
          ],
          child: MaterialApp(
              theme: dark ? ThemeData.dark() : ThemeData.light(),
              home: const Scaffold(body: ToolsScreen()))));
      await tester.pumpAndSettle();
      MainShell.pendingTab.value = -1;
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pump();
      expect(MainShell.pendingTab.value, 0);
      MainShell.pendingTab.value = -1;
    }
  } finally {
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPadding();
    tester.view.resetDevicePixelRatio();
    p.dispose();
    tools.dispose();
    io.provider.dispose();
  }
}

Future<void> verifyStudyNotice(WidgetTester tester,
    {required bool accept}) async {
  final io = await GuideHarness.open(tester);
  try {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: StudyWorkspaceScreen(isEs: false))));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Não inclua dados identificáveis de pacientes'),
        findsOneWidget);
    await tester.tap(find.text(accept ? 'Continuar' : 'Agora não'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(StudyWorkspaceScreen), findsOneWidget);
    expect(await StudyFirstUseNoticeService.isAccepted(), accept);
    expect(tester.takeException(), isNull);
  } finally {
    await tester.pumpWidget(const SizedBox());
    io.provider.dispose();
  }
}

class _PinnedProvider extends ToolsThemeProvider {
  _PinnedProvider() : super('pt', false);
  @override
  List<String> get pinnedCalcIds => [
        'calc_infusao',
        'calc_prescricoes',
        'calc_eletrólitos',
        'calc_cardio',
        'calc_nefrologia',
        'calc_hepatologia'
      ];
}

Future<void> verifyGuardiaFilter(WidgetTester tester) async {
  final io = await GuideHarness.open(tester);
  final p = _PinnedProvider();
  final calls = <String>[];
  try {
    await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
        value: p,
        child: MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child: MeuPlantaoDashboard(
                        onOpenDrug: (_) {},
                        onOpenCalc: calls.add,
                        onManageTap: () {},
                        onAddPatient: () {}))))));
    await tester.pumpAndSettle();
    final ids = ['calc_cardio', 'calc_nefrologia', 'calc_hepatologia'];
    for (final label in ['CARDIO', 'NEFRO', 'HEPATO']) {
      final f = find.text(label);
      expect(f, findsOneWidget);
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pumpAndSettle();
    }
    expect(calls, ids);
    for (final forbidden in ['INFUSÃO', 'PRESCRIÇÕES', 'ELETRÓLITOS']) {
      expect(find.text(forbidden), findsNothing);
    }
    expect(tester.takeException(), isNull);
  } finally {
    await tester.pumpWidget(const SizedBox());
    p.dispose();
    io.provider.dispose();
  }
}

Future<void> verifyPediatricGeometry(WidgetTester tester,
    {bool dark = false}) async {
  final io = await GuideHarness.open(tester);
  final p = ToolsThemeProvider('pt', dark);
  try {
    await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
        value: p,
        child: MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: const Scaffold(body: PediatricsTabContent()))));
    await tester.pumpAndSettle();
    final body = find.byWidgetPredicate((w) =>
        w is SingleChildScrollView && w.scrollDirection == Axis.vertical);
    expect(body, findsOneWidget);
    expect(tester.getTopLeft(body).dy, 40);
    expect(tester.widget<SingleChildScrollView>(body).padding,
        const EdgeInsets.fromLTRB(0.5, 0.1, 0.5, 100));
    final cards = find.byWidgetPredicate((w) =>
        w is Container &&
        w.padding == const EdgeInsets.fromLTRB(17, 10, 17, 10));
    expect(cards, findsWidgets);
    for (final card in tester.widgetList<Container>(cards)) {
      final d = card.decoration as BoxDecoration;
      expect(d.color, dark ? const Color(0xFF252930) : Colors.white);
      expect(d.borderRadius, BorderRadius.circular(8));
      expect(d.border, isNull);
      expect(d.boxShadow, isNull);
    }
    final cardRects = cards
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .toList();
    expect(cardRects.first.top, closeTo(40.1, 0.001));
    expect(cardRects.first.left, 0.5);
    for (var i = 1; i < cardRects.length; i++) {
      expect(cardRects[i].top - cardRects[i - 1].bottom, closeTo(3, 0.001));
    }
    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields, isNotEmpty);
    for (final f in fields) {
      expect(f.style!.fontSize, 15.5);
      expect(f.decoration!.hintStyle!.fontSize, 14);
      expect(f.decoration!.fillColor,
          dark ? const Color(0xFF1F232A) : Colors.white);
      expect((f.decoration!.enabledBorder as OutlineInputBorder).borderRadius,
          BorderRadius.circular(8));
      expect(f.cursorColor, const Color(0xFF0D6B57));
    }
    final labels = ['BIOMETRIA', 'CRESCIMENTO', 'FUNÇÃO RENAL', 'PEWS'];
    for (final label in labels) {
      final t = tester.widget<Text>(find.text(label));
      expect(t.style!.fontSize, 12);
      expect(t.style!.fontWeight, FontWeight.w700);
    }
    expect(tester.takeException(), isNull);
  } finally {
    await tester.pumpWidget(const SizedBox());
    p.dispose();
    io.provider.dispose();
  }
}

Future<void> verifyAdaptiveScoreInputs(WidgetTester tester,
    {bool dark = false}) async {
  final io = await GuideHarness.open(tester);
  final p = ToolsThemeProvider('pt', dark);
  final tools = ToolsStateProvider();
  try {
    for (final page in <Widget>[
      const NephroScoreDetailScreen(scoreId: NephroScoreId.ckdEpi2021),
      const CardioScoreDetailScreen(scoreId: CardioScoreId.heart),
      const HepatoScoreDetailScreen(scoreId: HepatoScoreId.meld30),
      const ElectrolytesScoreDetailScreen(
          scoreId: ElectrolytesScoreId.correctedSodium)
    ]) {
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AppProvider>.value(value: p),
            ChangeNotifierProvider.value(value: tools)
          ],
          child: MaterialApp(
              theme: dark ? ThemeData.dark() : ThemeData.light(), home: page)));
      await tester.pumpAndSettle();
      expect(find.byType(page.runtimeType), findsOneWidget);
      final fields =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields, isNotEmpty);
      for (final f in fields) {
        expect(f.controller, isNotNull);
        expect(f.decoration!.filled, isTrue);
        expect(
            f.decoration!.fillColor,
            dark
                ? const Color(0xFF222A35)
                : ((page is NephroScoreDetailScreen ||
                        page is CardioScoreDetailScreen)
                    ? Colors.white
                    : const Color(0xFFF8FAFC)));
        expect(f.style!.color,
            dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827));
        final border = f.decoration!.enabledBorder as OutlineInputBorder;
        expect(border.borderSide.color,
            dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC));
        expect(
            (f.decoration!.focusedBorder as OutlineInputBorder)
                .borderSide
                .color,
            const Color(0xFF009C3B));
      }
      // Built-in values are left untouched; this checks rendering, never adds a dose or patient input.
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  } finally {
    await tester.pumpWidget(const SizedBox());
    p.dispose();
    tools.dispose();
    io.provider.dispose();
  }
}

Future<void> verifyHistoryOutcomePalette(WidgetTester tester,
    {bool dark = false}) async {
  final io = await GuideHarness.open(tester);
  final p = HistoryRuntimeProvider('pt', dark);
  try {
    final outcomes = <String, Color>{
      'alta': const Color(0xFF10B981),
      'obito': const Color(0xFFEF4444),
      'transferencia': const Color(0xFF3B82F6),
      'internado': const Color(0xFFF59E0B)
    };
    for (final entry in outcomes.entries) {
      p.myHistories.clear();
      p.myHistories.add(ClinicalHistoryModel.blank(authorUid: 'runtime-test')
          .copyWith(
              patientInitials: 'CAMPO_TESTE',
              chiefComplaint: 'CAMPO_TESTE',
              outcome: entry.key));
      await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
          value: p,
          child: MaterialApp(
              theme: dark ? ThemeData.dark() : ThemeData.light(),
              home: const Scaffold(body: HistoryScreen()))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MINHAS'));
      await tester.pumpAndSettle();
      final card = find
          .byWidgetPredicate((w) => w.runtimeType.toString() == '_HistoryCard');
      expect(card, findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('CAMPO_TESTE')),
          findsWidgets);
      final blocks = tester.widgetList<Container>(
          find.descendant(of: card, matching: find.byType(Container)));
      expect(
          blocks.any((w) =>
              w.color == entry.value ||
              (w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).color == entry.value)),
          isTrue,
          reason: entry.key);
      await tester.pumpWidget(const SizedBox());
    }
    expect(tester.takeException(), isNull);
  } finally {
    await tester.pumpWidget(const SizedBox());
    p.dispose();
    io.provider.dispose();
  }
}

Future<void> verifyPediatricShell(WidgetTester tester) async {
  final io = await GuideHarness.open(tester);
  final p = ToolsThemeProvider('pt', false);
  var backs = 0;
  tester.view.padding = FakeViewPadding(top: 24);
  tester.view.devicePixelRatio = 1;
  try {
    await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
        value: p,
        child: MaterialApp(
            home: PediatricsMainShellWorkspace(onBack: () => backs++))));
    await tester.pumpAndSettle();
    expect(find.text('PEDIATRIA'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(PediatricsTabContent)).dy, 72);
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    expect(backs, 1);
    expect(tester.takeException(), isNull);
  } finally {
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPadding();
    tester.view.resetDevicePixelRatio();
    p.dispose();
    io.provider.dispose();
  }
}
