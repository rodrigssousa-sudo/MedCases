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

  group('Top200 Expansion Batch29 pediatrics V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String marker,
    })>[
      (
        id: 'PERT',
        query: 'coqueluche pediátrica',
        answer: 'COQUELUCHE PEDIÁTRICA',
        authority: 'CDC',
        marker: '2026'
      ),
      (
        id: 'CROUP',
        query: 'crupe pediátrico',
        answer: 'CRUPE',
        authority: 'Canadian Paediatric Society',
        marker: '2026'
      ),
      (
        id: 'AOM',
        query: 'otite média aguda pediátrica',
        answer: 'OMA PEDIÁTRICA',
        authority: 'AAP',
        marker: 'Acute Otitis Media'
      ),
      (
        id: 'SCAR',
        query: 'escarlatina pediátrica',
        answer: 'ESCARLATINA',
        authority: 'CDC',
        marker: '2026'
      ),
      (
        id: 'AGE',
        query: 'gastroenterite aguda pediátrica',
        answer: 'GASTROENTERITE AGUDA',
        authority: 'WHO',
        marker: '2024'
      ),
      (
        id: 'DEHY',
        query: 'desidratação pediátrica',
        answer: 'DESIDRATAÇÃO PEDIÁTRICA',
        authority: 'Royal Children’s Hospital',
        marker: '2026'
      ),
      (
        id: 'KD',
        query: 'doença de Kawasaki',
        answer: 'DOENÇA DE KAWASAKI',
        authority: 'AHA',
        marker: '2024'
      ),
      (
        id: 'HFMD',
        query: 'doença mão-pé-boca',
        answer: 'MÃO-PÉ-BOCA',
        authority: 'CDC',
        marker: 'Hand, Foot'
      ),
      (
        id: 'FS',
        query: 'convulsão febril simples',
        answer: 'CONVULSÃO FEBRIL',
        authority: 'AAP',
        marker: 'Febrile Seizure'
      ),
      (
        id: 'ASD',
        query: 'transtorno do espectro autista pediátrico',
        answer: 'TEA / AUTISMO',
        authority: 'AAP',
        marker: '2025'
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
        (
          q: 'pediatric pertussis whooping cough',
          a: 'PERTUSSIS',
          marker: 'CDC'
        ),
        (
          q: 'pediatric croup laryngotracheobronchitis',
          a: 'CROUP',
          marker: 'Canadian Paediatric Society'
        ),
        (
          q: 'pediatric acute otitis media AOM',
          a: 'ACUTE OTITIS MEDIA',
          marker: 'AAP'
        ),
        (q: 'scarlet fever child', a: 'SCARLET FEVER', marker: 'CDC'),
        (
          q: 'pediatric acute gastroenteritis',
          a: 'ACUTE GASTROENTERITIS',
          marker: 'WHO'
        ),
        (
          q: 'pediatric dehydration',
          a: 'PEDIATRIC DEHYDRATION',
          marker: '2026'
        ),
        (q: 'Kawasaki disease', a: 'KAWASAKI DISEASE', marker: 'AHA'),
        (q: 'hand-foot-and-mouth disease', a: 'HFMD', marker: 'CDC'),
        (q: 'simple febrile seizure', a: 'FEBRILE SEIZURE', marker: 'AAP'),
        (
          q: 'autism spectrum disorder',
          a: 'AUTISM SPECTRUM DISORDER',
          marker: '2025'
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

    test('precedência específica protege colisões pediátricas', () {
      final pert = joined(resolve(
        'lactente com coqueluche pediátrica e tosse paroxística',
        'COQUELUCHE',
      ));
      expect(pert, contains('CDC'));
      expect(pert, contains('Pertussis'));

      final croup = joined(resolve(
        'crupe pediátrico com estridor',
        'CROUP',
      ));
      expect(croup, contains('Canadian Paediatric Society'));

      final aom = joined(resolve(
        'otite média aguda pediátrica versus otite externa',
        'ACUTE OTITIS MEDIA',
      ));
      expect(aom, contains('Acute Otitis Media'));

      final scarlet = joined(resolve(
        'faringite estreptocócica com escarlatina pediátrica',
        'SCARLET FEVER',
      ));
      expect(scarlet, contains('Scarlet Fever'));

      final age = joined(resolve(
        'gastroenterite aguda pediátrica com desidratação leve',
        'ACUTE GASTROENTERITIS',
      ));
      expect(age, contains('WHO'));
      expect(age, contains('Gastroenteritis'));

      final dehydration = joined(resolve(
        'desidratação pediátrica por gastroenterite',
        'PEDIATRIC DEHYDRATION',
      ));
      expect(dehydration, contains('Dehydration'));
      expect(dehydration, contains('2026'));

      final kd = joined(resolve(
        'doença de Kawasaki versus escarlatina',
        'KAWASAKI DISEASE',
      ));
      expect(kd, contains('AHA'));
      expect(kd, contains('2024'));

      final hfmd = joined(resolve(
        'doença mão-pé-boca com exantema',
        'HAND FOOT MOUTH DISEASE',
      ));
      expect(hfmd, contains('CDC'));

      final fs = joined(resolve(
        'convulsão febril simples versus epilepsia',
        'FEBRILE SEIZURE',
      ));
      expect(fs, contains('AAP'));
      expect(fs, contains('Febrile Seizure'));

      final asd = joined(resolve(
        'transtorno do espectro autista com atraso do desenvolvimento',
        'AUTISM SPECTRUM DISORDER',
      ));
      expect(asd, contains('AAP'));
      expect(asd, contains('2025'));
    });

    test('Batch01–29 permanecem curated-only', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      for (var i = 1; i <= 10; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }
      for (var i = 11; i <= 29; i++) {
        expect(source,
            contains('_top200ExpansionBatch${i}Domains.contains(domain)'));
      }

      for (final domain in <String>[
        'pediatric_pertussis_cdc_2026',
        'pediatric_croup_cps_2026',
        'pediatric_acute_otitis_media_aap_nice',
        'pediatric_scarlet_fever_cdc_2026',
        'pediatric_acute_gastroenteritis_who_2024',
        'pediatric_dehydration_rch_2026',
        'kawasaki_disease_aha_2024',
        'hand_foot_mouth_disease_cdc_who',
        'febrile_seizure_aap_rch_current',
        'autism_spectrum_disorder_aap_2025',
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
