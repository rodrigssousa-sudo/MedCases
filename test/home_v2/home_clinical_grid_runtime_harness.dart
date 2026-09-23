import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:medcases/home_v2/components/home_v2_modules_view.dart';

Future<void> verifyClinicalGrid(WidgetTester tester,
    {required bool dark, required bool isEs}) async {
  final calls = <String>[];
  await tester.pumpWidget(MaterialApp(
    theme: dark ? ThemeData.dark() : ThemeData.light(),
    home: Scaffold(
        body: HomeV2ClinicalGrid(
      dark: dark,
      isEs: isEs,
      onPatient: () => calls.add('patient'),
      onPediatrics: () => calls.add('pediatrics'),
      onTools: () => calls.add('tools'),
      onClinicalHistory: () => calls.add('history'),
    )),
  ));
  await tester.pumpAndSettle();
  final labels = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .toList();
  expect(labels, contains('PACIENTES'));
  expect(labels, contains(isEs ? 'PEDIATRÍA' : 'PEDIATRIA'));
  expect(find.byType(SvgPicture), findsNWidgets(4));
  final icons = tester.widgetList<SvgPicture>(find.byType(SvgPicture)).toList();
  expect(icons.map((icon) => (icon.bytesLoader as SvgAssetLoader).assetName), [
    'assets/icons/home_v2/ic_ferramentas.svg',
    'assets/icons/home_v2/ic_historia.svg',
    'assets/icons/home_v2/ic_paciente.svg',
    'assets/icons/home_v2/ic_pediatria.svg',
  ]);
  for (final icon in icons) {
    expect(icon.colorFilter, isNull,
        reason: 'Preserve the colors authored in the canonical SVG');
    expect(icon.width, 54);
    expect(icon.height, 54);
  }
  expect(find.byType(GridView), findsNothing);
  expect(labels,
      ['+SCORES', 'H. CLÍNICA', 'PACIENTES', isEs ? 'PEDIATRÍA' : 'PEDIATRIA']);
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    expect(text.style!.fontSize, 11);
    expect(text.textAlign, TextAlign.center);
  }
  final glyphs = find.byType(SvgPicture);
  final boxes = List.generate(4, (i) => tester.getRect(glyphs.at(i)));
  expect(boxes[0].top, boxes[1].top);
  expect(boxes[2].top, boxes[3].top);
  expect(boxes[2].top - boxes[0].top, closeTo(111.2, 0.01));
  expect(boxes[0].right, lessThan(boxes[1].left));
  for (final label in labels) {
    await tester.tap(find.text(label));
  }
  expect(calls, ['tools', 'history', 'patient', 'pediatrics']);
  expect(tester.takeException(), isNull);
}
