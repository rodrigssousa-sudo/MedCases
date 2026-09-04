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

  group('Top200 Expansion Batch16 endocrinology metabolism V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String marker,
    })>[
      (
        id: 'DI',
        query: 'diabetes insípido',
        answer: 'DIABETES INSÍPIDO',
        authority: 'ESE/Endocrine Society',
        marker: '2026'
      ),
      (
        id: 'SIADH',
        query: 'SIADH',
        answer: 'SIADH',
        authority: 'ESE/ESICM/ERA',
        marker: 'Hyponatraemia'
      ),
      (
        id: 'HCAL',
        query: 'hipercalcemia',
        answer: 'HIPERCALCEMIA',
        authority: 'Endocrine Society',
        marker: '2023'
      ),
      (
        id: 'LCAL',
        query: 'hipocalcemia',
        answer: 'HIPOCALCEMIA',
        authority: 'ESE',
        marker: '2025'
      ),
      (
        id: 'MG',
        query: 'hipomagnesemia',
        answer: 'HIPOMAGNESEMIA',
        authority: 'American Journal of Kidney Diseases',
        marker: '2024'
      ),
      (
        id: 'PHOS',
        query: 'hipofosfatemia',
        answer: 'HIPOFOSFATEMIA',
        authority: 'BMC Medicine',
        marker: '2025'
      ),
      (
        id: 'TG',
        query: 'hipertrigliceridemia grave',
        answer: 'HIPERTRIGLICERIDEMIA GRAVE',
        authority: 'ACC/AHA',
        marker: '2026'
      ),
      (
        id: 'METS',
        query: 'síndrome metabólica',
        answer: 'SÍNDROME METABÓLICA',
        authority: 'AHA',
        marker: 'Metabolic Syndrome'
      ),
      (
        id: 'HYPOPIT',
        query: 'hipopituitarismo',
        answer: 'HIPOPITUITARISMO',
        authority: 'Endocrine Society',
        marker: 'Hypopituitarism'
      ),
      (
        id: 'AI',
        query: 'incidentaloma adrenal',
        answer: 'INCIDENTALOMA ADRENAL',
        authority: 'ESE/ENSAT',
        marker: '2023'
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
          q: 'arginine vasopressin deficiency',
          a: 'AVP DEFICIENCY',
          marker: 'Arginine Vasopressin'
        ),
        (
          q: 'síndrome de secreción inadecuada de ADH',
          a: 'SIADH',
          marker: 'Hyponatraemia'
        ),
        (q: 'hypercalcemia', a: 'HYPERCALCEMIA', marker: 'Hypercalcemia'),
        (q: 'hypocalcemia', a: 'HYPOCALCEMIA', marker: 'Hypoparathyroidism'),
        (
          q: 'magnesium deficiency',
          a: 'HYPOMAGNESEMIA',
          marker: 'Magnesium Disorders'
        ),
        (
          q: 'hypophosphatemia',
          a: 'HYPOPHOSPHATEMIA',
          marker: 'Hypophosphatemia'
        ),
        (
          q: 'severe hypertriglyceridemia',
          a: 'SEVERE HYPERTRIGLYCERIDEMIA',
          marker: 'Dyslipidemia'
        ),
        (
          q: 'metabolic syndrome',
          a: 'METABOLIC SYNDROME',
          marker: 'Metabolic Syndrome'
        ),
        (q: 'hypopituitarism', a: 'HYPOPITUITARISM', marker: 'Hypopituitarism'),
        (
          q: 'adrenal incidentaloma',
          a: 'ADRENAL INCIDENTALOMA',
          marker: 'Adrenal Incidentalomas'
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

    test('precedência específica bloqueia colisões endócrino-metabólicas', () {
      final di = joined(resolve(
        'diabetes insípido central',
        'DEFICIÊNCIA DE ARGININA VASOPRESSINA',
      ));
      expect(di, contains('Arginine Vasopressin'));
      expect(di, contains('2026'));

      final siadh = joined(resolve(
        'SIADH com hiponatremia',
        'SIADH',
      ));
      expect(siadh, contains('Hyponatraemia'));

      final hypoCa = joined(resolve(
        'hipocalcemia por hipoparatireoidismo',
        'HIPOCALCEMIA',
      ));
      expect(hypoCa, contains('2025'));

      final hyperCa = joined(resolve(
        'hipercalcemia',
        'HIPERCALCEMIA',
      ));
      expect(hyperCa, contains('Hypercalcemia'));

      final severeTg = joined(resolve(
        'hipertrigliceridemia grave com triglicérides acima de 1000',
        'HIPERTRIGLICERIDEMIA GRAVE',
      ));
      expect(severeTg, contains('2026'));
      expect(severeTg, contains('Dyslipidemia'));

      final adrenal = joined(resolve(
        'incidentaloma adrenal',
        'INCIDENTALOMA ADRENAL',
      ));
      expect(adrenal, contains('Adrenal Incidentalomas'));
      expect(adrenal, contains('2023'));
    });

    test('Batch01–16 permanecem curated-only', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      for (var i = 1; i <= 10; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }
      for (var i = 11; i <= 16; i++) {
        expect(source,
            contains('_top200ExpansionBatch${i}Domains.contains(domain)'));
      }

      for (final domain in <String>[
        'arginine_vasopressin_deficiency_ese_es_2026',
        'siadh_hyponatremia_ese',
        'hypercalcemia_endocrine_society_2023',
        'hypocalcemia_hypoparathyroidism_ese_2025',
        'hypomagnesemia_core_curriculum_2024',
        'hypophosphatemia_consensus_2025',
        'severe_hypertriglyceridemia_acc_aha_2026',
        'metabolic_syndrome_harmonized',
        'hypopituitarism_endocrine_society',
        'adrenal_incidentaloma_ese_2023',
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
