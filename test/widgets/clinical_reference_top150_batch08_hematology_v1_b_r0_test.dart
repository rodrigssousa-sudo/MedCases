import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/clinical_reference_resolver.dart';

void main() {
  ClinicalReferenceData resolve(String userText, String aiText) {
    return ClinicalReferenceResolver.resolve(
      userText: userText,
      aiText: aiText,
      lang: 'pt',
    );
  }

  String joined(ClinicalReferenceData data) => data.lines.join('\n');

  group('Top150 Batch08 hematology V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String year,
    })>[
      (id: 'IDA', query: 'anemia ferropriva', answer: 'ANEMIA FERROPRIVA — abordagem clínica', authority: 'AGA', year: '2024'),
      (id: 'B12', query: 'deficiência de vitamina B12', answer: 'DEFICIÊNCIA DE VITAMINA B12 — abordagem clínica', authority: 'NICE', year: '2024'),
      (id: 'AIHA', query: 'anemia hemolítica autoimune', answer: 'ANEMIA HEMOLÍTICA AUTOIMUNE — abordagem clínica', authority: 'International Consensus', year: '2020'),
      (id: 'SCD', query: 'doença falciforme', answer: 'DOENÇA FALCIFORME — abordagem clínica', authority: 'ASH', year: '2023'),
      (id: 'TDT', query: 'talassemia beta dependente de transfusão', answer: 'TALASSEMIA TRANSFUSIONAL — abordagem clínica', authority: 'TIF', year: '2025'),
      (id: 'ITP', query: 'trombocitopenia imune', answer: 'TROMBOCITOPENIA IMUNE — abordagem clínica', authority: 'ASH', year: '2019'),
      (id: 'TTP', query: 'púrpura trombótica trombocitopênica', answer: 'PTT / TTP — abordagem clínica', authority: 'ISTH', year: '2025'),
      (id: 'HIT', query: 'trombocitopenia induzida por heparina', answer: 'HIT — abordagem clínica', authority: 'ASH', year: '2022'),
      (id: 'VWD', query: 'doença de von Willebrand', answer: 'DOENÇA DE VON WILLEBRAND — abordagem clínica', authority: 'ASH/ISTH/NHF/WFH', year: '2021'),
      (id: 'RBC', query: 'limiar de transfusão de hemácias', answer: 'TRANSFUSÃO DE HEMÁCIAS — abordagem clínica', authority: 'AABB', year: '2023'),
      (id: 'AML', query: 'leucemia mieloide aguda em idoso', answer: 'LEUCEMIA MIELOIDE AGUDA — abordagem clínica', authority: 'ASH', year: '2025'),
      (id: 'AL', query: 'amiloidose AL', answer: 'AMILOIDOSE DE CADEIA LEVE — abordagem diagnóstica', authority: 'ASH', year: '2026'),
      (id: 'MM', query: 'mieloma múltiplo', answer: 'MIELOMA MÚLTIPLO — abordagem clínica', authority: 'EHA/EMN', year: '2025'),
      (id: 'CAT', query: 'trombose associada ao câncer', answer: 'TROMBOEMBOLISMO ASSOCIADO AO CÂNCER — abordagem clínica', authority: 'ASH', year: '2021'),
      (id: 'THROMB', query: 'testes de trombofilia', answer: 'TROMBOFILIA — quando testar', authority: 'ASH', year: '2023'),
    ];

    test('os 15 temas do Batch08 resolvem curadoria com >=3 URLs HTTPS', () {
      expect(cases.length, 15);
      for (final c in cases) {
        final result = resolve(c.query, c.answer);
        final text = joined(result);
        final urlLines = result.lines.where((line) => line.contains('https://')).toList();
        expect(text, contains(c.authority), reason: c.id);
        expect(text, contains(c.year), reason: c.id);
        expect(urlLines.length, greaterThanOrEqualTo(3), reason: c.id);
        for (final line in urlLines) {
          final url = line.substring(line.indexOf('https://')).trim();
          final uri = Uri.tryParse(url);
          expect(uri, isNotNull, reason: '${c.id}:$url');
          expect(uri!.scheme, 'https', reason: '${c.id}:$url');
          expect(uri.host, isNotEmpty, reason: '${c.id}:$url');
        }
      }
    });

    test('TTP e HIT vencem trombocitopenia imune genérica', () {
      final ttp = joined(resolve(
        'púrpura trombótica trombocitopênica com trombocitopenia',
        'TTP — emergência hematológica',
      ));
      expect(ttp, contains('ISTH'));
      expect(ttp, contains('2025'));

      final hit = joined(resolve(
        'trombocitopenia induzida por heparina',
        'HIT — trombose associada à heparina',
      ));
      expect(hit, contains('Heparin-Induced Thrombocytopenia'));
      expect(hit, contains('2022'));
    });

    test('câncer associado a VTE vence VTE genérico', () {
      final cat = joined(resolve(
        'trombose associada ao câncer',
        'TROMBOEMBOLISMO ASSOCIADO AO CÂNCER',
      ));
      expect(cat, contains('Patients With Cancer'));
      expect(cat, contains('2021'));
    });

    test('Batch01 a Batch08 permanecem curated-only no mesmo resolver', () {
      final source = File('lib/screens/ai/widgets/clinical_reference_resolver.dart').readAsStringSync();
      for (var i = 1; i <= 8; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }
      expect(source, contains("case 'iron_deficiency_anemia':"));
      expect(source, contains("case 'thrombophilia_testing':"));
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
