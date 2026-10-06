import 'package:medcases/services/ai/safety/clinical_dose_scope.dart';
import 'package:medcases/services/study_continuation_resolver.dart';
import 'package:medcases/services/study/study_canonical_continuation.dart';
import 'study_global_validation_regression_test.dart' show finalizeStudyFixture;
import 'package:medcases/services/study/study_canonical_schema.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/study_clinical_snapshot.dart';
import 'package:medcases/services/gemini_service_v2.dart';
import 'package:medcases/services/study/study_canonical_response.dart';
import 'package:medcases/services/study/study_reference_boundary.dart';

// Synthetic notation exercises binding; it is not a clinical regimen.
List<Map<String, dynamic>> records() => [
      {
        'type': 'title',
        'id': 'topic',
        'localization': {'pt': 'Exemplo sintético', 'es': 'Ejemplo sintético'}
      },
      {
        'type': 'fact',
        'id': 'f_one',
        'clinical': {
          'section': 'doses',
          'conceptId': 'synthetic_example',
          'actionId': 'explain',
          'polarity': 'conditional',
          'conditionIds': ['f_one_condition'],
          'items': [
            {
              'id': 'f_one_condition',
              'kind': 'condition',
              'code': 'synthetic_only'
            },
            {
              'id': 'f_one_action',
              'kind': 'action',
              'code': 'describe_notation'
            },
            {'id': 'f_one_q', 'kind': 'quantity', 'value': '2.5–5 mg/kg'},
            {'id': 'f_one_route', 'kind': 'route', 'value': 'IV'},
            {'id': 'f_one_frequency', 'kind': 'frequency', 'value': 'c/24 h'},
            {'id': 'f_one_end', 'kind': 'relation', 'code': 'not_a_regimen'},
          ]
        },
        'localization': {
          'f_one_condition': {'pt': 'Neste teste,', 'es': 'En esta prueba,'},
          'f_one_action': {'pt': 'a notação é', 'es': 'la notación es'},
          'f_one_end': {
            'pt': '; não é uma prescrição.',
            'es': '; no es una prescripción.'
          },
        }
      },
      {
        'type': 'fact',
        'id': 'f_two',
        'clinical': {
          'section': 'monitoring',
          'conceptId': 'synthetic_monitoring',
          'actionId': 'monitor',
          'polarity': 'positive',
          'conditionIds': [],
          'items': [
            {
              'id': 'f_two_monitor',
              'kind': 'monitoring',
              'code': 'check_example'
            },
          ]
        },
        'localization': {
          'f_two_monitor': {
            'pt': 'Verificar o exemplo.',
            'es': 'Verificar el ejemplo.'
          },
        }
      },
      {'type': 'end'},
    ];
String wire(List<Map<String, dynamic>> r) => r.map(jsonEncode).join('\n');

void main() {
  test('paid backend and primary gateway use the identical canonical schema',
      () {
    final backend = jsonDecode(
        File('functions/lib/study_canonical_schema_v1.json')
            .readAsStringSync());
    expect(backend, StudyCanonicalSchema.schema);
    expect(jsonDecode(File('server/study_canonical_schema_v1.json').readAsStringSync()), backend);
  });

  test('Study numeric sentinel is a token, not part of a scientific word', () {
    expect(ClinicalDoseScope.hasInvalidReferenceValue('recombinante'), false);
    for (final value in [
      'NaN mg',
      'Infinity mg',
      '0 mg',
      '-1 mg',
      'inventado'
    ]) {
      expect(ClinicalDoseScope.hasInvalidReferenceValue(value), true,
          reason: value);
    }
    for (final value in ['0.9 mg', '1.0 mg', '1-2 mg']) {
      expect(ClinicalDoseScope.hasInvalidReferenceValue(value), false,
          reason: value);
    }
  });

  test('scientific semantic code preserves case while binding IDs stay strict',
      () {
    final input = records();
    input[1]['clinical']['items'][0]['code'] = 'mmHg';
    final snapshot = StudyClinicalSnapshot.fromRecords(input);
    expect(snapshot.audit('pt'), snapshot.audit('es'));
    input[1]['clinical']['items'][0]['id'] = 'Not_a_binding';
    expect(
        () => StudyClinicalSnapshot.fromRecords(input), throwsFormatException);
  });

  test('schema approximation operator is a shared quantity in both views', () {
    final input = records();
    input[1]['clinical']['items'][2]['value'] = '~2.5 mg';
    final snapshot = StudyClinicalSnapshot.fromRecords(input);
    expect(snapshot.blocks('pt').join(), contains('~2.5 mg'));
    expect(snapshot.blocks('es').join(), contains('~2.5 mg'));
  });

  test('active continuation resolves the same ID after finalization in PT/ES',
      () async {
    final snapshot = StudyClinicalSnapshot.fromRecords(records());
    final id = snapshot.audit('pt')['ctaId'] as String;
    for (final language in ['pt', 'es']) {
      final text = snapshot.blocks(language, includeContinuation: true).join();
      final finalized = await finalizeStudyFixture(text, language);
      final action = StudyContinuationResolver.resolve(
          rawText: finalized,
          isStudyMode: true,
          isSafeCard: false,
          isStreaming: false,
          lastUserMessage: 'synthetic',
          languageCode: language);
      expect(action.label,
          StudyCanonicalContinuation.choices[id]![language == 'es' ? 1 : 0]);
      expect(action.question,
          StudyCanonicalContinuation.choices[id]![language == 'es' ? 3 : 2]);
      expect(action.displayText,
          isNot(contains(StudyCanonicalContinuation.prefix)));
      final streaming = StudyContinuationResolver.resolve(
          rawText: finalized,
          isStudyMode: true,
          isSafeCard: false,
          isStreaming: true,
          lastUserMessage: 'synthetic',
          languageCode: language);
      expect(streaming.hasContinuation, false);
      expect(streaming.displayText,
          isNot(contains(StudyCanonicalContinuation.prefix)));
    }
  });

  test(
      'canonical CTA progression uses prior IDs, independent of wording/language',
      () {
    final metadata = StudyCanonicalContinuation.metadata('pathophysiology');
    final prompt = StudyCanonicalContinuation.prefix + 'pathophysiology';
    final pt = StudyCanonicalContinuation.resolve(prompt, 'pt', [metadata])!;
    final es = StudyCanonicalContinuation.resolve(prompt, 'es', [metadata])!;
    expect(pt.id, es.id);
    expect(pt.id, 'differential');
    expect(
        StudyCanonicalContinuation.resolve(
                prompt,
                'pt',
                StudyCanonicalContinuation.choices.keys
                    .map(StudyCanonicalContinuation.metadata))!
            .id,
        isEmpty);
  });

  test(
      'native schema selection is explicit and isolated from plain Study/Plantão',
      () {
    expect(
        StudyCanonicalSchema.applies(StudyCanonicalResponse.prompt('policy')),
        true);
    expect(StudyCanonicalSchema.applies('plain Study policy'), false);
    expect(StudyCanonicalSchema.applies('Plantão policy'), false);
    expect(StudyCanonicalSchema.generationConfig['responseMimeType'],
        'application/json');
  });
  test('native array binds localizations inside their own canonical item IDs',
      () {
    final input = (jsonDecode(jsonEncode(records())) as List)
        .cast<Map<String, dynamic>>();
    for (final record in input.where((r) => r['type'] == 'fact')) {
      final labels = record.remove('localization') as Map;
      for (final item in record['clinical']['items'] as List) {
        if (labels.containsKey(item['id']))
          item['localization'] = labels[item['id']];
      }
    }
    final decoder = StudyCanonicalDecoder('es');
    final rendered = decoder.add(jsonEncode(input));
    decoder.finish();
    expect(decoder.snapshot(), isNotNull);
    expect(rendered,
        StudyClinicalSnapshot.fromRecords(records()).blocks('es').join());
  });

  test('one immutable snapshot resolves every item by ID in both languages',
      () {
    final input = records();
    final snapshot = StudyClinicalSnapshot.fromRecords(input,
        verifiedReferences: ['Synthetic source record']);
    expect(snapshot.audit('pt'), snapshot.audit('es'));
    expect(snapshot.audit('pt')['quantityCount'], 2);
    expect(snapshot.audit('es')['droppedFacts'], 0);
    final before = snapshot.blocks('pt');
    input[0]['localization'] = {'pt': 'Changed', 'es': 'Changed'};
    expect(snapshot.blocks('pt'), before);
    expect(snapshot.blocks('es').join(), contains('2.5–5 mg/kg IV c/24 h'));
    expect(snapshot.blocks('pt').join(), contains('não é uma prescrição'));
  });

  test('localization map order and wording cannot change binding or quantities',
      () {
    final input = records();
    final before = StudyClinicalSnapshot.fromRecords(input);
    final labels = input[1]['localization'] as Map<String, dynamic>;
    input[1]['localization'] =
        Map.fromEntries(labels.entries.toList().reversed);
    final after = StudyClinicalSnapshot.fromRecords(input);
    expect(after.blocks('es'), before.blocks('es'));
    expect(after.audit('pt'), before.audit('pt'));
  });

  for (final defect in [
    'missing_es',
    'quantity_in_label',
    'wrong_id',
    'duplicate_id',
    'missing_condition',
    'extra_label',
    'missing_end'
  ]) {
    test('parity gate rejects $defect without guessing a binding', () {
      final input = records();
      final labels = input[1]['localization'] as Map;
      final items = input[1]['clinical']['items'] as List;
      switch (defect) {
        case 'missing_es':
          (labels['f_one_action'] as Map).remove('es');
        case 'quantity_in_label':
          labels['f_one_action']['pt'] = 'dose 99 mg';
        case 'wrong_id':
          labels['unbound'] = labels.remove('f_one_action');
        case 'duplicate_id':
          items[1]['id'] = items[0]['id'];
        case 'missing_condition':
          input[1]['clinical']['conditionIds'] = ['missing'];
        case 'extra_label':
          labels['ghost'] = {'pt': 'Texto', 'es': 'Texto'};
        case 'missing_end':
          input.removeLast();
      }
      expect(() => StudyClinicalSnapshot.fromRecords(input),
          throwsFormatException);
    });
  }

  test('a returning section preserves chronological block order in both views',
      () {
    final input = records();
    final again = jsonDecode(jsonEncode(input[2])) as Map<String, dynamic>;
    again['id'] = 'f_three';
    again['clinical']['section'] = 'doses';
    again['clinical']['items'][0]['id'] = 'f_three_monitor';
    again['localization'] = {
      'f_three_monitor': again['localization']['f_two_monitor']
    };
    input.insert(3, again);
    final snapshot = StudyClinicalSnapshot.fromRecords(input);
    expect(snapshot.audit('pt'), snapshot.audit('es'));
    expect(snapshot.audit('pt')['factCount'], 3);
    for (final lang in ['pt', 'es']) {
      final decoder = StudyCanonicalDecoder(lang);
      final shown = decoder.add(wire(input));
      decoder.finish();
      expect(shown, snapshot.blocks(lang).join());
      expect(decoder.snapshot(), isNotNull);
    }
  });

  test('every SSE split produces the same final blocks without JSON', () {
    final text = wire(records());
    final expected =
        StudyClinicalSnapshot.fromRecords(records()).blocks('es').join();
    for (final width in [1, 2, 7, 31, 256, text.length]) {
      final decoder = StudyCanonicalDecoder('es');
      final parts = <String>[];
      for (var i = 0; i < text.length; i += width) {
        parts.add(
            decoder.add(text.substring(i, (i + width).clamp(0, text.length))));
      }
      parts.add(decoder.finish());
      expect(parts.join(), expected, reason: 'split width $width');
      expect(decoder.issues, isEmpty);
      expect(decoder.snapshot(), isNotNull);
      expect(parts.join(), isNot(contains('"clinical"')));
    }
  });

  test('escaped braces and pretty JSON do not corrupt the object frame', () {
    final input = records();
    input[2]['localization']['f_two_monitor'] = {
      'pt': 'Verificar "{exemplo}".',
      'es': 'Verificar "{ejemplo}".'
    };
    final decoder = StudyCanonicalDecoder('es');
    final text = decoder
        .add(input.map(const JsonEncoder.withIndent('  ').convert).join('\n'));
    decoder.finish();
    expect(decoder.snapshot(), isNotNull);
    expect(text, contains('"{ejemplo}"'));
  });

  test(
      'broken translation isolates its fact and preserves remaining bound answer',
      () {
    final input = records();
    (input[1]['localization']['f_one_action'] as Map).remove('es');
    final decoder = StudyCanonicalDecoder('es');
    final text = decoder.add(wire(input));
    decoder.finish();
    expect(decoder.snapshot(), isNull);
    expect(decoder.issues, isNotEmpty);
    expect(text, isNot(contains('2.5–5 mg/kg IV c/24 h')));
    expect(decoder.presentationSnapshot(), isNotNull);
    final pt = decoder.presentationSnapshot()!.audit('pt');
    final es = decoder.presentationSnapshot()!.audit('es');
    expect(pt['factHash'], es['factHash']);
    expect(pt['quantityHash'], es['quantityHash']);
    expect(text, contains('Verificar el ejemplo'));
    expect(text, isNot(contains('validação clínica')));
  });

  test('plaintext provider fallback remains the existing educational answer',
      () {
    final decoder = StudyCanonicalDecoder('pt');
    const text = 'Texto educativo preservado.\n\nSem bloqueio global.';
    expect(decoder.add(text) + decoder.finish(), text);
    expect(decoder.snapshot(), isNull);
    expect(decoder.issues, ['plaintext_fallback']);
  });

  test('incomplete fact is never shown as JSON or accepted as complete', () {
    final decoder = StudyCanonicalDecoder('pt');
    final first = decoder.add(wire(records().take(2).toList()));
    expect(first, contains('2.5–5'));
    expect(decoder.add('{"type":"fact","id":"f_cut'), isEmpty);
    decoder.finish();
    expect(decoder.snapshot(), isNull);
    expect(decoder.issues, contains('incomplete_record'));
  });

  test('progressive canonical blocks are visible before terminal and immutable',
      () async {
    final source = StreamController<GeminiChunk>();
    final chunks = <GeminiChunk>[];
    final done = StudyCanonicalResponse.localize(source.stream,
            language: 'es', references: StudyReferenceBoundary())
        .listen(chunks.add)
        .asFuture<void>();
    source.add(GeminiChunk(text: wire(records().take(2).toList())));
    await Future<void>.delayed(Duration.zero);
    final first = chunks.map((c) => c.text).join();
    expect(first, contains('2.5–5'));
    expect(chunks.any((c) => c.isDone), false);
    source.add(GeminiChunk(
        text: wire(records().skip(2).toList()),
        isDone: true,
        finishReason: 'STOP'));
    await source.close();
    await done;
    expect(chunks.map((c) => c.text).join().startsWith(first), true);
    expect(chunks.last.studySnapshot, isNotNull);
    expect(chunks.last.studyCanonicalIssues, isEmpty);
    expect(chunks.last.text, isEmpty);
  });

  test('references are only externally verified and identical in both views',
      () async {
    final refs = StudyReferenceBoundary(['Catalog record']);
    final chunks = await StudyCanonicalResponse.localize(
            Stream.value(GeminiChunk(
                text: wire(records()),
                isDone: true,
                finishReason: 'STOP',
                groundedSources: [
                  (
                    title: 'Grounded source',
                    url: 'https://example.org/real-transport'
                  ),
                  (title: 'Invalid', url: 'javascript:bad'),
                ])),
            language: 'pt',
            references: refs)
        .toList();
    final snapshot = chunks.last.studySnapshot!;
    expect(snapshot.audit('pt')['referenceHash'],
        snapshot.audit('es')['referenceHash']);
    expect(refs.records, hasLength(2));
    expect(snapshot.blocks('es').join(),
        contains('https://example.org/real-transport'));
  });

  test(
      'active adapters are scoped to Study chat, never utility JSON or Plantão',
      () {
    final gateway =
        File('lib/services/ai_gateway_service.dart').readAsStringSync();
    final router =
        File('lib/services/provider_router_service.dart').readAsStringSync();
    expect(
        gateway,
        contains(
            'longResponse && clinicalContext?.verifiesStudyReferences == true'));
    expect(gateway, contains('StudyCanonicalResponse.localize(transport'));
    expect(
        router,
        contains(
            '!isPlantao && clinicalContext?.verifiesStudyReferences == true'));
    expect(
        router, contains('StudyPaidCanonicalResponse.decode(wireText'));
  });
}
