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

  group('Top200 Expansion Batch15 hepatology pancreas V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String marker,
    })>[
      (
        id: 'AH',
        query: 'hepatite alcoólica',
        answer: 'HEPATITE ALCOÓLICA',
        authority: 'ACG',
        marker: '2024'
      ),
      (
        id: 'ALD',
        query: 'doença hepática associada ao álcool',
        answer: 'DOENÇA HEPÁTICA ASSOCIADA AO ÁLCOOL',
        authority: 'ACG',
        marker: '2024'
      ),
      (
        id: 'AIH',
        query: 'hepatite autoimune',
        answer: 'HEPATITE AUTOIMUNE',
        authority: 'EASL',
        marker: '2025'
      ),
      (
        id: 'PBC',
        query: 'colangite biliar primária',
        answer: 'COLANGITE BILIAR PRIMÁRIA',
        authority: 'AASLD',
        marker: '2021'
      ),
      (
        id: 'PSC',
        query: 'colangite esclerosante primária',
        answer: 'COLANGITE ESCLEROSANTE PRIMÁRIA',
        authority: 'AASLD',
        marker: '2022'
      ),
      (
        id: 'CP',
        query: 'pancreatite crônica',
        answer: 'PANCREATITE CRÔNICA',
        authority: 'ACG',
        marker: '2020'
      ),
      (
        id: 'EPI',
        query: 'insuficiência pancreática exócrina',
        answer: 'INSUFICIÊNCIA PANCREÁTICA EXÓCRINA',
        authority: 'AGA',
        marker: '2023'
      ),
      (
        id: 'PCYST',
        query: 'cisto pancreático IPMN',
        answer: 'CISTO PANCREÁTICO / IPMN',
        authority: 'IAP',
        marker: '2024'
      ),
      (
        id: 'HH',
        query: 'hemocromatose hereditária',
        answer: 'HEMOCROMATOSE HEREDITÁRIA',
        authority: 'EASL',
        marker: '2022'
      ),
      (
        id: 'WD',
        query: 'doença de Wilson',
        answer: 'DOENÇA DE WILSON',
        authority: 'EASL-ERN',
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
          q: 'alcoholic hepatitis',
          a: 'ALCOHOLIC HEPATITIS',
          marker: 'Alcohol-Associated Liver Disease'
        ),
        (
          q: 'alcohol-associated liver disease',
          a: 'ALCOHOL-ASSOCIATED LIVER DISEASE',
          marker: 'Alcohol-Associated Liver Disease'
        ),
        (
          q: 'autoimmune hepatitis',
          a: 'AUTOIMMUNE HEPATITIS',
          marker: 'Autoimmune Hepatitis'
        ),
        (
          q: 'primary biliary cholangitis',
          a: 'PRIMARY BILIARY CHOLANGITIS',
          marker: 'Primary Biliary Cholangitis'
        ),
        (
          q: 'primary sclerosing cholangitis',
          a: 'PRIMARY SCLEROSING CHOLANGITIS',
          marker: 'Primary Sclerosing Cholangitis'
        ),
        (
          q: 'chronic pancreatitis',
          a: 'CHRONIC PANCREATITIS',
          marker: 'Chronic Pancreatitis'
        ),
        (
          q: 'exocrine pancreatic insufficiency',
          a: 'EXOCRINE PANCREATIC INSUFFICIENCY',
          marker: 'Exocrine Pancreatic Insufficiency'
        ),
        (
          q: 'mucinous pancreatic neoplasm IPMN',
          a: 'PANCREATIC CYST IPMN',
          marker: 'Kyoto'
        ),
        (
          q: 'hereditary haemochromatosis',
          a: 'HEREDITARY HAEMOCHROMATOSIS',
          marker: 'Haemochromatosis'
        ),
        (q: 'Wilson disease', a: 'WILSON DISEASE', marker: 'Wilson'),
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

    test('precedência específica bloqueia colisões hepatopancreáticas', () {
      final ah = joined(resolve(
        'hepatite alcoólica em paciente com doença hepática associada ao álcool',
        'HEPATITE ALCOÓLICA',
      ));
      expect(ah, contains('including alcohol-associated hepatitis'));

      final aih = joined(resolve(
        'hepatite autoimune com cirrose',
        'HEPATITE AUTOIMUNE',
      ));
      expect(aih, contains('2025'));

      final psc = joined(resolve(
        'colangite esclerosante primária com colangite',
        'COLANGITE ESCLEROSANTE PRIMÁRIA',
      ));
      expect(psc, contains('Primary Sclerosing Cholangitis'));

      final epi = joined(resolve(
        'insuficiência pancreática exócrina por pancreatite crônica',
        'INSUFICIÊNCIA PANCREÁTICA EXÓCRINA',
      ));
      expect(epi, contains('AGA'));
      expect(epi, contains('2023'));

      final cyst = joined(resolve(
        'IPMN com pancreatite crônica',
        'CISTO PANCREÁTICO IPMN',
      ));
      expect(cyst, contains('Kyoto'));
      expect(cyst, contains('2024'));

      final wilson = joined(resolve(
        'doença de Wilson com hepatite',
        'DOENÇA DE WILSON',
      ));
      expect(wilson, contains('EASL-ERN'));
      expect(wilson, contains('2025'));
    });

    test('Batch01–15 permanecem curated-only', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      for (var i = 1; i <= 10; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }
      for (var i = 11; i <= 15; i++) {
        expect(source,
            contains('_top200ExpansionBatch${i}Domains.contains(domain)'));
      }

      for (final domain in <String>[
        'alcohol_associated_hepatitis_acg_2024',
        'alcohol_associated_liver_disease_acg_2024',
        'autoimmune_hepatitis_easl_2025',
        'primary_biliary_cholangitis_aasld_2021',
        'primary_sclerosing_cholangitis_aasld_2022',
        'chronic_pancreatitis_acg_2020',
        'exocrine_pancreatic_insufficiency_aga_2023',
        'pancreatic_cyst_ipmn_kyoto_2024',
        'hereditary_hemochromatosis_easl_2022',
        'wilson_disease_easl_2025',
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
