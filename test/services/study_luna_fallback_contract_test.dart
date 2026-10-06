import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/study_clinical_snapshot.dart';
import 'package:medcases/services/study/study_canonical_response.dart';
import 'package:medcases/services/study/study_luna_fallback_contract.dart';
import 'package:medcases/services/study/study_quantity_retention.dart';
import 'package:medcases/services/study/study_reference_boundary.dart';

Map<String, dynamic> response() => {
      'model': StudyLunaFallbackContract.model,
      'finishReason': 'STOP',
      'studyCanonicalVersion': StudyClinicalSnapshot.version,
      'coverage': {'complete': true},
      'text': jsonEncode([
        {
          'type': 'title',
          'id': 'topic',
          'localization': {'pt': 'Exemplo sintético', 'es': 'Ejemplo sintético'}
        },
        {
          'type': 'fact',
          'id': 'f1',
          'clinical': {
            'section': 'monitoring',
            'conceptId': 'synthetic_value',
            'actionId': 'monitor',
            'polarity': 'positive',
            'conditionIds': <String>[],
            'items': [
              {
                'id': 'f1a',
                'kind': 'concept',
                'code': 'synthetic',
                'localization': {
                  'pt': 'Valor sintético',
                  'es': 'Valor sintético'
                }
              },
              {
                'id': 'f1q',
                'kind': 'quantity',
                'amount': 30,
                'upper': null,
                'operator': '',
                'unit': 'mL'
              },
              {
                'id': 'f1r',
                'kind': 'relation',
                'code': 'context',
                'localization': {
                  'pt': 'conforme o contexto clínico.',
                  'es': 'según el contexto clínico.'
                }
              }
            ]
          }
        },
        {'type': 'end'}
      ])
    };

void main() {
  test('only Study chat selects Luna; other Gemini consumers stay isolated',
      () {
    for (final mode in ['estudo', 'plantao', 'transcription', 'summary']) {
      for (final chat in [true, false]) {
        expect(StudyLunaFallbackContract.applies(mode: mode, studyChat: chat),
            mode == 'estudo' && chat);
      }
    }
  });
  test('Luna uses the exact primary clinical prompt and canonical version', () {
    final payload = StudyLunaFallbackContract.fields('POLICY_SENTINEL');
    expect(payload['systemPrompt'],
        StudyCanonicalResponse.prompt('POLICY_SENTINEL'));
    expect(payload['studyFallbackModel'], 'gpt-5.6-luna');
    expect(payload['provider'], 'openai');
    expect(payload['maxOutputTokens'], 12288);
    expect(payload['studyCanonicalVersion'], StudyClinicalSnapshot.version);
  });
  test(
      'one native numeric snapshot localizes both languages with all quantities',
      () {
    final wire = response();
    final refs = StudyReferenceBoundary(['SYNTHETIC_PROVENANCE_RECORD']);
    final pt = StudyLunaFallbackContract.decode(wire,
        language: 'pt', references: refs);
    final es = StudyLunaFallbackContract.decode(wire,
        language: 'es', references: refs);
    for (final key in [
      'factHash',
      'quantityHash',
      'orderHash',
      'referenceHash',
      'ctaId'
    ]) {
      expect(pt.snapshot.audit('pt')[key], es.snapshot.audit('es')[key]);
    }
    expect(pt.text, contains('Monitorização'));
    expect(es.text, contains('Monitorización'));
    for (final answer in [pt, es]) {
      StudyQuantityRetention.requirePreserved(answer.snapshot, answer.text);
      expect(answer.text, contains('30 mL'));
      expect(answer.text, contains('SYNTHETIC_PROVENANCE_RECORD'));
    }
  });
  for (final invalid in <Map<String, dynamic>>[
    {'model': 'gpt-4o-mini'},
    {'model': 'gemini-2.5-pro'},
    {'finishReason': 'MAX_TOKENS'},
    {'finishReason': null},
    {'studyCanonicalVersion': 'wrong_version'},
    {'text': 'Plaintext partial without canonical completion'},
    {
      'text':
          '[{"type":"title","id":"topic","localization":{"pt":"Teste","es":"Prueba"}}]'
    },
    {'text': '[{"type":"fact",'},
  ]) {
    test(
        'invalid terminal is technical failure: ${invalid.keys.first} ${invalid.values.first}',
        () {
      expect(
          () => StudyLunaFallbackContract.decode({...response(), ...invalid},
              language: 'pt', references: StudyReferenceBoundary()),
          throwsFormatException);
    });
  }
  for (final coverage in [null, {'complete': false}, {'complete': true}]) {
    test('educational coverage does not authorize a valid answer: $coverage', () {
      final result = StudyLunaFallbackContract.decode({...response(), 'coverage': coverage},
          language: 'es', references: StudyReferenceBoundary());
      expect(result.text, contains('30 mL'));
      expect(result.snapshot.audit('es')['quantityHash'], isNotEmpty);
    });
  }
  test('missing quantity or language binding cannot become a valid terminal',
      () {
    final wire = response();
    final rows = jsonDecode(wire['text'] as String) as List;
    rows[1]['clinical']['items'][0]['localization'].remove('es');
    wire['text'] = jsonEncode(rows);
    expect(
        () => StudyLunaFallbackContract.decode(wire,
            language: 'es', references: StudyReferenceBoundary()),
        throwsFormatException);
  });
  test('productive fallback preserves owner and single-attempt boundaries', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();
    final start = source.indexOf('Future<bool> tryPaidFallback(');
    final end = source.indexOf('// ── M13-R2:', start);
    final fallback = source.substring(start, end);
    expect(fallback, contains('if (studyFallbackStarted) return true;'));
    expect(fallback.indexOf('_activeRequestId != thisRequestId'),
        lessThan(fallback.indexOf('studyFallbackStarted = true')));
    expect(fallback, contains('if (longResponse || _openAiKey.isNotEmpty)'));
    final failure = fallback.substring(
        fallback.indexOf('// A failed canonical fallback'),
        fallback.indexOf('// GPT falhou'));
    expect(failure, contains('wrappedOnError('));
    expect(failure, contains('return true;'));
    expect(failure, isNot(contains('persistAiExchangeOnce')));
    expect(failure, isNot(contains('callPaidProxy')));
    expect(source, contains('final bool shouldUseGptSse = !longResponse;'));
    expect(
        RegExp(r'if \(longResponse && studyFallbackStarted\) return;')
            .allMatches(source),
        hasLength(2));
    expect(source, contains("await tryPaidFallback('study_invalid_terminal')"));
    expect(source,
        contains("unawaited(tryPaidFallback('study_incomplete_stream'))"));
  });
  test('legacy paid entrypoint diverts Study chat before any Gemini transport',
      () {
    final source =
        File('lib/services/provider_router_service.dart').readAsStringSync();
    final part = source.substring(
        source.indexOf('static Future<PaidProxyResult> callPaidProxy('),
        source.indexOf('static Future<PaidProxyResult> callGptProxy('));
    expect(part.indexOf('StudyLunaFallbackContract.applies'),
        lessThan(part.indexOf('String idToken')));
    expect(part, contains('return callGptProxy('));
    expect(
        part,
        contains(
            'studyChat: clinicalContext?.verifiesStudyReferences == true'));
  });
}
