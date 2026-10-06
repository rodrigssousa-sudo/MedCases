import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/widgets/cardio/cardio_acute_risk_hub.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('Scores touch dismissal and field transfer on $platform',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: platform),
        home: Scaffold(body: SingleChildScrollView(child: CardioAcuteRiskHub(
          isEs: true,
          dark: true,
          initialAge: 55,
          initialSbp: 132,
          initialHeartRate: 78,
          onOpenCalculator: (_, __) {},
        ))),
      ));
      await tester.tap(find.byKey(const Key('score_card_grace')));
      await tester.pumpAndSettle();
      final age = find.descendant(of: find.byKey(const Key('grace_age')), matching: find.byType(TextField));
      final sbp = find.descendant(of: find.byKey(const Key('grace_sbp')), matching: find.byType(TextField));
      await tester.ensureVisible(age);
      await tester.tap(age);
      await tester.enterText(age, '55');
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.tap(sbp);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(sbp, '132');
      // A touch in the panel padding is outside every editable field.
      final panel = tester.getRect(find.byKey(const Key('score_detail_panel')));
      await tester.tapAt(Offset(panel.left + 2, panel.top + 2));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.widget<TextField>(age).controller!.text, '55');
      expect(tester.widget<TextField>(sbp).controller!.text, '132');
      await tester.enterText(find.descendant(of: find.byKey(const Key('grace_creatinine')), matching: find.byType(TextField)), '1.0');
      await tester.tap(age);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.ensureVisible(find.byKey(const Key('grace_calculate')));
      await tester.tap(find.byKey(const Key('grace_calculate')));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.byKey(const Key('score_result_box')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
