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

  group('Top200 Expansion Batch23 hematology V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String marker,
    })>[
      (
        id: 'AI',
        query: 'anemia da doença crônica',
        answer: 'ANEMIA DA INFLAMAÇÃO',
        authority: 'ASH/Blood',
        marker: 'Inflammation'
      ),
      (
        id: 'FOL',
        query: 'deficiência de folato',
        answer: 'DEFICIÊNCIA DE FOLATO',
        authority: 'NIH',
        marker: 'Folate'
      ),
      (
        id: 'AA',
        query: 'anemia aplástica adquirida',
        answer: 'ANEMIA APLÁSTICA',
        authority: 'ASH',
        marker: '2026'
      ),
      (
        id: 'G6PD',
        query: 'deficiência de G6PD',
        answer: 'DEFICIÊNCIA DE G6PD',
        authority: 'WHO',
        marker: '2025'
      ),
      (
        id: 'HEM',
        query: 'hemofilia A e B',
        answer: 'HEMOFILIA A/B',
        authority: 'WFH',
        marker: 'Hemophilia'
      ),
      (
        id: 'DIC',
        query: 'coagulação intravascular disseminada',
        answer: 'CIVD / DIC',
        authority: 'ISTH',
        marker: '2025'
      ),
      (
        id: 'PV',
        query: 'policitemia vera',
        answer: 'POLICITEMIA VERA',
        authority: 'European LeukemiaNet',
        marker: 'Polycythaemia Vera'
      ),
      (
        id: 'ET',
        query: 'trombocitemia essencial',
        answer: 'TROMBOCITEMIA ESSENCIAL',
        authority: 'American Journal of Hematology',
        marker: '2024'
      ),
      (
        id: 'MF',
        query: 'mielofibrose primária',
        answer: 'MIELOFIBROSE',
        authority: 'BSH',
        marker: '2023'
      ),
      (
        id: 'CLL',
        query: 'leucemia linfocítica crônica',
        answer: 'LLC / CLL',
        authority: 'BSH',
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
          q: 'anemia of inflammation',
          a: 'ANEMIA OF INFLAMMATION',
          marker: 'ASH/Blood'
        ),
        (
          q: 'folate deficiency anemia',
          a: 'FOLATE DEFICIENCY',
          marker: 'Folate'
        ),
        (
          q: 'severe acquired aplastic anemia',
          a: 'APLASTIC ANEMIA',
          marker: '2026'
        ),
        (
          q: 'glucose-6-phosphate dehydrogenase deficiency',
          a: 'G6PD DEFICIENCY',
          marker: 'G6PD'
        ),
        (
          q: 'hemophilia A factor VIII deficiency',
          a: 'HEMOPHILIA A',
          marker: 'WFH'
        ),
        (q: 'disseminated intravascular coagulation', a: 'DIC', marker: 'ISTH'),
        (
          q: 'polycythemia vera JAK2',
          a: 'POLYCYTHEMIA VERA',
          marker: 'European LeukemiaNet'
        ),
        (
          q: 'essential thrombocythemia',
          a: 'ESSENTIAL THROMBOCYTHEMIA',
          marker: '2024'
        ),
        (
          q: 'primary myelofibrosis',
          a: 'PRIMARY MYELOFIBROSIS',
          marker: 'Myelofibrosis'
        ),
        (
          q: 'chronic lymphocytic leukemia',
          a: 'CHRONIC LYMPHOCYTIC LEUKEMIA',
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

    test('precedência específica protege colisões hematológicas', () {
      expect(
        joined(resolve(
          'anemia da doença crônica em artrite reumatoide',
          'ANEMIA DA INFLAMAÇÃO',
        )),
        contains('ASH/Blood'),
      );

      expect(
        joined(resolve(
          'anemia macrocítica por deficiência de folato',
          'DEFICIÊNCIA DE FOLATO',
        )),
        contains('Folate'),
      );

      expect(
        joined(resolve(
          'pancitopenia por anemia aplástica adquirida',
          'ANEMIA APLÁSTICA',
        )),
        contains('2026'),
      );

      expect(
        joined(resolve(
          'anemia hemolítica por deficiência de G6PD',
          'DEFICIÊNCIA DE G6PD',
        )),
        contains('G6PD'),
      );

      expect(
        joined(resolve(
          'sangramento por hemofilia B deficiência de fator IX',
          'HEMOFILIA B',
        )),
        contains('WFH'),
      );

      final dic = joined(resolve(
        'sepse com coagulação intravascular disseminada e trombocitopenia',
        'CIVD / DIC',
      ));
      expect(dic, contains('ISTH'));
      expect(dic, contains('2025'));

      final mf = joined(resolve(
        'mielofibrose pós-policitemia vera',
        'MIELOFIBROSE PÓS-PV',
      ));
      expect(mf, contains('Myelofibrosis'));
      expect(mf,
          isNot(contains('Diagnosis and Management of Polycythaemia Vera')));

      final et = joined(resolve(
        'trombocitose por trombocitemia essencial',
        'TROMBOCITEMIA ESSENCIAL',
      ));
      expect(et, contains('Essential Thrombocythemia'));

      final cll = joined(resolve(
        'leucemia linfocítica crônica de células B',
        'LLC / CLL',
      ));
      expect(cll, contains('2025'));
      expect(cll, contains('Chronic Lymphocytic'));
    });

    test('Batch01–23 permanecem curated-only', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      for (var i = 1; i <= 10; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }
      for (var i = 11; i <= 23; i++) {
        expect(source,
            contains('_top200ExpansionBatch${i}Domains.contains(domain)'));
      }

      for (final domain in <String>[
        'anemia_of_inflammation_ash_current',
        'folate_deficiency_nih_who_bsh',
        'acquired_aplastic_anemia_ash_2026',
        'g6pd_deficiency_who_2025',
        'hemophilia_ab_wfh_living_2026',
        'disseminated_intravascular_coagulation_isth_2025',
        'polycythemia_vera_bsh_eln_current',
        'essential_thrombocythemia_2024_current',
        'myelofibrosis_bsh_2023_current',
        'chronic_lymphocytic_leukemia_bsh_2025',
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
