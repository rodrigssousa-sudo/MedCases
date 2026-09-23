import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';
import 'package:medcases/screens/ai/widgets/therapeutic_options_view.dart';
import 'package:medcases/services/clinical_content/clinical_content_gateway.dart';
import 'package:medcases/services/plantao_knowledge/remote_knowledge_resolver.dart';
import 'package:medcases/providers/app_provider.dart';
import 'knowledge_fixture.dart';

void main() {
  for (final language in ['pt', 'es'])
    testWidgets('real Plantao copy label and option isolation $language',
        (tester) async {
      var files = fixtureRelease(syntheticProtocol());
      final gateway = ClinicalContentGateway(
          baseUri: Uri.parse('https://example.invalid/'),
          store: MemoryClinicalSnapshotStore(),
          sessionScope: 'A',
          currentSessionScope: () => 'A',
          canReadDomain: (_) => true,
          tokenProvider: () async => 'TEST_TOKEN',
          client: MockClient((r) async =>
              http.Response(jsonEncode(files[r.url.path.substring(1)]), 200)));
      addTearDown(gateway.close);
      final resolver = RemoteKnowledgeResolver(gateway);
      final resolution =
          (await tester.runAsync(() => resolver.resolve('TEST_CONTEXT_ID')))!;
      final session = TherapeuticOptionSession(
          resolver: resolver,
          resolution: resolution,
          language: language,
          ownsRequest: () => true,
          safetyAllows: (_) => true,
          lookupDrug: (_) async => true,
          refreshEvidence: () async => []);
      String? copied;
      var followups = 0;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData')
          copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      Future<void>? pendingCopy;
      Future<void> copy(String id) {
        return pendingCopy = tester.runAsync(() async {
          final text = await session.copy(id);
          if (text != null) await Clipboard.setData(ClipboardData(text: text));
        }).then((_) {});
      }

      Widget page(List<Map<String, dynamic>> options) => MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: GuardiaClinicalResponseView(
                      rawText: 'TEST_CONTEXT\nTratamento\nTEST_TREATMENT',
                      dark: false,
                      languageCode: language,
                      onCopy: () => copy(options.first['optionId'] as String),
                      therapeuticOptions: TherapeuticOptionsView(
                          session: session,
                          options: options,
                          onCopy: copy,
                          onAlternatives: () => followups++)))));
      final primary = (await tester.runAsync(() => session.options()))!;
      await tester.pumpWidget(page(primary));
      await tester.pumpAndSettle();
      expect(find.text('COPIAR'), findsOneWidget);
      expect(find.textContaining('TEST_OPTION_1'), findsNothing);
      final followup = find.text(language == 'es'
          ? 'Ver otras opciones terapéuticas'
          : 'Ver outras opções terapêuticas');
      expect(followup, findsOneWidget);
      await tester.ensureVisible(followup);
      await tester.tap(followup);
      expect(followups, 1);
      final mainCopy = find.byKey(const ValueKey('guardia_copy_action'));
      await tester.ensureVisible(mainCopy);
      await tester.tap(mainCopy);
      await pendingCopy!;
      await tester.pumpAndSettle();
      expect(copied, contains('TEST_VALUE_0'));
      expect(copied, isNot(contains('TEST_WARNING')));
      final alternatives =
          (await tester.runAsync(() => session.options(alternatives: true)))!;
      await tester.pumpWidget(page(alternatives));
      await tester.pumpAndSettle();
      final alternative = find.byKey(const ValueKey('copy_TEST_OPTION_2'));
      await tester.ensureVisible(alternative);
      await tester.tap(alternative);
      await pendingCopy!;
      await tester.pumpAndSettle();
      expect(copied, contains('TEST_VALUE_2'));
      expect(copied, isNot(contains('TEST_VALUE_0')));
      expect(copied, isNot(contains('TEST_REFERENCE')));
      files = fixtureRelease(syntheticProtocol(), sequence: 2, revoked: true);
      await tester.runAsync(() => gateway.sync());
      await tester.pumpAndSettle();
      expect(find.textContaining('TEST_OPTION_2'), findsNothing);
      expect(
          await tester.runAsync(() => session.copy('TEST_OPTION_2')), isNull);
    });
  test(
      'existing productive AppProvider cannot authorize an unowned prescription',
      () {
    final p = AppProvider();
    try {
      expect(
          p.authorizesPracticalPrescription(
              'UNOWNED', 'PRESCRIÇÃO PRÁTICA\nTEST_VALUE'),
          isFalse);
    } finally {
      p.dispose();
    }
  });
}
