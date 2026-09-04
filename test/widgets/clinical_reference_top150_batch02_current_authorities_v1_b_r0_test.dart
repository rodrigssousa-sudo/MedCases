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

  group('Top150 Batch02 current authorities V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String year,
    })>[
      (id: 'DYS', query: 'dislipidemia', answer: 'DISLIPIDEMIA — abordagem clínica', authority: 'ACC/AHA', year: '2026'),
      (id: 'VHD', query: 'doença valvular', answer: 'DOENÇA VALVULAR — abordagem clínica', authority: 'ESC/EACTS', year: '2025'),
      (id: 'MYO', query: 'miocardite', answer: 'MIOCARDITE — abordagem clínica', authority: 'ESC', year: '2025'),
      (id: 'PERI', query: 'pericardite', answer: 'PERICARDITE — abordagem clínica', authority: 'ESC', year: '2025'),
      (id: 'PAD', query: 'doença arterial periférica', answer: 'DOENÇA ARTERIAL PERIFÉRICA — abordagem clínica', authority: 'ACC/AHA', year: '2024'),
      (id: 'AORTA', query: 'dissecção aórtica', answer: 'DISSECÇÃO AÓRTICA — abordagem clínica', authority: 'ACC/AHA', year: '2022'),
      (id: 'HCM', query: 'cardiomiopatia hipertrófica', answer: 'CARDIOMIOPATIA HIPERTRÓFICA — abordagem clínica', authority: 'AHA/ACC', year: '2024'),
      (id: 'IE', query: 'endocardite infecciosa', answer: 'ENDOCARDITE INFECCIOSA — abordagem clínica', authority: 'ESC', year: '2023'),
      (id: 'MEN', query: 'meningite bacteriana', answer: 'MENINGITE BACTERIANA — abordagem clínica', authority: 'WHO', year: '2025'),
      (id: 'HP', query: 'Helicobacter pylori', answer: 'HELICOBACTER PYLORI — abordagem clínica', authority: 'ACG', year: '2024'),
      (id: 'UGIB', query: 'hemorragia digestiva alta', answer: 'HEMORRAGIA DIGESTIVA ALTA — abordagem clínica', authority: 'ACG', year: '2021'),
      (id: 'APP', query: 'apendicite aguda', answer: 'APENDICITE AGUDA — abordagem clínica', authority: 'WSES', year: '2020'),
      (id: 'CHOLE', query: 'colecistite aguda', answer: 'COLECISTITE AGUDA — abordagem clínica', authority: 'WSES', year: '2020'),
      (id: 'CHOLANG', query: 'colangite aguda', answer: 'COLANGITE AGUDA — abordagem clínica', authority: 'Tokyo Guidelines', year: '2018'),
      (id: 'DIV', query: 'diverticulite aguda', answer: 'DIVERTICULITE AGUDA — abordagem clínica', authority: 'ACP', year: '2022'),
    ];

    test('os 15 temas do Batch02 resolvem a curadoria e >=3 URLs HTTPS', () {
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

    test('Batch01 e Batch02 permanecem curated-only sem base paralela', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      expect(source, contains('_top150Batch01Domains.contains(domain)'));
      expect(source, contains('_top150Batch02Domains.contains(domain)'));
      expect(source, contains("case 'asthma':"));
      expect(source, contains("case 'acute_diverticulitis':"));
    });

    test('Batch02 não altera o call-site compartilhado Plantão/Estudo', () {
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
