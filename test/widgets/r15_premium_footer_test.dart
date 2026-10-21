import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:medcases/screens/ai/widgets/collapsible_content_blocks.dart';
import 'package:medcases/screens/ai/widgets/ai_bubble.dart';
import 'package:medcases/models/chat_message.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';
import 'package:medcases/services/ai_session_exchange_hydrator.dart';

void main() {
  for (final width in [320.0, 375.0, 768.0, 1200.0]) {
    for (final dark in [true, false]) {
      for (final locale in ['pt', 'es']) {
        testWidgets('shared footer $width dark=$dark $locale', (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 700));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final semantics = tester.ensureSemantics();
          try {
            var copies = 0, plays = 0;
            var expanded = false;
            final created = DateTime(2026, 10, 20, 12, 34);
            await tester.pumpWidget(MaterialApp(
                home: Scaffold(
              body: StatefulBuilder(
                  builder: (context, update) => Padding(
                        padding: const EdgeInsets.all(12),
                        child: ClinicalResponseFooter(
                          dark: dark,
                          lang: locale,
                          createdAt: created,
                          references: const [
                            '- [Source](https://example.org/ref)',
                            '- [Source](https://example.org/ref)'
                          ],
                          onToggleFull: () =>
                              update(() => expanded = !expanded),
                          fullExpanded: expanded,
                          onCopy: () => copies++,
                          onTts: () => plays++,
                          ttsReady: true,
                        ),
                      )),
            )));
            expect(find.text('12:34'), findsOneWidget);
            var accessibleButtons = 0;
            void countButtons(SemanticsNode node) {
              if (node.getSemanticsData().flagsCollection.isButton) {
                accessibleButtons++;
              }
              node.visitChildren((child) {
                countButtons(child);
                return true;
              });
            }

            countButtons(tester.binding.renderViews.single.owner!
                .semanticsOwner!.rootSemanticsNode!);
            expect(accessibleButtons, 4,
                reason: 'No nested duplicate accessible actions');

            final ids = [
              'clinical_references_action',
              'guardia_full_response_action',
              'guardia_tts_action',
              'guardia_copy_action'
            ];
            for (final id in ids) {
              expect(find.byKey(ValueKey(id)), findsOneWidget);
              expect(tester.getSize(find.byKey(ValueKey(id))).height,
                  greaterThanOrEqualTo(48));
            }
            final centers = ids
                .map((id) => tester.getCenter(find.byKey(ValueKey(id))).dy)
                .toSet();
            expect(centers, hasLength(1));
            expect(find.byType(MarkdownBody), findsNothing);
            await tester
                .tap(find.byKey(const ValueKey('clinical_references_action')));
            await tester.pumpAndSettle();
            final refs =
                tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data;
            expect(RegExp('https://example.org/ref').allMatches(refs),
                hasLength(1));
            await tester
                .tap(find.byKey(const ValueKey('clinical_references_action')));
            await tester.pumpAndSettle();
            expect(find.byType(MarkdownBody), findsNothing);
            await tester.tap(
                find.byKey(const ValueKey('guardia_full_response_action')));
            await tester.pump();
            expect(expanded, isTrue);
            await tester.tap(find.byKey(const ValueKey('guardia_tts_action')));
            await tester.tap(find.byKey(const ValueKey('guardia_copy_action')));
            expect(plays, 1);
            expect(copies, 1);
            expect(find.text('📚'), findsNothing);
            await tester.pump(const Duration(minutes: 5));
            expect(find.text('12:34'), findsOneWidget);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        });
      }
    }
  }

  test(
      'sources stay only behind references; clinical wording and later sections remain',
      () {
    for (final heading in [
      '## Fontes técnicas',
      '**Fuentes**',
      '📚 Referências'
    ]) {
      final source =
          'Dose 0,5 mg VO; somente na condição documentada. [R1]\n\n$heading\n\n- [R1 · Fonte técnica](https://example.org/source)\n\n## Monitorização\n\nManter a condição original.';
      final projected = CollapsibleReferencesBlock.project(source);
      expect(projected.$1,
          contains('Dose 0,5 mg VO; somente na condição documentada.'));
      expect(projected.$1, contains('Manter a condição original.'));
      expect(projected.$1, isNot(contains('https://')));
      expect(projected.$1, isNot(contains('Fonte técnica')));
      expect(projected.$1, isNot(contains('[R1]')));
      expect(projected.$2.join(), contains('https://example.org/source'));
    }
  });

  test(
      'standalone and inline links move without deleting meaningful linked text',
      () {
    final source =
        'Verificar [condição documentada](https://example.org/a). ([Fonte técnica](https://example.org/inline))\n\n[Fonte técnica](https://example.org/b)\n\nFonte técnica: documento original';
    final projected = CollapsibleReferencesBlock.project(source);
    expect(projected.$1, contains('Verificar condição documentada.'));
    expect(projected.$1, isNot(contains('Fonte técnica')));
    expect(projected.$1, isNot(contains('https://')));
    expect(projected.$1, isNot(contains('documento original')));
    expect(projected.$2, hasLength(4));
  });

  testWidgets('related clinical references use the same closed source button',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ClinicalResponseFooter(
      dark: false,
      lang: 'es',
      relatedReferences: const ['Documento relacionado original'],
      onCopy: () {},
    ))));
    expect(find.byKey(const ValueKey('clinical_references_action')),
        findsOneWidget);
    expect(find.byType(MarkdownBody), findsNothing);
    await tester.tap(find.byKey(const ValueKey('clinical_references_action')));
    await tester.pumpAndSettle();
    final panel = tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data;
    expect(panel, contains('Referencia clínica'));
    expect(panel, contains('Documento relacionado original'));
    expect(tester.takeException(), isNull);
  });

  test('unmapped clinical bracket code is not silently erased as a citation',
      () {
    final projected = CollapsibleReferencesBlock.project(
        'Classificação [R1]; manter o qualificador.');
    expect(projected.$1, contains('[R1]'));
    expect(projected.$2, isEmpty);
  });

  test('reference heading compatibility does not expose legacy emoji controls',
      () {
    expect(
        GuardiaClinicalResponseView.hasReferenceSection(
            '## Referências\nsource'),
        isTrue);
    expect(
        GuardiaClinicalResponseView.hasReferenceSection(
            '📚 Referencias\nsource'),
        isTrue);
  });

  testWidgets('large accessible text keeps all actions at 320 pixels',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: Scaffold(
          body: ClinicalResponseFooter(
        dark: false,
        createdAt: DateTime(2026, 10, 20, 12, 34),
        references: const ['https://example.org'],
        onToggleFull: () {},
        onTts: () {},
        ttsReady: true,
        onCopy: () {},
      )),
    )));
    expect(find.byType(TextButton), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Study streaming does not expose final actions prematurely',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AiBubble(
      text: 'Texto parcial recebido.',
      dark: false,
      studyMode: true,
      isStreaming: true,
      onCopy: () {},
    ))));
    expect(find.byType(ClinicalResponseFooter), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Study uses same footer without fictitious expansion or time',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AiBubble(
      text:
          '## Estudo\n\nExplicação preservada.\n\n## Referências\n\n- [Fonte](https://example.org/study)',
      dark: false,
      studyMode: true,
      onCopy: () {},
    ))));
    await tester.pumpAndSettle();
    expect(find.byType(ClinicalResponseFooter), findsOneWidget);
    expect(find.byKey(const ValueKey('clinical_references_action')),
        findsOneWidget);
    final before = tester
        .widgetList<MarkdownBody>(find.byType(MarkdownBody))
        .map((w) => w.data)
        .join();
    expect(before, isNot(contains('https://example.org/study')));
    await tester.tap(find.byKey(const ValueKey('clinical_references_action')));
    await tester.pumpAndSettle();
    final after = tester
        .widgetList<MarkdownBody>(find.byType(MarkdownBody))
        .map((w) => w.data)
        .join();
    expect(RegExp('https://example.org/study').allMatches(after), hasLength(1));

    expect(find.byKey(const ValueKey('guardia_full_response_action')),
        findsNothing);
    expect(find.text('—'), findsOneWidget);
    expect(find.byKey(const ValueKey('guardia_copy_action')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('saved exchange timestamp is preserved; unknown time is never now', () {
    final saved =
        AiSessionExchangeHydrator.hydrate(sessionId: 'LOCAL', exchanges: [
      {
        'requestId': 'LOCAL',
        'userInput': 'x',
        'assistantOutput': 'y',
        'createdAt': '2026-10-20T12:34:00Z'
      },
    ]).single;
    expect(saved.createdAt, DateTime.utc(2026, 10, 20, 12, 34));
    final message = ChatMessage.withId(
        id: saved.assistantMessageId,
        role: 'ai',
        text: saved.assistantText,
        createdAt: saved.createdAt);
    expect(message.copyWith(text: 'same response').createdAt, saved.createdAt);
    expect(ChatMessage.withId(id: 'unknown', role: 'ai', text: 'x').createdAt,
        isNull);
    expect(ChatMessage.parseTimestamp('invalid'), isNull);
    final original = DateTime.utc(2026, 10, 20, 12, 34);
    expect(
        ChatMessage.timeFromLegacyId('ai_${original.microsecondsSinceEpoch}'),
        original);
  });
}
