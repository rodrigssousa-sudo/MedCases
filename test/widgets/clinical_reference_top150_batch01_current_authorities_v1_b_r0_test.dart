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

  group('Top150 Batch01 current authorities V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String year,
    })>[
      (
        id: 'ASTHMA',
        query: 'asma',
        answer: 'ASMA — abordagem clínica',
        authority: 'GINA',
        year: '2026',
      ),
      (
        id: 'COPD',
        query: 'DPOC',
        answer: 'DPOC — abordagem clínica',
        authority: 'GOLD',
        year: '2026',
      ),
      (
        id: 'DIABETES',
        query: 'diabetes mellitus',
        answer: 'DIABETES MELLITUS — abordagem clínica',
        authority: 'ADA',
        year: '2026',
      ),
      (
        id: 'DKA_HHS',
        query: 'cetoacidose diabética e estado hiperosmolar',
        answer: 'CETOACIDOSE DIABÉTICA — abordagem clínica',
        authority: 'ADA',
        year: '2026',
      ),
      (
        id: 'HYPERTENSION',
        query: 'hipertensão arterial',
        answer: 'HIPERTENSÃO ARTERIAL — abordagem clínica',
        authority: 'AHA/ACC',
        year: '2025',
      ),
      (
        id: 'ACS',
        query: 'síndrome coronariana aguda',
        answer: 'SÍNDROME CORONARIANA AGUDA — abordagem clínica',
        authority: 'ACC/AHA',
        year: '2025',
      ),
      (
        id: 'AF',
        query: 'fibrilação atrial',
        answer: 'FIBRILAÇÃO ATRIAL — abordagem clínica',
        authority: 'ESC',
        year: '2024',
      ),
      (
        id: 'HF',
        query: 'insuficiência cardíaca',
        answer: 'INSUFICIÊNCIA CARDÍACA — abordagem clínica',
        authority: 'AHA/ACC/HFSA',
        year: '2022',
      ),
      (
        id: 'PE',
        query: 'embolia pulmonar',
        answer: 'EMBOLIA PULMONAR — abordagem clínica',
        authority: 'AHA/ACC',
        year: '2026',
      ),
      (
        id: 'STROKE',
        query: 'acidente vascular cerebral isquêmico',
        answer: 'AVC ISQUÊMICO — abordagem clínica',
        authority: 'AHA/ASA',
        year: '2026',
      ),
      (
        id: 'CKD',
        query: 'doença renal crônica',
        answer: 'DOENÇA RENAL CRÔNICA — abordagem clínica',
        authority: 'KDIGO',
        year: '2024',
      ),
      (
        id: 'SEPSIS',
        query: 'sepse e choque séptico',
        answer: 'SEPSE — abordagem clínica',
        authority: 'Surviving Sepsis',
        year: '2026',
      ),
      (
        id: 'CAP',
        query: 'pneumonia adquirida na comunidade',
        answer: 'PNEUMONIA ADQUIRIDA NA COMUNIDADE — abordagem clínica',
        authority: 'ATS',
        year: '2025',
      ),
      (
        id: 'UTI',
        query: 'infecção urinária',
        answer: 'INFECÇÃO URINÁRIA — abordagem clínica',
        authority: 'IDSA',
        year: '2025',
      ),
      (
        id: 'PANCREATITIS',
        query: 'pancreatite aguda',
        answer: 'PANCREATITE AGUDA — abordagem clínica',
        authority: 'ACG',
        year: '2024',
      ),
    ];

    test('todos os 15 temas resolvem autoridade atual com URLs reais', () {
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

    test('Batch01 não deixa referência protocolar antiga ultrapassar curadoria', () {
      final pancreatitis = joined(resolve(
        'pancreatite aguda',
        'PANCREATITE AGUDA — abordagem clínica',
      ));
      expect(pancreatitis, contains('ACG'));
      expect(pancreatitis, contains('2024'));
      expect(pancreatitis, isNot(contains('ACG 2013')));
      expect(pancreatitis, isNot(contains('IAP/APA 2013')));

      final pe = joined(resolve(
        'embolia pulmonar',
        'EMBOLIA PULMONAR — abordagem clínica',
      ));
      expect(pe, contains('2026'));
      expect(pe, isNot(contains('ESC/ERS — Guidelines for diagnosis')));
    });

    test('resolver produtivo permite até quatro referências', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      expect(source, contains('limit: 4'));
      expect(
        source,
        contains('_top150Batch01Domains.contains(domain)'),
      );
    });

    test('Plantão e Estudo seguem o mesmo call-site do resolver', () {
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
