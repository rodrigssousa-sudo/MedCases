import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'history_light_runtime_harness.dart';

void main() {
  testWidgets(
      'expanded microphone retains readable light palette and toggle state',
      (tester) async {
    await openHistoryLightEditor(tester);
    await tester.tap(find.text('Anamnese'));
    await tester.pumpAndSettle();
    final heading = find.text('Ditado e IA');
    expect(heading, findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsWidgets);
    await tester.tap(heading);
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(heading);
    expect(text.style!.color, const Color(0xFF05070A));
    expect(contrastRatio(text.style!.color!, const Color(0xFFECF1F3)),
        greaterThanOrEqualTo(4.5));
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lab and ECG render readable editable fields on light surfaces',
      (tester) async {
    await openHistoryLightEditor(tester);
    await tester.tap(find.text('Exames'));
    await tester.pumpAndSettle();
    for (final label in ['EXAMES LABORATORIAIS', 'ECG']) {
      final section = find.text(label);
      expect(section, findsOneWidget);
      await tester.ensureVisible(section);
      await tester.tap(section);
      await tester.pumpAndSettle();
    }
    expect(find.text('Hb (g/dL)'), findsOneWidget);
    expect(find.text('FC (bpm)'), findsOneWidget);
    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.length, greaterThanOrEqualTo(23));
    final numericFields = fields
        .where((f) =>
            f.keyboardType == TextInputType.number ||
            f.keyboardType ==
                const TextInputType.numberWithOptions(
                    decimal: true, signed: false))
        .toList();
    expect(numericFields, hasLength(21));
    for (final field in numericFields) {
      expect(field.style!.color, const Color(0xFF05070A));
      expect(field.decoration!.fillColor, const Color(0xFFF8FAFC));
      expect(contrastRatio(field.style!.color!, field.decoration!.fillColor!),
          greaterThanOrEqualTo(4.5));
    }
    final heartRate = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '72');
    expect(heartRate, findsOneWidget);
    await tester.ensureVisible(heartRate);
    await tester.enterText(heartRate, '72');
    await tester.pump();
    expect(tester.widget<TextField>(heartRate).controller!.text, '72');
    expect(tester.takeException(), isNull);
  });
}
