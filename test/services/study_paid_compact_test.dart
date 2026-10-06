import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/study/study_paid_canonical_response.dart';
import 'package:medcases/services/study/study_reference_boundary.dart';
import 'package:medcases/services/ai/safety/clinical_dose_scope.dart';

Map<String, dynamic> fixture() => {
      'clinical': [
        {
          'id': 'f1',
          's': 'treatment',
          'c': 'synthetic_treatment',
          'a': 'consider',
          'p': 'conditional',
          'when': ['f1_c'],
          'items': [
            {'id': 'f1_c', 'k': 'condition', 'c': 'if_indicated'},
            {'id': 'f1_a', 'k': 'action', 'c': 'synthetic_agent'},
            {
              'id': 'f1_q',
              'k': 'quantity',
              'n': 500,
              'hi': null,
              'op': '',
              'u': 'mg'
            },
            {'id': 'f1_r', 'k': 'route', 'v': 'VO'},
            {
              'id': 'f1_i',
              'k': 'frequency',
              'n': 24,
              'hi': null,
              'op': '',
              'u': 'h'
            },
            {'id': 'f1_m', 'k': 'monitoring', 'c': 'monitor_response'}
          ]
        }
      ],
      'presentation': {
        'title': 'Caso sintético',
        'labels': [
          {'id': 'f1_c', 'text': 'Si está indicado:'},
          {'id': 'f1_a', 'text': 'Agente de prueba'},
          {'id': 'f1_m', 'text': 'y monitorizar la respuesta.'}
        ]
      },
      'complete': true
    };
void main() {
  StudyPaidSnapshot parse(Map data, {String finish = 'STOP'}) =>
      StudyPaidCanonicalResponse.decode(jsonEncode(data),
          language: 'es',
          finishReason: finish,
          references: StudyReferenceBoundary());
  test('one locale renders full bindings without fabricating another language',
      () {
    final s = parse(fixture());
    expect(s.text.contains('500 mg VO c/24 h'), true);
    expect(s.snapshot.audit('es')['quantityCount'], 2);
    expect(() => s.snapshot.blocks('pt'), throwsFormatException);
    expect(s.text.contains('STUDY_CANONICAL_CTA::'), true);
  });
  test('translation attaches only labels to the SAME clinical snapshot', () {
    final s = parse(fixture());
    final translation = {
      'title': 'Caso sintético',
      'labels': [
        {'id': 'f1_c', 'text': 'Se indicado:'},
        {'id': 'f1_a', 'text': 'Agente de teste'},
        {'id': 'f1_m', 'text': 'e monitorizar a resposta.'}
      ]
    };
    final pair =
        s.withLocalization(jsonEncode(translation), finishReason: 'STOP');
    final es = pair.audit('es'), pt = pair.audit('pt');
    for (final key in [
      'factHash',
      'quantityHash',
      'orderHash',
      'referenceHash',
      'ctaId'
    ]) {
      expect(pt[key], es[key]);
      expect(es[key], s.snapshot.audit('es')[key]);
    }
    expect(pair.blocks('pt').join().contains('500 mg VO c/24 h'), true);
  });
  for (final reason in ['MAX_TOKENS', 'SAFETY', '', 'OTHER']) {
    test(
        '$reason is not a successful answer',
        () => expect(
            () => parse(fixture(), finish: reason), throwsFormatException));
  }
  test(
      'missing completion, missing binding, duplicate label and unbound dose fail',
      () {
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (d) => d['complete'] = false,
      (d) => (d['presentation']['labels'] as List).removeLast(),
      (d) => (d['presentation']['labels'] as List)
          .add(d['presentation']['labels'][0]),
      (d) => d['presentation']['labels'][0]['text'] = '500 mg',
      (d) =>
          d['presentation']['labels'][0]['text'] = 'https://fabricated.invalid',
      (d) => d['clinical'][0]['when'] = ['missing'],
      (d) => d['clinical'][0]['items'][2]['hi'] = 1,
      (d) => d['clinical'][0]['items'][3]['v'] = 'unknown'
    ]) {
      final d = fixture();
      mutate(d);
      expect(() => parse(d), throwsFormatException);
    }
  });
  test(
      'translation cannot add or remove IDs, doses, clinical fields or references',
      () {
    final s = parse(fixture());
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (d) => (d['labels'] as List).removeLast(),
      (d) => d['labels'][0]['text'] = '100 mg',
      (d) => d['clinical'] = [],
      (d) => d['labels'][0]['text'] = 'PMID: 12345'
    ]) {
      final d = Map<String, dynamic>.from(fixture()['presentation']);
      mutate(d);
      expect(() => s.withLocalization(jsonEncode(d), finishReason: 'STOP'),
          throwsFormatException);
    }
  });
  test('references originate outside provider wire and remain identical', () {
    final s = StudyPaidCanonicalResponse.decode(jsonEncode(fixture()),
        language: 'es',
        finishReason: 'STOP',
        references:
            StudyReferenceBoundary(['Verified synthetic catalog record']));
    expect(
        s.snapshot
            .blocks('es')
            .join()
            .contains('Verified synthetic catalog record'),
        true);
  });
  test('NaN/Infinity validation stays bounded and recombinant remains allowed',
      () {
    expect(ClinicalDoseScope.hasInvalidReferenceValue('NaN mg'), true);
    expect(ClinicalDoseScope.hasInvalidReferenceValue('Infinity mg'), true);
    expect(ClinicalDoseScope.hasInvalidReferenceValue('recombinante'), false);
  });
  test('compact prompt is single-locale and includes original policy once', () {
    final p = StudyPaidCanonicalResponse.prompt('unique clinical policy', 'es');
    expect('unique clinical policy'.allMatches(p).length, 1);
    expect(p.startsWith(StudyPaidCanonicalResponse.marker), true);
    expect(StudyPaidCanonicalResponse.maxOutputTokens, lessThan(32768));
  });
}
