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

  group('Top150 Batch05 endocrine V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String year,
    })>[
      (id: 'HYPO', query: 'hipotireoidismo', answer: 'HIPOTIREOIDISMO — abordagem clínica', authority: 'ATA', year: '2014'),
      (id: 'HYPER', query: 'hipertireoidismo por Graves', answer: 'HIPERTIREOIDISMO / GRAVES — abordagem clínica', authority: 'ATA', year: '2016'),
      (id: 'DTC', query: 'câncer diferenciado de tireoide', answer: 'CÂNCER DIFERENCIADO DE TIREOIDE — abordagem clínica', authority: 'ATA', year: '2025'),
      (id: 'PREG', query: 'doença tireoidiana na gravidez', answer: 'TIREOIDE E GESTAÇÃO — abordagem clínica', authority: 'ATA', year: '2026'),
      (id: 'PAI', query: 'insuficiência adrenal primária', answer: 'INSUFICIÊNCIA ADRENAL PRIMÁRIA — abordagem clínica', authority: 'Endocrine Society', year: '2016'),
      (id: 'CUSH', query: 'síndrome de Cushing', answer: 'SÍNDROME DE CUSHING — abordagem clínica', authority: 'Endocrine Society', year: '2015'),
      (id: 'PA', query: 'hiperaldosteronismo primário', answer: 'HIPERALDOSTERONISMO PRIMÁRIO — abordagem clínica', authority: 'Endocrine Society', year: '2025'),
      (id: 'PHEO', query: 'feocromocitoma e paraganglioma', answer: 'FEOCROMOCITOMA / PARAGANGLIOMA — abordagem clínica', authority: 'Endocrine Society', year: '2014'),
      (id: 'OSTEO', query: 'osteoporose pós-menopausa', answer: 'OSTEOPOROSE — abordagem clínica', authority: 'Endocrine Society', year: '2020'),
      (id: 'PHPT', query: 'hiperparatireoidismo primário', answer: 'HIPERPARATIREOIDISMO PRIMÁRIO — abordagem clínica', authority: 'Fifth International Workshop', year: '2022'),
      (id: 'HYPOPT', query: 'hipoparatireoidismo', answer: 'HIPOPARATIREOIDISMO — abordagem clínica', authority: 'International Task Force', year: '2022'),
      (id: 'OBES', query: 'obesidade farmacoterapia', answer: 'OBESIDADE — abordagem farmacológica', authority: 'AGA', year: '2022'),
      (id: 'PCOS', query: 'síndrome dos ovários policísticos', answer: 'SOP / PCOS — abordagem clínica', authority: 'International Evidence-based Guideline', year: '2023'),
      (id: 'ACRO', query: 'acromegalia', answer: 'ACROMEGALIA — abordagem clínica', authority: 'Endocrine Society', year: '2014'),
      (id: 'PRL', query: 'prolactinoma com hiperprolactinemia', answer: 'HIPERPROLACTINEMIA / PROLACTINOMA — abordagem clínica', authority: 'Pituitary Society', year: '2023'),
    ];

    test('os 15 temas do Batch05 resolvem curadoria com >=3 URLs HTTPS', () {
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

    test('causas endócrinas específicas vencem hipertensão genérica', () {
      final pa = joined(resolve(
        'hipertensão por hiperaldosteronismo primário',
        'HIPERALDOSTERONISMO PRIMÁRIO — hipertensão secundária',
      ));
      expect(pa, contains('Primary Aldosteronism'));
      expect(pa, contains('2025'));
      expect(pa, isNot(contains('High Blood Pressure Guideline')));

      final pheo = joined(resolve(
        'hipertensão por feocromocitoma',
        'FEOCROMOCITOMA — hipertensão secundária',
      ));
      expect(pheo, contains('Pheochromocytoma'));
      expect(pheo, isNot(contains('High Blood Pressure Guideline')));
    });

    test('tireoide na gestação vence tireoide genérica', () {
      final pregnancy = joined(resolve(
        'hipotireoidismo na gravidez',
        'HIPOTIREOIDISMO NA GRAVIDEZ — abordagem clínica',
      ));
      expect(pregnancy, contains('2026'));
      expect(pregnancy, contains('Pregnancy'));
    });

    test('prolactinoma usa consenso Pituitary Society 2023 como primário', () {
      final prl = joined(resolve(
        'prolactinoma com hiperprolactinemia',
        'HIPERPROLACTINEMIA / PROLACTINOMA — abordagem clínica',
      ));

      expect(prl, contains('Pituitary Society'));
      expect(prl, contains('2023'));
      expect(prl, contains('s41574-023-00886-5'));
      expect(prl, contains('Endocrine Society'));
    });

    test('Batch01 a Batch05 permanecem curated-only no mesmo resolver', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      expect(source, contains('_top150Batch01Domains.contains(domain)'));
      expect(source, contains('_top150Batch02Domains.contains(domain)'));
      expect(source, contains('_top150Batch03Domains.contains(domain)'));
      expect(source, contains('_top150Batch04Domains.contains(domain)'));
      expect(source, contains('_top150Batch05Domains.contains(domain)'));
      expect(source, contains("case 'hypothyroidism':"));
      expect(source, contains("case 'hyperprolactinemia_prolactinoma':"));
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
