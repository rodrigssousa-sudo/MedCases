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

  group('Top150 Batch10 OBGYN pediatrics V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String year,
    })>[
      (id: 'PE', query: 'pré-eclâmpsia', answer: 'PRÉ-ECLÂMPSIA — abordagem clínica', authority: 'NICE', year: '2023'),
      (id: 'PPH', query: 'hemorragia pós-parto', answer: 'HEMORRAGIA PÓS-PARTO — abordagem clínica', authority: 'WHO', year: '2025'),
      (id: 'GDM', query: 'diabetes gestacional', answer: 'DIABETES GESTACIONAL — abordagem clínica', authority: 'ADA', year: '2026'),
      (id: 'ECT', query: 'gravidez ectópica', answer: 'GRAVIDEZ ECTÓPICA — abordagem clínica', authority: 'NICE', year: '2026'),
      (id: 'MISC', query: 'abortamento espontâneo', answer: 'ABORTAMENTO / PERDA GESTACIONAL PRECOCE', authority: 'NICE', year: '2026'),
      (id: 'ENDO', query: 'endometriose', answer: 'ENDOMETRIOSE — abordagem clínica', authority: 'NICE', year: '2024'),
      (id: 'HMB', query: 'sangramento menstrual intenso', answer: 'SANGRAMENTO MENSTRUAL INTENSO — abordagem clínica', authority: 'NICE', year: '2024'),
      (id: 'MENO', query: 'menopausa', answer: 'MENOPAUSA — abordagem clínica', authority: 'NICE', year: '2026'),
      (id: 'BRONCH', query: 'bronquiolite', answer: 'BRONQUIOLITE — abordagem pediátrica', authority: 'NICE', year: '2021'),
      (id: 'FEVER', query: 'febre em menor de 5 anos', answer: 'FEBRE EM MENORES DE 5 ANOS', authority: 'NICE', year: '2025'),
      (id: 'PUTI', query: 'ITU pediátrica', answer: 'INFECÇÃO URINÁRIA PEDIÁTRICA', authority: 'NICE', year: '2022'),
      (id: 'JAUND', query: 'icterícia neonatal', answer: 'ICTERÍCIA NEONATAL — abordagem clínica', authority: 'NICE', year: '2023'),
      (id: 'NSEPSIS', query: 'sepse neonatal', answer: 'INFECÇÃO / SEPSE NEONATAL', authority: 'NICE', year: '2026'),
      (id: 'POB', query: 'obesidade infantil', answer: 'OBESIDADE PEDIÁTRICA — abordagem clínica', authority: 'NICE', year: '2026'),
      (id: 'ADHD', query: 'TDAH', answer: 'TDAH / ADHD — abordagem clínica', authority: 'NICE', year: '2025'),
    ];

    test('os 15 temas do Batch10 resolvem curadoria com >=3 URLs HTTPS', () {
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

    test('pré-eclâmpsia vence hipertensão arterial genérica', () {
      final text = joined(resolve(
        'hipertensão na gestação com pré-eclâmpsia',
        'PRÉ-ECLÂMPSIA — abordagem clínica',
      ));
      expect(text, contains('Hypertension in Pregnancy'));
      expect(text, contains('Pre-eclampsia'));
      expect(text, isNot(contains('High Blood Pressure Guideline')));
    });

    test('diabetes gestacional vence diabetes genérico', () {
      final text = joined(resolve(
        'diabetes gestacional',
        'DIABETES GESTACIONAL — abordagem clínica',
      ));
      expect(text, contains('Management of Diabetes in Pregnancy'));
      expect(text, contains('2026'));
    });

    test('obesidade infantil vence obesidade farmacológica adulta', () {
      final text = joined(resolve(
        'obesidade infantil',
        'OBESIDADE PEDIÁTRICA — abordagem clínica',
      ));
      expect(text, contains('NG246'));
      expect(text, contains('2026'));
      expect(text, isNot(contains('AGA — Pharmacological Interventions')));
    });

    test('ITU pediátrica vence ITU genérica', () {
      final text = joined(resolve(
        'ITU pediátrica',
        'INFECÇÃO URINÁRIA PEDIÁTRICA',
      ));
      expect(text, contains('Under 16s'));
      expect(text, contains('NG224'));
    });

    test('sepse neonatal vence sepse genérica', () {
      final text = joined(resolve(
        'sepse neonatal',
        'INFECÇÃO / SEPSE NEONATAL',
      ));
      expect(text, contains('Neonatal Infection'));
      expect(text, contains('2026'));
    });

    test('Batch01 a Batch10 permanecem curated-only no mesmo resolver', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      for (var i = 1; i <= 10; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }

      expect(source, contains("case 'preeclampsia_eclampsia_nice_2023':"));
      expect(source, contains("case 'adhd_nice_current':"));
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
