import 'dart:io';
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:medcases/models/canonical_clinical_snapshot.dart';
import 'package:medcases/models/plantao_presentation_contract.dart';
import 'package:medcases/services/ai_session_exchange_hydrator.dart';
import '../fixtures/r15_ux_fixtures.dart';
import '../fixtures/r15_drug_reference_snapshots.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';

void main() {
  testWidgets('preserved reference keeps copy and audio actions',
      (tester) async {
    var copies = 0;
    var listens = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: GuardiaClinicalResponseView(
                rawText: '# Protocolo\n\nTexto integral autorizado.',
                preserveReferenceText: true,
                dark: false,
                languageCode: 'pt',
                onCopy: () => copies++,
                onTts: () => listens++,
                ttsReady: true))));
    expect(find.byKey(const ValueKey('guardia_copy_action')), findsOneWidget);
    expect(find.byKey(const ValueKey('guardia_tts_action')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('guardia_copy_action')));
    await tester.tap(find.byKey(const ValueKey('guardia_tts_action')));
    expect(copies, 1);
    expect(listens, 1);
  });
  String body(WidgetTester tester) => tester
      .widgetList<MarkdownBody>(find.byType(MarkdownBody))
      .map((w) => w.data)
      .join('\n');
  Future<void> show(WidgetTester tester, CanonicalClinicalSnapshot? snapshot,
      String full, String locale,
      {bool preserved = true}) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: GuardiaClinicalResponseView(
                    key: ValueKey('$locale-${snapshot?.factsHash}-$full'),
                    rawText: full,
                    referenceDocument: snapshot,
                    preserveReferenceText: preserved,
                    dark: false,
                    languageCode: locale,
                    onCopy: () {},
                    onTts: () {},
                    ttsReady: true)))));
    await tester.pumpAndSettle();
  }

  for (final locale in ['pt', 'es']) {
    testWidgets(
        'verified executive four blocks, conditional doses and full toggle $locale',
        (tester) async {
      final snapshot = r15ProtocolSnapshot(locale);
      final full = snapshot.blocks(locale).join();
      await show(tester, snapshot, full, locale);
      expect(body(tester), isNot(contains('FULL_SENTINEL')));
      expect(RegExp(r'^## ', multiLine: true).allMatches(body(tester)),
          hasLength(4));
      expect(body(tester), contains('TEST_CONDITION'));
      expect(body(tester), contains('TEST_LIMIT'));
      expect(body(tester), contains('TEST_DURATION'));
      final alternative = body(tester).indexOf(locale == 'pt'
          ? '## Tratamento farmacológico alternativo'
          : '## Tratamiento farmacológico alternativo');
      expect(body(tester).indexOf('FIXTURE_ASSOCIATED'), lessThan(alternative));
      expect(body(tester).indexOf('FIXTURE_ALTERNATIVE'),
          greaterThan(alternative));
      expect(body(tester), isNot(contains('example.org')));
      final expand = find.byKey(const ValueKey('guardia_full_response_action'));
      expect(expand, findsOneWidget);
      await tester.ensureVisible(expand);
      await tester.tap(expand);
      await tester.pumpAndSettle();
      expect(body(tester), contains('FULL_SENTINEL'));
      expect(body(tester), isNot(contains('FIXTURE_MAIN')));
      await tester.ensureVisible(expand);
      await tester.tap(expand);
      await tester.pumpAndSettle();
      expect(body(tester), contains('FIXTURE_MAIN'));
      expect(tester.takeException(), isNull);
    });
    testWidgets(
        'FULL is immediate, references collapsed, one accessible footer $locale',
        (tester) async {
      final snapshot = r15ProtocolSnapshot(locale, executive: false);
      await show(tester, snapshot, snapshot.blocks(locale).join(), locale);
      expect(body(tester), contains('FULL_SENTINEL'));
      expect(find.byKey(const ValueKey('guardia_full_response_action')),
          findsNothing);
      expect(find.byKey(const ValueKey('guardia_copy_action')), findsOneWidget);
      expect(find.byKey(const ValueKey('guardia_tts_action')), findsOneWidget);
      expect(body(tester), isNot(contains('example.org')));
      final refs = find.text(locale == 'pt'
          ? 'Referências'
          : 'Referencias');
      expect(refs, findsOneWidget);
      await tester.ensureVisible(refs);
      await tester.tap(refs);
      await tester.pumpAndSettle();
      expect(RegExp('https://example.org/reference').allMatches(body(tester)),
          hasLength(1));
    });
    testWidgets(
        'historic real drug sections retain populations and restore identically $locale',
        (tester) async {
      final raw = r15DrugReferenceSnapshots[locale]!;
      final hash = PlantaoPresentationContract.textHash(raw);
      final snapshot = CanonicalClinicalSnapshot.fromDrugReference(raw, hash);
      final full = snapshot.blocks(locale).join();
      await show(tester, snapshot, full, locale);
      final quick = body(tester);
      expect(quick, contains('75 mg/kg'));
      expect(quick, contains('<50 kg'));
      expect(quick, contains('4.000 mg'));
      expect(quick, isNot(contains('## Farmacocinética')));
      final hydrated = AiSessionExchangeHydrator.hydrate(
          sessionId: 'local-fixture',
          exchanges: [
            {
              'requestId': 'fixture-$locale',
              'userInput': 'Paracetamol',
              'mode': 'plantao',
              'locale': locale,
              'provenance': 'CANONICAL_DRUG_INFORMATION_NOT_PRESCRIPTION',
              'assistantOutput': full,
              'drugReference': {'documentJson': raw, 'payloadSha256': hash}
            }
          ]).single;
      expect(hydrated.referenceDocument, isNotNull);
      expect(hydrated.assistantText, full);
      await show(
          tester, hydrated.referenceDocument, hydrated.assistantText, locale);
      expect(body(tester), quick);
    });
    testWidgets('corrupt executive fails back to integral $locale',
        (tester) async {
      final source = r15ProtocolFixture(locale);
      (source['presentationEnvelope']['presentation']['medications'][0]
          as Map)['dose'] = '999';
      final snapshot = CanonicalClinicalSnapshot.fromApprovedProtocol(
          source, source['payloadSha256']);
      await show(tester, snapshot, snapshot.blocks(locale).join(), locale);
      expect(body(tester), contains('FULL_SENTINEL'));
      expect(body(tester), isNot(contains('999')));
    });
  }
  test('corrupt saved drug attachment grants no projection authority', () {
    final raw = r15DrugReferenceSnapshots['pt']!;
    final snapshot = CanonicalClinicalSnapshot.fromDrugReference(
        raw, PlantaoPresentationContract.textHash(raw));
    final full = snapshot.blocks('pt').join();
    final hydrated =
        AiSessionExchangeHydrator.hydrate(sessionId: 'local', exchanges: [
      {
        'requestId': 'local',
        'mode': 'plantao',
        'locale': 'pt',
        'provenance': 'CANONICAL_DRUG_INFORMATION_NOT_PRESCRIPTION',
        'assistantOutput': full,
        'drugReference': {
          'documentJson': '$raw ',
          'payloadSha256': PlantaoPresentationContract.textHash(raw)
        }
      }
    ]).single;
    expect(hydrated.referenceDocument, isNull);
    expect(hydrated.assistantText, full);
    final doc = jsonDecode(raw) as Map;
    expect(doc['calculationAuthorized'], isFalse);
  });
  testWidgets('conversational references have one collapsed disclosure',
      (tester) async {
    await show(
        tester,
        null,
        '# Tema\n\n## Conduta imediata\n\nAção técnica.\n\n## Referências\n\n- [Fonte](https://example.org/source)\n- [Outro rótulo](https://example.org/source)',
        'pt',
        preserved: false);
    expect(find.text('Referências'), findsOneWidget);
    expect(body(tester), isNot(contains('example.org/source')));
    final refs = find.text('Referências');
    await tester.ensureVisible(refs);
    await tester.tap(refs);
    await tester.pumpAndSettle();
    expect(RegExp('https://example.org/source').allMatches(body(tester)),
        hasLength(1));
  });
  testWidgets('mismatched reference cannot replace the displayed full text',
      (tester) async {
    final raw = r15DrugReferenceSnapshots['pt']!;
    final source = CanonicalClinicalSnapshot.fromDrugReference(
        raw, PlantaoPresentationContract.textHash(raw));
    await show(tester, source, '# Outra resposta\n\nFULL_ORIGINAL', 'pt');
    expect(body(tester), contains('FULL_ORIGINAL'));
    expect(body(tester), isNot(contains('75 mg/kg')));
    expect(find.byKey(const ValueKey('guardia_full_response_action')),
        findsNothing);
  });
  final namedDocuments = jsonDecode(
      File('test/fixtures/r15_named_drug_documents.json')
          .readAsStringSync()) as Map;
  for (final entry in namedDocuments.entries) {
    testWidgets(
        'source-specific populations and safety stay intact: ${entry.key}',
        (tester) async {
      final raw = entry.value['documentJson'] as String;
      final reference = CanonicalClinicalSnapshot.fromDrugReference(
          raw, entry.value['payloadSha256']);
      final document = jsonDecode(raw) as Map;
      final locale = document['language'] as String;
      final source = jsonDecode(document['sourceJson']) as Map;
      await show(tester, reference, reference.blocks(locale).join(), locale);
      expect(find.byKey(const ValueKey('guardia_full_response_action')),
          findsOneWidget);
      for (final field in [
        'dose',
        'renalDose',
        'hepaticDose',
        'pediatricDose',
        'contraindications',
        'interactions',
        'monitoring'
      ]) {
        final text = source[locale][field];
        if (text is String && text.isNotEmpty) {
          expect(body(tester), contains(text), reason: field);
        }
      }
      expect(body(tester), isNot(contains('clinicalContentSha256')));
    });
  }
}
