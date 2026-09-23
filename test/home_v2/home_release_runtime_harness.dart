import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:medcases/providers/app_provider.dart';
import 'package:medcases/screens/home_screen.dart';
import 'package:medcases/screens/internacion/internacion_screen.dart';
import 'package:medcases/home_v2/theme/home_v2_palette.dart';
import '../guides/guide_runtime_fixture.dart';

class HomeRuntimeProvider extends GuideAppProvider {
  HomeRuntimeProvider(super.language, this.dark);
  final bool dark;
  @override
  bool get darkMode => dark;
}

class RouteRecorder extends NavigatorObserver {
  final pushes = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes.add(route);
  }
}

Future<void> mountRealHome(WidgetTester tester,
    {bool dark = false,
    String language = 'pt',
    bool module = false,
    RouteRecorder? root,
    RouteRecorder? nested}) async {
  final io = await GuideHarness.open(tester);
  final provider = HomeRuntimeProvider(language, dark);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
    io.provider.dispose();
  });
  final content = module
      ? HomeMiGuardiaSection(
          dark: dark,
          isEs: language == 'es',
          onTabChange: (_) {},
          openProtocol: (_) {})
      : HomeScreen(
          onTabChange: (_) {},
          onSubTabChange: (_) {},
          openProtocol: (_) {},
          onOpenNotes: () {});
  await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
    value: provider,
    child: MaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      navigatorObservers: root == null ? [] : [root],
      home: Navigator(
          observers: nested == null ? [] : [nested],
          onGenerateRoute: (_) =>
              MaterialPageRoute<void>(builder: (_) => Scaffold(body: content))),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> verifyRealTimer(WidgetTester tester,
    {bool dark = false, String language = 'pt'}) async {
  await mountRealHome(tester, dark: dark, language: language);
  await tester.ensureVisible(find.text('Timer'));
  await tester.tap(find.text('Timer'));
  await tester.pumpAndSettle();
  final title = language == 'es' ? 'Temporizador clínico' : 'Timer clínico';
  expect(find.text(title), findsOneWidget);
  final actionLabel =
      language == 'es' ? 'Programar revisión' : 'Programar revisão';
  final action = find.ancestor(
      of: find.text(actionLabel), matching: find.byType(FilledButton));
  expect(action, findsOneWidget);
  final button = tester.widget<FilledButton>(action);
  expect(button.onPressed, isNotNull);
  final palette = HomeV2Palette.resolve(dark);
  expect(button.style!.backgroundColor!.resolve({}), palette.accent);
  expect(button.style!.backgroundColor!.resolve({WidgetState.disabled}),
      palette.surfaceStrong);
  expect(button.style!.foregroundColor!.resolve({WidgetState.disabled}),
      palette.textMuted);
  expect(button.style!.backgroundColor!.resolve({}),
      isNot(const Color(0xFF7C3AED)));
  final modal = find
      .ancestor(of: find.text(title), matching: find.byType(BottomSheet))
      .first;
  final numeric = find.descendant(
      of: modal,
      matching: find.byWidgetPredicate(
          (w) => w is TextField && w.keyboardType == TextInputType.number));
  expect(numeric, findsOneWidget);
  await tester.enterText(numeric, '25');
  expect(tester.widget<TextField>(numeric).controller!.text, '25');
  expect(
      find.descendant(of: modal, matching: find.text('0/5')), findsOneWidget);
  Navigator.of(tester.element(find.text(title))).pop();
  await tester.pumpAndSettle();
  expect(find.text(title), findsNothing);
  expect(tester.takeException(), isNull);
}

Future<void> verifyRealPatientRoute(WidgetTester tester,
    {required bool module}) async {
  final root = RouteRecorder();
  final nested = RouteRecorder();
  await mountRealHome(tester, module: module, root: root, nested: nested);
  root.pushes.clear();
  nested.pushes.clear();
  await tester.ensureVisible(find.text('+ PACIENTE'));
  await tester.tap(find.text('+ PACIENTE'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  expect(root.pushes, hasLength(1),
      reason: 'Native patient route must escape the nested Home navigator');
  expect(nested.pushes, isEmpty);
  expect(find.byType(InternacionScreen), findsOneWidget);
  expect(find.text('Dados do Paciente'), findsOneWidget);
  expect(find.text('SOAP'), findsWidgets);
  expect(tester.takeException(), isNull);
}
