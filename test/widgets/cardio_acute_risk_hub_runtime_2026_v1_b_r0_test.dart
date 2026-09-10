import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/widgets/cardio/cardio_acute_risk_hub.dart';

Widget _app({
  required bool isEs,
  required bool dark,
  required CardioScoreDeeplinkCallback callback,
}) {
  return MaterialApp(
    theme: dark ? ThemeData.dark() : ThemeData.light(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: CardioAcuteRiskHub(
            isEs: isEs,
            dark: dark,
            initialAge: 67,
            initialSbp: 132,
            initialHeartRate: 78,
            onOpenCalculator: callback,
          ),
        ),
      ),
    ),
  );
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  for (final size in <Size>[
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final dark in <bool>[false, true]) {
      for (final isEs in <bool>[false, true]) {
        testWidgets(
          'runtime layout ${size.width.toInt()}x${size.height.toInt()} '
          '${dark ? 'dark' : 'light'} ${isEs ? 'es' : 'pt'} has no overflow',
          (tester) async {
            await _setSize(tester, size);
            await tester.pumpWidget(
              _app(isEs: isEs, dark: dark, callback: (_, __) {}),
            );
            await tester.pumpAndSettle();

            expect(find.byKey(const Key('cardio_score_grid')), findsOneWidget);
            expect(find.byKey(const Key('score_card_heart')), findsOneWidget);
            expect(find.byKey(const Key('score_card_timi')), findsOneWidget);
            expect(find.byKey(const Key('score_card_grace')), findsOneWidget);
            expect(find.byKey(const Key('score_card_killip')), findsOneWidget);
            expect(tester.takeException(), isNull);

            final heartSize = tester.getSize(
              find.byKey(const Key('score_card_heart')),
            );
            final timiSize = tester.getSize(
              find.byKey(const Key('score_card_timi')),
            );
            expect((heartSize.width - timiSize.width).abs(), lessThan(1.0));
            expect(heartSize.height, greaterThan(100));
          },
        );
      }
    }
  }

  testWidgets('HEART calculates and sends detailed deeplink payload',
      (tester) async {
    await _setSize(tester, const Size(390, 844));
    String? scoreKey;
    Map<String, String>? payload;

    await tester.pumpWidget(
      _app(
        isEs: false,
        dark: false,
        callback: (key, params) {
          scoreKey = key;
          payload = params;
        },
      ),
    );

    expect(find.byKey(const Key('score_detail_panel')), findsNothing);
    await tester.tap(find.byKey(const Key('score_card_heart')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('score_detail_panel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('heart_calculate')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('score_result_box')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('score_open_calculator')));
    await tester.tap(find.byKey(const Key('score_open_calculator')));
    await tester.pump();

    expect(scoreKey, 'heart');
    expect(payload, isNotNull);
    expect(payload!['heartScore'], isNotNull);
    expect(payload!['heartAge'], '67');
    expect(tester.takeException(), isNull);
  });

  testWidgets('GRACE panel reuses age/SBP/HR and renders safely',
      (tester) async {
    await _setSize(tester, const Size(430, 932));
    await tester.pumpWidget(
      _app(isEs: true, dark: true, callback: (_, __) {}),
    );
    expect(find.byKey(const Key('score_detail_panel')), findsNothing);
    await tester.tap(find.byKey(const Key('score_card_grace')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('score_detail_panel')), findsOneWidget);
    expect(find.byKey(const Key('grace_age')), findsOneWidget);
    expect(find.byKey(const Key('grace_sbp')), findsOneWidget);
    expect(find.byKey(const Key('grace_hr')), findsOneWidget);
    expect(find.byKey(const Key('grace_creatinine')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
