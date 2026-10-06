import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/mobile_ai_action_bar.dart';

void main() {
  setUpAll(() async {
    var dir = File(Platform.resolvedExecutable).parent;
    while (!Directory('${dir.path}/material_fonts').existsSync() &&
        dir.parent.path != dir.path) {
      dir = dir.parent;
    }
    final loader = FontLoader('Roboto');
    loader.addFont(Future.value(ByteData.sublistView(
        File('${dir.path}/material_fonts/Roboto-Regular.ttf')
            .readAsBytesSync())));
    await loader.load();
  });
  for (final dark in [true, false]) {
    for (final lang in ['pt', 'es']) {
      testWidgets(
          'actual mobile AI header keeps canonical brand $lang dark=$dark',
          (t) async {
        await t.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => t.binding.setSurfaceSize(null));
        var settings = 0;
        await t.pumpWidget(MaterialApp(
            home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
              body: MobileAiActionBar(
            dark: dark,
            lang: lang,
            historyCount: 1,
            hasMessages: true,
            hasRealAi: true,
            isConnected: true,
            keyLoading: false,
            onHistory: () {},
            onClear: () {},
            onSettings: () => settings++,
          )),
        )));
        final title = find.text('MedCases Clinical', findRichText: true);
        expect(title, findsOneWidget);
        expect(find.text('MEDCASES IA', findRichText: true), findsNothing);
        final titleRect = t.getRect(title);
        final identity = find.byType(AiConnectionIdentity);
        expect(titleRect.left, greaterThanOrEqualTo(t.getRect(identity).right));
        expect(titleRect.right, lessThanOrEqualTo(320));
        await t.tap(identity);
        expect(settings, 1);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
