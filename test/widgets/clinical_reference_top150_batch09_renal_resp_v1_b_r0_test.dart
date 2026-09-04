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

  group('Top150 Batch09 renal respiratory V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String year,
    })>[
      (id: 'AKI', query: 'lesão renal aguda', answer: 'LESÃO RENAL AGUDA / AKI — abordagem clínica', authority: 'KDIGO', year: '2012'),
      (id: 'IGA', query: 'nefropatia por IgA', answer: 'NEFROPATIA POR IgA — abordagem clínica', authority: 'KDIGO', year: '2025'),
      (id: 'ADPKD', query: 'ADPKD', answer: 'DOENÇA RENAL POLICÍSTICA AUTOSSÔMICA DOMINANTE', authority: 'KDIGO', year: '2025'),
      (id: 'ANEMIACKD', query: 'anemia na doença renal crônica', answer: 'ANEMIA NA DRC — abordagem clínica', authority: 'KDIGO', year: '2026'),
      (id: 'NS', query: 'síndrome nefrótica infantil', answer: 'SÍNDROME NEFRÓTICA PEDIÁTRICA', authority: 'KDIGO', year: '2025'),
      (id: 'STONE', query: 'cálculo renal', answer: 'NEFROLITÍASE — abordagem clínica', authority: 'AUA', year: '2026'),
      (id: 'K', query: 'hipercalemia aguda', answer: 'HIPERCALEMIA — abordagem clínica', authority: 'UK Kidney Association', year: '2023'),
      (id: 'NA', query: 'hiponatremia', answer: 'HIPONATREMIA — abordagem clínica', authority: 'European', year: '2014'),
      (id: 'PH', query: 'hipertensão pulmonar', answer: 'HIPERTENSÃO PULMONAR — abordagem clínica', authority: 'ESC/ERS', year: '2022'),
      (id: 'BE', query: 'bronquiectasia', answer: 'BRONQUIECTASIA — abordagem clínica', authority: 'ERS', year: '2025'),
      (id: 'ARDS', query: 'síndrome do desconforto respiratório agudo', answer: 'SDRA / ARDS — abordagem clínica', authority: 'ATS', year: '2024'),
      (id: 'IPF', query: 'fibrose pulmonar idiopática', answer: 'FIBROSE PULMONAR IDIOPÁTICA — abordagem clínica', authority: 'ATS/ERS/JRS/ALAT', year: '2022'),
      (id: 'OSA', query: 'apneia obstrutiva do sono', answer: 'APNEIA OBSTRUTIVA DO SONO — abordagem clínica', authority: 'NICE', year: '2025'),
      (id: 'OHS', query: 'síndrome de hipoventilação da obesidade', answer: 'HIPOVENTILAÇÃO DA OBESIDADE — abordagem clínica', authority: 'NICE', year: '2025'),
      (id: 'HP', query: 'pneumonite por hipersensibilidade', answer: 'PNEUMONITE POR HIPERSENSIBILIDADE — abordagem diagnóstica', authority: 'ATS/JRS/ALAT', year: '2020'),
    ];

    test('os 15 temas do Batch09 resolvem curadoria com >=3 URLs HTTPS', () {
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

    test('GCA não colide com IgA por substring de gigantes', () {
      final gca = joined(resolve(
        'arterite de células gigantes',
        'ARTERITE DE CÉLULAS GIGANTES — abordagem clínica',
      ));
      expect(gca, contains('ACR'));
      expect(gca, isNot(contains('IgA Nephropathy')));
    });

    test('IgA continua resolvendo sem aliases curtos perigosos', () {
      final iga = joined(resolve(
        'nefropatia por IgA',
        'NEFROPATIA POR IgA — abordagem clínica',
      ));
      expect(iga, contains('KDIGO'));
      expect(iga, contains('2025'));
    });

    test('anemia CKD e AKI vencem CKD genérica', () {
      final anemia = joined(resolve(
        'anemia na doença renal crônica',
        'ANEMIA NA DRC — abordagem clínica',
      ));
      expect(anemia, contains('Anemia in CKD'));
      expect(anemia, contains('2026'));

      final aki = joined(resolve(
        'lesão renal aguda',
        'AKI — lesão renal aguda',
      ));
      expect(aki, contains('Acute Kidney Injury'));
      expect(aki, contains('2012'));
    });

    test('AUA stones 2026 usa as três partes publicadas e atuais', () {
      final stones = joined(resolve(
        'cálculo renal',
        'NEFROLITÍASE — abordagem clínica',
      ));
      expect(stones, contains('AUA'));
      expect(stones, contains('2026'));
      expect(stones, contains('41263323'));
      expect(stones, contains('41263322'));
      expect(stones, contains('41263325'));
    });

    test('hipertensão pulmonar vence hipertensão arterial sistêmica', () {
      final ph = joined(resolve(
        'hipertensão pulmonar',
        'HIPERTENSÃO PULMONAR — abordagem clínica',
      ));
      expect(ph, contains('ESC/ERS'));
      expect(ph, contains('Pulmonary Hypertension'));
      expect(ph, isNot(contains('High Blood Pressure Guideline')));
    });

    test('OHS vence OSA genérica quando hipoventilação por obesidade é explícita', () {
      final ohs = joined(resolve(
        'síndrome de hipoventilação da obesidade',
        'OBESITY HYPOVENTILATION SYNDROME',
      ));
      expect(ohs, contains('Obesity Hypoventilation Syndrome'));
      expect(ohs, contains('2025'));
    });

    test('AKI 2026 draft nunca é rotulado como guideline final', () {
      final aki = joined(resolve(
        'acute kidney injury',
        'AKI / AKD — abordagem clínica',
      ));
      expect(aki, contains('DRAFT, not final'));
      expect(aki, contains('2012 final'));
    });

    test('Batch01 a Batch09 permanecem curated-only no mesmo resolver', () {
      final source = File('lib/screens/ai/widgets/clinical_reference_resolver.dart').readAsStringSync();
      for (var i = 1; i <= 9; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }
      expect(source, contains("case 'acute_kidney_injury_aki_akd':"));
      expect(source, contains("case 'hypersensitivity_pneumonitis_ats_2020':"));
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
