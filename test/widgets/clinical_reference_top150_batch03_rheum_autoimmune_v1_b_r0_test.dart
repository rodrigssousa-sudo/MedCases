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

  group('Top150 Batch03 rheum autoimmune V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String year,
    })>[
      (id: 'RA', query: 'artrite reumatoide', answer: 'ARTRITE REUMATOIDE — abordagem clínica', authority: 'EULAR', year: '2026'),
      (id: 'SLE', query: 'lupus eritematoso sistêmico', answer: 'LÚPUS ERITEMATOSO SISTÊMICO — abordagem clínica', authority: 'ACR', year: '2025'),
      (id: 'LN', query: 'nefrite lúpica', answer: 'NEFRITE LÚPICA — abordagem clínica', authority: 'KDIGO', year: '2024'),
      (id: 'GOUT', query: 'gota', answer: 'GOTA — abordagem clínica', authority: 'ACR', year: '2020'),
      (id: 'OA', query: 'osteoartrite', answer: 'OSTEOARTRITE — abordagem clínica', authority: 'ACR', year: '2019'),
      (id: 'PSA', query: 'artrite psoriásica', answer: 'ARTRITE PSORIÁSICA — abordagem clínica', authority: 'EULAR', year: '2023'),
      (id: 'AXSPA', query: 'espondiloartrite axial', answer: 'ESPONDILOARTRITE AXIAL — abordagem clínica', authority: 'ASAS/EULAR', year: '2022'),
      (id: 'SSC', query: 'esclerose sistêmica', answer: 'ESCLEROSE SISTÊMICA — abordagem clínica', authority: 'EULAR', year: '2023'),
      (id: 'ANCA', query: 'vasculite ANCA', answer: 'VASCULITE ANCA — abordagem clínica', authority: 'EULAR', year: '2022'),
      (id: 'GCA', query: 'arterite de células gigantes', answer: 'ARTERITE DE CÉLULAS GIGANTES — abordagem clínica', authority: 'ACR', year: '2021'),
      (id: 'SJO', query: 'síndrome de Sjögren', answer: 'SÍNDROME DE SJÖGREN — abordagem clínica', authority: 'EULAR', year: '2019'),
      (id: 'APS', query: 'síndrome antifosfolípide', answer: 'SÍNDROME ANTIFOSFOLÍPIDE — abordagem clínica', authority: 'EULAR', year: '2019'),
      (id: 'BEH', query: 'doença de Behçet', answer: 'DOENÇA DE BEHÇET — abordagem clínica', authority: 'EULAR', year: '2026'),
      (id: 'PMR', query: 'polimialgia reumática', answer: 'POLIMIALGIA REUMÁTICA — abordagem clínica', authority: 'EULAR/ACR', year: '2015'),
      (id: 'STILL', query: 'doença de Still do adulto', answer: 'DOENÇA DE STILL — abordagem clínica', authority: 'EULAR/PReS', year: '2024'),
    ];

    test('os 15 temas do Batch03 resolvem curadoria com >=3 URLs HTTPS', () {
      expect(cases.length, 15);
      for (final c in cases) {
        final result = resolve(c.query, c.answer);
        final text = joined(result);
        final urlLines =
            result.lines.where((line) => line.contains('https://')).toList();

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

    test('Sjögren resolve em formas com e sem diacrítico', () {
      final queries = <String>[
        'síndrome de Sjögren',
        'sindrome de Sjogren',
        'Sjögren syndrome',
        'Sjoegren syndrome',
      ];

      for (final query in queries) {
        final result = resolve(
          query,
          'SÍNDROME DE SJÖGREN — abordagem clínica',
        );
        final text = joined(result);
        expect(text, contains('EULAR'), reason: query);
        expect(text, contains('2019'), reason: query);
        expect(
          result.lines.where((line) => line.contains('https://')).length,
          greaterThanOrEqualTo(3),
          reason: query,
        );
      }
    });

    test('Batch01, 02 e 03 permanecem curated-only no mesmo resolver', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      expect(source, contains('_top150Batch01Domains.contains(domain)'));
      expect(source, contains('_top150Batch02Domains.contains(domain)'));
      expect(source, contains('_top150Batch03Domains.contains(domain)'));
      expect(source, contains("case 'rheumatoid_arthritis':"));
      expect(source, contains("case 'still_disease':"));
    });

    test('Plantão e Estudo continuam no mesmo call-site', () {
      final source = File('lib/screens/ai_screen.dart').readAsStringSync();
      expect(
        'ClinicalReferenceResolver.resolve('.allMatches(source).length,
        1,
      );
      expect(source, contains('GuardiaClinicalResponseView('));
      expect(source, contains('AiBubble('));
      expect(source, contains('StudyContinuationResolver.resolve('));
    });
  });
}
