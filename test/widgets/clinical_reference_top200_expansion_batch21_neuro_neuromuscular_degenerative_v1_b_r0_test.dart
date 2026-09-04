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

  group('Top200 Expansion Batch21 neuro neuromuscular degenerative V1-B-R0',
      () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String marker,
    })>[
      (
        id: 'ALS',
        query: 'esclerose lateral amiotrófica',
        answer: 'ELA / ALS',
        authority: 'EAN/ERN EURO-NMD',
        marker: '2024'
      ),
      (
        id: 'DPN',
        query: 'neuropatia diabética periférica',
        answer: 'NEUROPATIA DIABÉTICA',
        authority: 'ADA',
        marker: '2026'
      ),
      (
        id: 'CTS',
        query: 'síndrome do túnel do carpo',
        answer: 'TÚNEL DO CARPO',
        authority: 'AAOS/ASSH',
        marker: '2024'
      ),
      (
        id: 'NPH',
        query: 'hidrocefalia de pressão normal idiopática',
        answer: 'HPN IDIOPÁTICA',
        authority: 'Japanese Society',
        marker: 'Third Edition'
      ),
      (
        id: 'ET',
        query: 'tremor essencial',
        answer: 'TREMOR ESSENCIAL',
        authority: 'MDS',
        marker: '2026'
      ),
      (
        id: 'HD',
        query: 'doença de Huntington',
        answer: 'DOENÇA DE HUNTINGTON',
        authority: 'German Neurological Society',
        marker: '2023'
      ),
      (
        id: 'DYS',
        query: 'distonia primária',
        answer: 'DISTONIA',
        authority: 'Movement Disorder Society',
        marker: 'Dystonia'
      ),
      (
        id: 'RLS',
        query: 'síndrome das pernas inquietas',
        answer: 'PERNAS INQUIETAS',
        authority: 'AASM',
        marker: '2025'
      ),
      (
        id: 'NUT',
        query: 'neuropatia nutricional por deficiência de vitamina B12',
        answer: 'NEUROPATIA NUTRICIONAL',
        authority: 'NICE',
        marker: '2024'
      ),
      (
        id: 'DCM',
        query: 'mielopatia cervical degenerativa',
        answer: 'MIELOPATIA CERVICAL DEGENERATIVA',
        authority: 'AO Spine',
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
          q: 'amyotrophic lateral sclerosis ALS',
          a: 'AMYOTROPHIC LATERAL SCLEROSIS',
          marker: 'EAN/ERN EURO-NMD'
        ),
        (
          q: 'painful diabetic polyneuropathy',
          a: 'DIABETIC PERIPHERAL NEUROPATHY',
          marker: 'ADA'
        ),
        (
          q: 'carpal tunnel syndrome',
          a: 'CARPAL TUNNEL SYNDROME',
          marker: 'AAOS/ASSH'
        ),
        (
          q: 'idiopathic normal pressure hydrocephalus iNPH',
          a: 'NORMAL PRESSURE HYDROCEPHALUS',
          marker: 'Third Edition'
        ),
        (q: 'essential tremor', a: 'ESSENTIAL TREMOR', marker: '2026'),
        (
          q: "Huntington's disease",
          a: 'HUNTINGTON DISEASE',
          marker: 'Huntington'
        ),
        (q: 'primary dystonia', a: 'PRIMARY DYSTONIA', marker: 'Dystonia'),
        (
          q: 'restless legs syndrome Willis-Ekbom',
          a: 'RESTLESS LEGS SYNDROME',
          marker: 'AASM'
        ),
        (
          q: 'nutritional peripheral neuropathy vitamin B12 deficiency',
          a: 'NUTRITIONAL NEUROPATHY',
          marker: 'Vitamin B12'
        ),
        (
          q: 'degenerative cervical myelopathy',
          a: 'DEGENERATIVE CERVICAL MYELOPATHY',
          marker: 'AO Spine'
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

    test(
        'precedência específica protege colisões neuromusculares e degenerativas',
        () {
      final als = joined(resolve(
        'esclerose lateral amiotrófica com doença do neurônio motor',
        'ELA / ALS',
      ));
      expect(als, contains('EAN/ERN EURO-NMD'));

      final dpn = joined(resolve(
        'diabetes tipo 2 com neuropatia diabética periférica dolorosa',
        'NEUROPATIA DIABÉTICA',
      ));
      expect(dpn, contains('Standards of Care in Diabetes 2026'));

      final cts = joined(resolve(
        'neuropatia periférica por síndrome do túnel do carpo',
        'SÍNDROME DO TÚNEL DO CARPO',
      ));
      expect(cts, contains('Carpal Tunnel Syndrome'));

      final et = joined(resolve(
        'tremor essencial versus Parkinson',
        'TREMOR ESSENCIAL',
      ));
      expect(et, contains('Essential Tremor'));

      final hd = joined(resolve(
        'coreia e doença de Huntington',
        'DOENÇA DE HUNTINGTON',
      ));
      expect(hd, contains('Huntington'));

      final rls = joined(resolve(
        'síndrome das pernas inquietas com distúrbio do sono',
        'PERNAS INQUIETAS',
      ));
      expect(rls, contains('Restless Legs Syndrome'));

      final nut = joined(resolve(
        'neuropatia periférica por deficiência de vitamina B12',
        'NEUROPATIA NUTRICIONAL',
      ));
      expect(nut, contains('Vitamin B12'));

      final dcm = joined(resolve(
        'cervicalgia com mielopatia cervical degenerativa',
        'MIELOPATIA CERVICAL DEGENERATIVA',
      ));
      expect(dcm, contains('Degenerative Cervical Myelopathy'));
      expect(dcm, contains('AO Spine'));
    });

    test('ALS nunca usa parâmetro AAN aposentado em 2026', () {
      final als = joined(resolve(
        'amyotrophic lateral sclerosis',
        'ALS',
        lang: 'en',
      ));
      expect(als, contains('EAN/ERN EURO-NMD'));
      expect(
          als,
          isNot(
              contains('Practice Parameter Update: The Care of the Patient')));
      expect(als, isNot(contains('AAN 2009')));
    });

    test('Batch01–21 permanecem curated-only', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      for (var i = 1; i <= 10; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }
      for (var i = 11; i <= 21; i++) {
        expect(source,
            contains('_top200ExpansionBatch${i}Domains.contains(domain)'));
      }

      for (final domain in <String>[
        'amyotrophic_lateral_sclerosis_ean_2024',
        'diabetic_peripheral_neuropathy_ada_aan_2026',
        'carpal_tunnel_syndrome_aaos_2024',
        'idiopathic_normal_pressure_hydrocephalus_2021',
        'essential_tremor_mds_2026',
        'huntington_disease_dgn_ehdn_2023',
        'dystonia_mds_ean_current',
        'restless_legs_syndrome_aasm_2025',
        'nutritional_peripheral_neuropathy_nice_2026',
        'degenerative_cervical_myelopathy_aospine_2025',
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
