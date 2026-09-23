import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:medcases/providers/app_provider.dart';
import 'package:medcases/screens/history_screen.dart';
import '../guides/guide_runtime_fixture.dart';

// Reuse the established Firebase IO setup. History UI, draft creation,
// navigation, text controllers, focus, colors and layout are production code.
class HistoryLightProvider extends GuideAppProvider {
  HistoryLightProvider() : super('pt');
  @override
  Future<void> loadHistories() async {}
  @override
  Future<void> loadPublicHistories({bool forceRemote = false}) async {}
}

Future<void> openHistoryLightEditor(WidgetTester tester) async {
  final io = await GuideHarness.open(tester);
  final provider = HistoryLightProvider();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
    io.provider.dispose();
  });
  await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
    value: provider,
    child: MaterialApp(
      theme: ThemeData.light(),
      home: const Scaffold(body: HistoryScreen()),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Preencher manualmente'));
  await tester.tap(find.text('Preencher manualmente'));
  await tester.pumpAndSettle();
  expect(HistoryScreen.editorActive.value, isTrue);
}

double contrastRatio(Color foreground, Color background) {
  final effective = Color.alphaBlend(foreground, background);
  final a = effective.computeLuminance();
  final b = background.computeLuminance();
  return (a > b ? a + .05 : b + .05) / (a > b ? b + .05 : a + .05);
}
