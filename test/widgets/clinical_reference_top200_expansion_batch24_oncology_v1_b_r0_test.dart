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

  group('Top200 Expansion Batch24 oncology V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String marker,
    })>[
      (
        id: 'ALL',
        query: 'leucemia linfoblástica aguda',
        answer: 'LLA / ALL',
        authority: 'European LeukemiaNet',
        marker: '2024'
      ),
      (
        id: 'HL',
        query: 'linfoma de Hodgkin clássico',
        answer: 'LINFOMA DE HODGKIN',
        authority: 'BSH',
        marker: 'Hodgkin'
      ),
      (
        id: 'DLBCL',
        query: 'linfoma difuso de grandes células B',
        answer: 'DLBCL',
        authority: 'BSH',
        marker: '2025'
      ),
      (
        id: 'BREAST',
        query: 'câncer de mama',
        answer: 'CÂNCER DE MAMA',
        authority: 'ESMO',
        marker: 'Breast Cancer'
      ),
      (
        id: 'PROSTATE',
        query: 'câncer de próstata',
        answer: 'CÂNCER DE PRÓSTATA',
        authority: 'EAU',
        marker: '2026'
      ),
      (
        id: 'NSCLC',
        query: 'câncer de pulmão de não pequenas células',
        answer: 'NSCLC',
        authority: 'ESMO',
        marker: 'NSCLC'
      ),
      (
        id: 'CRC',
        query: 'câncer colorretal',
        answer: 'CÂNCER COLORRETAL',
        authority: 'ASCO',
        marker: 'Metastatic Colorectal'
      ),
      (
        id: 'CERVIX',
        query: 'câncer do colo do útero',
        answer: 'CÂNCER CERVICAL',
        authority: 'ESGO/ESTRO/ESP',
        marker: '2023'
      ),
      (
        id: 'OVARY',
        query: 'câncer de ovário epitelial',
        answer: 'CÂNCER DE OVÁRIO',
        authority: 'ESGO-ESMO-ESP',
        marker: '2024'
      ),
      (
        id: 'PANCREAS',
        query: 'câncer de pâncreas',
        answer: 'CÂNCER DE PÂNCREAS',
        authority: 'ESMO',
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
          q: 'acute lymphoblastic leukemia adult ALL',
          a: 'ACUTE LYMPHOBLASTIC LEUKEMIA',
          marker: 'European LeukemiaNet'
        ),
        (
          q: 'classical Hodgkin lymphoma',
          a: 'CLASSICAL HODGKIN LYMPHOMA',
          marker: 'Hodgkin'
        ),
        (
          q: 'diffuse large B-cell lymphoma DLBCL',
          a: 'DLBCL',
          marker: 'Large B-Cell'
        ),
        (q: 'breast cancer', a: 'BREAST CANCER', marker: 'Breast Cancer'),
        (q: 'prostate cancer', a: 'PROSTATE CANCER', marker: 'EAU'),
        (q: 'non-small cell lung cancer NSCLC', a: 'NSCLC', marker: 'NSCLC'),
        (q: 'colorectal cancer', a: 'COLORECTAL CANCER', marker: 'Colorectal'),
        (q: 'cervical cancer', a: 'CERVICAL CANCER', marker: 'ESGO/ESTRO/ESP'),
        (
          q: 'epithelial ovarian cancer',
          a: 'OVARIAN CANCER',
          marker: 'ESGO-ESMO-ESP'
        ),
        (
          q: 'pancreatic ductal adenocarcinoma',
          a: 'PANCREATIC CANCER',
          marker: 'Pancreatic'
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

    test('precedência específica protege colisões oncológicas', () {
      final all = joined(resolve(
        'leucemia linfoblástica aguda em adulto',
        'LLA / ALL',
      ));
      expect(all, contains('European LeukemiaNet'));
      expect(all, isNot(contains('Chronic Lymphocytic')));

      final hl = joined(resolve(
        'linfoma de Hodgkin clássico',
        'HODGKIN LYMPHOMA',
      ));
      expect(hl, contains('Hodgkin'));
      expect(hl, isNot(contains('Large B-Cell Lymphoma')));

      final dlbcl = joined(resolve(
        'linfoma difuso de grandes células B',
        'DLBCL',
      ));
      expect(dlbcl, contains('Large B-Cell Lymphoma'));

      final breast = joined(resolve(
        'câncer de mama metastático',
        'BREAST CANCER',
      ));
      expect(breast, contains('Breast Cancer'));

      final prostate = joined(resolve(
        'câncer de próstata metastático',
        'PROSTATE CANCER',
      ));
      expect(prostate, contains('EAU'));
      expect(prostate, contains('2026'));

      final nsclc = joined(resolve(
        'câncer de pulmão NSCLC',
        'NON-SMALL CELL LUNG CANCER',
      ));
      expect(nsclc, contains('NSCLC'));

      final crc = joined(resolve(
        'câncer colorretal metastático',
        'COLORECTAL CANCER',
      ));
      expect(crc, contains('ASCO'));

      final cervix = joined(resolve(
        'câncer cervical recorrente',
        'CERVICAL CANCER',
      ));
      expect(cervix, contains('ESGO/ESTRO/ESP'));

      final ovary = joined(resolve(
        'câncer de ovário epitelial avançado',
        'OVARIAN CANCER',
      ));
      expect(ovary, contains('ESGO-ESMO-ESP'));

      final pancreas = joined(resolve(
        'adenocarcinoma ductal pancreático metastático',
        'PANCREATIC CANCER',
      ));
      expect(pancreas, contains('ESMO'));
      expect(pancreas, contains('2025'));
    });

    test('Batch01–24 permanecem curated-only', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      for (var i = 1; i <= 10; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }
      for (var i = 11; i <= 24; i++) {
        expect(source,
            contains('_top200ExpansionBatch${i}Domains.contains(domain)'));
      }

      for (final domain in <String>[
        'adult_acute_lymphoblastic_leukemia_eln_2024',
        'classical_hodgkin_lymphoma_bsh_nci',
        'diffuse_large_b_cell_lymphoma_bsh_2025',
        'breast_cancer_esmo_nci_current',
        'prostate_cancer_eau_2026',
        'non_small_cell_lung_cancer_esmo_nci_current',
        'colorectal_cancer_asco_nci_current',
        'cervical_cancer_esgo_2023_current',
        'ovarian_cancer_esgo_esmo_2024',
        'pancreatic_cancer_esmo_2025',
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
