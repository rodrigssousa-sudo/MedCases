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

  group('Top150 Batch07 neuro psych V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String year,
    })>[
      (id: 'EPI', query: 'epilepsia', answer: 'EPILEPSIA — abordagem clínica', authority: 'NICE', year: '2025'),
      (id: 'SE', query: 'status epilepticus', answer: 'STATUS EPILEPTICUS — abordagem clínica', authority: 'NICE', year: '2025'),
      (id: 'MIG', query: 'enxaqueca', answer: 'ENXAQUECA — abordagem clínica', authority: 'ACP', year: '2025'),
      (id: 'PD', query: 'doença de Parkinson', answer: 'DOENÇA DE PARKINSON — abordagem clínica', authority: 'NICE', year: '2026'),
      (id: 'MS', query: 'esclerose múltipla', answer: 'ESCLEROSE MÚLTIPLA — abordagem clínica', authority: 'NICE', year: '2026'),
      (id: 'MG', query: 'miastenia gravis', answer: 'MIASTENIA GRAVIS — abordagem clínica', authority: 'International Consensus Guidance', year: '2021'),
      (id: 'GBS', query: 'síndrome de Guillain-Barré', answer: 'GUILLAIN-BARRÉ — abordagem clínica', authority: 'EAN/PNS', year: '2023'),
      (id: 'DEL', query: 'delirium', answer: 'DELIRIUM — abordagem clínica', authority: 'NICE', year: '2023'),
      (id: 'DEM', query: 'demência e Alzheimer', answer: 'DEMÊNCIA / ALZHEIMER — abordagem clínica', authority: 'NICE', year: '2025'),
      (id: 'NP', query: 'dor neuropática', answer: 'DOR NEUROPÁTICA — abordagem clínica', authority: 'NICE', year: '2020'),
      (id: 'MDD', query: 'transtorno depressivo maior', answer: 'DEPRESSÃO MAIOR — abordagem clínica', authority: 'NICE', year: '2026'),
      (id: 'BD', query: 'transtorno bipolar', answer: 'TRANSTORNO BIPOLAR — abordagem clínica', authority: 'NICE', year: '2025'),
      (id: 'GAD', query: 'ansiedade generalizada', answer: 'ANSIEDADE GENERALIZADA — abordagem clínica', authority: 'NICE', year: '2024'),
      (id: 'SCZ', query: 'esquizofrenia', answer: 'ESQUIZOFRENIA — abordagem clínica', authority: 'NICE', year: '2025'),
      (id: 'AW', query: 'abstinência alcoólica', answer: 'ABSTINÊNCIA ALCOÓLICA — abordagem clínica', authority: 'NICE', year: '2026'),
    ];

    test('os 15 temas do Batch07 resolvem curadoria com >=3 URLs HTTPS', () {
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

    test('status epilepticus vence epilepsia genérica', () {
      final text = joined(resolve(
        'status epilepticus em paciente com epilepsia',
        'STATUS EPILEPTICUS — emergência neurológica',
      ));
      expect(text, contains('Status Epilepticus'));
      expect(text, contains('2025'));
    });

    test('abstinência alcoólica vence delirium genérico', () {
      final text = joined(resolve(
        'delirium tremens por abstinência alcoólica',
        'ABSTINÊNCIA ALCOÓLICA — delirium tremens',
      ));
      expect(text, contains('Alcohol-use Disorders'));
      expect(text, contains('2026'));
      expect(text, isNot(contains('Delirium: Prevention')));
    });

    test('bipolar depression vence depressão maior genérica', () {
      final text = joined(resolve(
        'depressão bipolar',
        'TRANSTORNO BIPOLAR — episódio depressivo',
      ));
      expect(text, contains('Bipolar Disorder'));
      expect(text, contains('2025'));
    });

    test('Batch01 a Batch07 permanecem curated-only no mesmo resolver', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      for (var i = 1; i <= 7; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }

      expect(source, contains("case 'epilepsy':"));
      expect(source, contains("case 'alcohol_withdrawal':"));
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
