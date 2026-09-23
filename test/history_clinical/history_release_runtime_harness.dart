import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:medcases/providers/app_provider.dart';
import 'package:medcases/screens/history_screen.dart';
import 'package:medcases/models/clinical_history_model.dart';
import '../guides/guide_runtime_fixture.dart';

class HistoryRuntimeProvider extends GuideAppProvider {
  HistoryRuntimeProvider(super.language, this.dark);
  final bool dark;
  int publicLoads = 0;
  @override
  bool get darkMode => dark;
  @override
  Future<void> loadHistories() async {}
  @override
  Future<void> loadPublicHistories({bool forceRemote = false}) async {
    publicLoads++;
  }
}

Future<HistoryRuntimeProvider> mountHistoryRuntime(WidgetTester tester,
    {bool dark = false, String language = 'pt', bool saved = false}) async {
  // Each scenario owns a fresh Navigator, including modal routes.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
  final io = await GuideHarness.open(tester);
  final p = HistoryRuntimeProvider(language, dark);
  if (saved) {
    // Explicitly authorized technical records, confined to tests. Real model
    // factory and UI; no doses, plausible diagnoses, or personal information.
    p.myHistories
        .add(ClinicalHistoryModel.blank(authorUid: 'runtime-test').copyWith(
      patientInitials: 'CAMPO_TESTE',
      chiefComplaint: 'CAMPO_TESTE <&>',
      allergies: 'CAMPO_TESTE_ALERGIA',
      workingDiagnosis: 'CAMPO_TESTE_HIPOTESE',
      evolutions: [
        EvolutionEntry.blank().copyWith(text: 'CAMPO_TESTE_EVOLUCAO')
      ],
    ));
  }
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    p.dispose();
    io.provider.dispose();
  });
  await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
    value: p,
    child: MaterialApp(
        theme: dark ? ThemeData.dark() : ThemeData.light(),
        home: const Scaffold(body: HistoryScreen())),
  ));
  await tester.pumpAndSettle();
  return p;
}

Future<void> enterHistoryEditor(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Preencher manualmente'));
  await tester.tap(find.text('Preencher manualmente'));
  await tester.pumpAndSettle();
  expect(HistoryScreen.editorActive.value, isTrue);
}

Future<void> verifyHistoryNavigation(WidgetTester tester,
    {bool dark = false, String language = 'pt'}) async {
  final p = await mountHistoryRuntime(tester, dark: dark, language: language);
  final labels = [
    language == 'es' ? 'MIS HCs' : 'MINHAS',
    'PÚBLICAS',
    language == 'es' ? '+ NUEVA' : '+ NOVA'
  ];
  final tabs = labels
      .map((label) => find
          .ancestor(
              of: find.text(label), matching: find.byType(AnimatedContainer))
          .first)
      .toList();
  final sizes = tabs.map(tester.getSize).toList();
  final strip =
      find.ancestor(of: tabs.first, matching: find.byType(Container)).first;
  final decoration =
      tester.widget<Container>(strip).decoration! as BoxDecoration;
  final border = decoration.border! as Border;
  expect(border.bottom.width, 0.7);
  expect(tester.getSize(strip).height, 40);
  expect(sizes[0].width, closeTo(sizes[1].width, 0.01));
  expect(sizes[1].width, closeTo(sizes[2].width, 0.01));
  for (var i = 0; i < tabs.length; i++) {
    expect(sizes[i].height + border.bottom.width, closeTo(40, 0.001));
    expect(tester.getTopLeft(tabs[i]).dy, 48);
    final text = tester.widget<Text>(find.text(labels[i]));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.style!.fontSize, 12);
  }
  final view = tester.widget<TabBarView>(find.byType(TabBarView));
  expect(view.children, hasLength(3));
  expect(view.controller!.index, 2);
  for (var i = 0; i < 2; i++) {
    await tester.tap(find.text(labels[i]));
    await tester.pumpAndSettle();
    expect(view.controller!.index, i);
    expect(tester.widget<Text>(find.text(labels[i])).style!.color,
        const Color(0xFF0E8000));
  }
  expect(p.publicLoads, greaterThan(0));
  expect(tester.takeException(), isNull);
}

Future<void> openSavedHistory(WidgetTester tester, {bool dark = true}) async {
  await mountHistoryRuntime(tester, dark: dark, saved: true);
  await tester.tap(find.text('MINHAS'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('CAMPO_TESTE <&>'));
  await tester.pumpAndSettle();
}

Future<void> verifyHistoryPngCanvas(WidgetTester tester,
    {bool dark = true}) async {
  await openSavedHistory(tester, dark: dark);
  final boundary = find
      .ancestor(of: find.text('M+'), matching: find.byType(RepaintBoundary))
      .first;
  final canvas = tester.widget<RepaintBoundary>(boundary).child! as Container;
  expect(
      canvas.color, dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3));
  expect(
      find.descendant(of: boundary, matching: find.text('CAMPO_TESTE_ALERGIA')),
      findsOneWidget);
  expect(
      find.descendant(
          of: boundary, matching: find.text('CAMPO_TESTE_HIPOTESE')),
      findsOneWidget);
  expect(tester.takeException(), isNull);
}

Future<void> verifyHistoryPreviewMetadata(WidgetTester tester) async {
  await openSavedHistory(tester);
  await tester.tap(find.byIcon(Icons.edit_rounded).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ver'));
  await tester.pumpAndSettle();
  final sheet = find.byType(DraggableScrollableSheet);
  expect(sheet, findsOneWidget);
  for (final label in ['SEXO', 'ESPECIALIDADE']) {
    expect(
        find.descendant(of: sheet, matching: find.text(label)), findsOneWidget);
  }
  for (final value in ['CAMPO_TESTE', 'Masculino', 'Clínica Geral']) {
    final text = find.descendant(of: sheet, matching: find.text(value));
    expect(text, findsOneWidget);
    expect(tester.widget<Text>(text).style!.color, const Color(0xFFE8F0EC));
  }
  expect(find.descendant(of: sheet, matching: find.text('CAMPO_TESTE_ALERGIA')),
      findsOneWidget);
  await tester.scrollUntilVisible(
      find.textContaining('Documento gerado em'), 300,
      scrollable:
          find.descendant(of: sheet, matching: find.byType(Scrollable)).first,
      maxScrolls: 30);
  await tester.pumpAndSettle();
  expect(
      find.descendant(
          of: sheet, matching: find.textContaining('Documento gerado em')),
      findsOneWidget);
  expect(tester.takeException(), isNull);
}

Future<void> verifyHistoryKeyboard(WidgetTester tester) async {
  await mountHistoryRuntime(tester);
  await enterHistoryEditor(tester);
  await tester.tap(find.text('Exame Físico'));
  await tester.pumpAndSettle();
  final age = find
      .byWidgetPredicate((w) =>
          w is TextField &&
          (w.keyboardType == TextInputType.number ||
              w.keyboardType ==
                  const TextInputType.numberWithOptions(decimal: true)))
      .first;
  await tester.ensureVisible(age);
  await tester.showKeyboard(age);
  tester.view.viewInsets = const FakeViewPadding(bottom: 300);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpAndSettle();
  final previous = FocusManager.instance.primaryFocus;
  final scroll = tester
      .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
      .firstWhere((w) =>
          w.keyboardDismissBehavior ==
          ScrollViewKeyboardDismissBehavior.onDrag);
  expect(scroll.padding, const EdgeInsets.fromLTRB(16, 12, 16, 16));
  expect(find.text('Próximo'), findsOneWidget);
  expect(find.text('OK'), findsOneWidget);
  await tester.tap(find.text('Próximo'));
  await tester.pumpAndSettle();
  expect(FocusManager.instance.primaryFocus, isNot(same(previous)));
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  expect(FocusManager.instance.primaryFocus?.context?.widget,
      isNot(isA<EditableText>()));
  expect(tester.takeException(), isNull);
}

Future<void> verifyHistoryExamPalette(WidgetTester tester,
    {bool dark = true}) async {
  await mountHistoryRuntime(tester, dark: dark);
  await enterHistoryEditor(tester);
  await tester.tap(find.text('Exames'));
  await tester.pumpAndSettle();
  for (final label in ['EXAMES LABORATORIAIS', 'ECG']) {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }
  final numeric = tester
      .widgetList<TextField>(find.byType(TextField))
      .where((f) =>
          f.keyboardType == TextInputType.number ||
          f.keyboardType ==
              const TextInputType.numberWithOptions(decimal: true))
      .toList();
  expect(numeric, hasLength(21));
  for (final field in numeric) {
    expect(field.decoration!.fillColor,
        dark ? const Color(0xFF2D3340) : const Color(0xFFF8FAFC));
    expect(field.style!.color,
        dark ? const Color(0xFFE8F0EC) : const Color(0xFF05070A));
  }
  expect(tester.takeException(), isNull);
}

Future<void> verifyHistoryOcrPicker(WidgetTester tester,
    {bool dark = true}) async {
  await mountHistoryRuntime(tester, dark: dark);
  await enterHistoryEditor(tester);
  await tester.tap(find.text('Exames'));
  await tester.pumpAndSettle();
  final action = find.text('Escanear Exame com IA');
  await tester.ensureVisible(action);
  final card =
      find.ancestor(of: action, matching: find.byType(Container)).first;
  final decoration =
      tester.widget<Container>(card).decoration! as BoxDecoration;
  expect((decoration.gradient! as LinearGradient).colors,
      [const Color(0xFF14213D), const Color(0xFF172A46)]);
  await tester.tap(action);
  await tester.pumpAndSettle();
  expect(find.byType(BottomSheet), findsOneWidget);
  final sheet = find.byType(BottomSheet);
  for (final label in [
    'Tirar foto',
    'Usar a câmera',
    'Escolher da galeria',
    'Selecionar imagem existente'
  ]) {
    expect(
        find.descendant(of: sheet, matching: find.text(label)), findsOneWidget);
  }
  final icons = tester
      .widgetList<Icon>(find.descendant(of: sheet, matching: find.byType(Icon)))
      .where((icon) => icon.color == const Color(0xFF0D6B57));
  expect(icons, hasLength(2));
  expect(
      tester
          .widget<Divider>(
              find.descendant(of: sheet, matching: find.byType(Divider)))
          .indent,
      36);
  expect(tester.takeException(), isNull);
}

Future<void> verifyHistoryListSurface(WidgetTester tester) async {
  await mountHistoryRuntime(tester, dark: true, saved: true);
  await tester.tap(find.text('MINHAS'));
  await tester.pumpAndSettle();
  final card = find
      .ancestor(
          of: find.text('CAMPO_TESTE <&>'), matching: find.byType(Container))
      .first;
  final decoration =
      tester.widget<Container>(card).decoration! as BoxDecoration;
  expect(decoration.color, const Color(0xFF252930));
  expect(decoration.boxShadow, isNull);
  expect(decoration.gradient, isNull);
  expect(decoration.borderRadius, BorderRadius.circular(12));
  expect((decoration.border! as Border).top.width, 0.7);
  expect(find.text('Hip.: CAMPO_TESTE_HIPOTESE'), findsOneWidget);
  expect(tester.takeException(), isNull);
}

Future<void> verifyHistoryEvolution(WidgetTester tester) async {
  await openSavedHistory(tester);
  await tester.tap(find.byIcon(Icons.edit_rounded).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Evolução'));
  await tester.pumpAndSettle();
  for (final label in ['Enfermagem', 'Lab', 'Imagem', 'Procedimento']) {
    final tab = find.text(label);
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await tester.pumpAndSettle();
    final container =
        find.ancestor(of: tab, matching: find.byType(AnimatedContainer)).first;
    final decoration = tester.widget<AnimatedContainer>(container).decoration!
        as BoxDecoration;
    expect(decoration.color, isNull);
    expect(decoration.gradient, isNull);
    expect(
        (decoration.border! as Border).bottom.color, const Color(0xFF0D6B57));
    expect((decoration.border! as Border).bottom.width, 2);
    expect(find.text('CAMPO_TESTE_EVOLUCAO'), findsOneWidget);
  }
  expect(tester.takeException(), isNull);
}

Future<void> verifyHistoryTopbar(WidgetTester tester) async {
  await mountHistoryRuntime(tester, dark: true);
  final backgrounds =
      tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).where((w) {
    final d = w.decoration;
    return d is BoxDecoration &&
        d.color == const Color(0xFF252930).withAlpha((255 * 0.70).round());
  }).toList();
  expect(backgrounds, hasLength(1));
  final d = backgrounds.single.decoration as BoxDecoration;
  expect(d.boxShadow, isNull);
  expect(d.gradient, isNull);
  expect((d.border! as Border).bottom,
      const BorderSide(color: Color(0xFF374151), width: 0.7));
  expect(tester.takeException(), isNull);
}

Future<void> verifyHistoryVitals(WidgetTester tester,
    {bool dark = true}) async {
  await mountHistoryRuntime(tester, dark: dark);
  await enterHistoryEditor(tester);
  await tester.tap(find.text('Exame Físico'));
  await tester.pumpAndSettle();
  final fields = tester
      .widgetList<TextField>(find.byType(TextField))
      .where((w) =>
          w.keyboardType == TextInputType.number ||
          w.keyboardType ==
              const TextInputType.numberWithOptions(decimal: true))
      .toList();
  expect(fields, hasLength(8));
  for (final field in fields) {
    expect(field.decoration!.fillColor,
        dark ? const Color(0xFF2D3340) : const Color(0xFFECF1F3));
    final border = field.decoration!.enabledBorder! as OutlineInputBorder;
    expect(
        border.borderSide,
        BorderSide(
            color: dark ? const Color(0xFF374151) : const Color(0xFFD8E0E7),
            width: 0.8));
    expect(field.scrollPadding, const EdgeInsets.only(bottom: 36));
  }
  expect(tester.takeException(), isNull);
}
