import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/clinical_reference_resolver.dart';

void main() {
  ClinicalReferenceData resolve(
    String userText,
    String aiText, {
    String lang = 'pt',
  }) {
    return ClinicalReferenceResolver.resolve(
      userText: userText,
      aiText: aiText,
      lang: lang,
    );
  }

  String joined(ClinicalReferenceData data) => data.lines.join('\n');

  group('Top200 Expansion Batch22 psychiatry dependence V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String marker,
    })>[
      (
        id: 'PANIC',
        query: 'transtorno do pânico',
        answer: 'TRANSTORNO DO PÂNICO',
        authority: 'NICE',
        marker: 'CG113'
      ),
      (
        id: 'SOC',
        query: 'transtorno de ansiedade social',
        answer: 'ANSIEDADE SOCIAL',
        authority: 'NICE',
        marker: 'CG159'
      ),
      (
        id: 'OCD',
        query: 'transtorno obsessivo-compulsivo',
        answer: 'TOC',
        authority: 'NICE',
        marker: 'CG31'
      ),
      (
        id: 'PTSD',
        query: 'transtorno de estresse pós-traumático',
        answer: 'TEPT',
        authority: 'VA/DoD',
        marker: '2023'
      ),
      (
        id: 'AN',
        query: 'anorexia nervosa',
        answer: 'ANOREXIA NERVOSA',
        authority: 'APA',
        marker: '2023'
      ),
      (
        id: 'BN',
        query: 'bulimia nervosa',
        answer: 'BULIMIA NERVOSA',
        authority: 'APA',
        marker: '2023'
      ),
      (
        id: 'OUD',
        query: 'transtorno por uso de opioides',
        answer: 'OUD',
        authority: 'ASAM',
        marker: 'Opioid Use Disorder'
      ),
      (
        id: 'CUD',
        query: 'transtorno por uso de cannabis',
        answer: 'CANNABIS USE DISORDER',
        authority: 'WHO',
        marker: 'mhGAP'
      ),
      (
        id: 'INS',
        query: 'insônia crônica',
        answer: 'INSÔNIA CRÔNICA',
        authority: 'AASM',
        marker: 'Chronic Insomnia'
      ),
      (
        id: 'BPD',
        query: 'transtorno de personalidade borderline',
        answer: 'BORDERLINE',
        authority: 'NICE',
        marker: 'CG78'
      ),
    ];

    test('10/10 temas resolvem curadoria com 3–4 URLs HTTPS', () {
      expect(cases.length, 10);
      for (final c in cases) {
        final result = resolve(c.query, c.answer);
        final text = joined(result);
        final urls =
            result.lines.where((line) => line.contains('https://')).toList();
        expect(text, contains(c.authority), reason: c.id);
        expect(text, contains(c.marker), reason: c.id);
        expect(urls.length, greaterThanOrEqualTo(3), reason: c.id);
        expect(urls.length, lessThanOrEqualTo(4), reason: c.id);
      }
    });

    test('aliases PT ES EN mantêm identidade temática', () {
      final probes = <({String q, String a, String marker})>[
        (q: 'panic disorder', a: 'PANIC DISORDER', marker: 'CG113'),
        (
          q: 'social anxiety disorder social phobia',
          a: 'SOCIAL ANXIETY DISORDER',
          marker: 'CG159'
        ),
        (q: 'obsessive-compulsive disorder OCD', a: 'OCD', marker: 'CG31'),
        (q: 'post-traumatic stress disorder PTSD', a: 'PTSD', marker: 'VA/DoD'),
        (
          q: 'anorexia nervosa',
          a: 'ANOREXIA NERVOSA',
          marker: 'Eating Disorders'
        ),
        (q: 'bulimia nervosa', a: 'BULIMIA NERVOSA', marker: 'Bulimia Nervosa'),
        (
          q: 'opioid use disorder OUD',
          a: 'OPIOID USE DISORDER',
          marker: 'ASAM'
        ),
        (
          q: 'cannabis use disorder marijuana dependence',
          a: 'CANNABIS USE DISORDER',
          marker: 'mhGAP'
        ),
        (q: 'chronic insomnia disorder', a: 'CHRONIC INSOMNIA', marker: 'AASM'),
        (
          q: 'borderline personality disorder',
          a: 'BORDERLINE PERSONALITY DISORDER',
          marker: 'CG78'
        ),
      ];
      for (final p in probes) {
        final result = resolve(p.q, p.a, lang: 'en');
        expect(joined(result), contains(p.marker), reason: p.q);
        expect(
          result.lines.where((line) => line.contains('https://')).length,
          greaterThanOrEqualTo(3),
          reason: p.q,
        );
      }
    });

    test('precedência específica protege colisões psiquiátricas', () {
      expect(
        joined(resolve(
            'transtorno do pânico com ansiedade', 'TRANSTORNO DO PÂNICO')),
        contains('CG113'),
      );
      expect(
        joined(resolve('ansiedade social com depressão', 'ANSIEDADE SOCIAL')),
        contains('CG159'),
      );
      expect(
        joined(resolve(
            'TOC com ansiedade intensa', 'TRANSTORNO OBSESSIVO-COMPULSIVO')),
        contains('CG31'),
      );
      expect(
        joined(resolve(
            'TEPT após trauma', 'TRANSTORNO DE ESTRESSE PÓS-TRAUMÁTICO')),
        contains('VA/DoD'),
      );
      expect(
        joined(resolve(
            'bulimia nervosa com compulsão alimentar', 'BULIMIA NERVOSA')),
        contains('Bulimia Nervosa'),
      );
      expect(
        joined(resolve(
            'transtorno por uso de opioides com overdose prévia', 'OUD')),
        contains('ASAM'),
      );
      expect(
        joined(resolve(
            'transtorno por uso de cannabis com intoxicação recorrente',
            'CUD')),
        contains('mhGAP'),
      );
      expect(
        joined(resolve('insônia crônica com ansiedade', 'INSÔNIA CRÔNICA')),
        contains('AASM'),
      );

      final bpd = joined(resolve(
        'transtorno de personalidade borderline versus transtorno bipolar',
        'BORDERLINE PERSONALITY DISORDER',
      ));
      expect(bpd, contains('CG78'));
      expect(bpd, isNot(contains('Bipolar Guideline')));
    });

    test('Batch01–22 permanecem curated-only', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      for (var i = 1; i <= 10; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }
      for (var i = 11; i <= 22; i++) {
        expect(source,
            contains('_top200ExpansionBatch${i}Domains.contains(domain)'));
      }

      for (final domain in <String>[
        'panic_disorder_nice_2026',
        'social_anxiety_disorder_nice_2026',
        'obsessive_compulsive_disorder_nice_2026',
        'posttraumatic_stress_disorder_va_dod_2023',
        'anorexia_nervosa_apa_nice_current',
        'bulimia_nervosa_apa_nice_current',
        'opioid_use_disorder_asam_samhsa_current',
        'cannabis_use_disorder_who_samhsa_current',
        'chronic_insomnia_aasm_current',
        'borderline_personality_disorder_nice_current',
      ]) {
        expect(source, contains("case '$domain':"), reason: domain);
      }

      expect(source, contains('limit: 4'));
    });

    test('Plantão e Estudo continuam no mesmo call-site', () {
      final source = File('lib/screens/ai_screen.dart').readAsStringSync();
      expect('ClinicalReferenceResolver.resolve('.allMatches(source).length, 1);
      expect(source, contains('GuardiaClinicalResponseView('));
      expect(source, contains('AiBubble('));
      expect(source, contains('StudyContinuationResolver.resolve('));
    });
  });
}
