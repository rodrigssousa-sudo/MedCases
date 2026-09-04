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

  group('Top150 Batch06 infectious V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String year,
    })>[
      (id: 'HIVART', query: 'tratamento antirretroviral HIV', answer: 'HIV — TRATAMENTO ANTIRRETROVIRAL', authority: 'NIH/DHHS', year: '2026'),
      (id: 'HIVOI', query: 'infecções oportunistas no HIV', answer: 'HIV — INFECÇÕES OPORTUNISTAS', authority: 'NIH/CDC/HIVMA', year: '2026'),
      (id: 'PREP', query: 'PrEP para HIV', answer: 'PREP PARA HIV — abordagem clínica', authority: 'CDC', year: '2026'),
      (id: 'PEP', query: 'PEP para HIV', answer: 'PEP PARA HIV — abordagem clínica', authority: 'CDC', year: '2025'),
      (id: 'TB', query: 'tuberculose pulmonar', answer: 'TUBERCULOSE — abordagem clínica', authority: 'WHO', year: '2025'),
      (id: 'MAL', query: 'malária', answer: 'MALÁRIA — abordagem clínica', authority: 'WHO', year: '2025'),
      (id: 'DENGUE', query: 'dengue', answer: 'DENGUE — abordagem clínica', authority: 'WHO', year: '2025'),
      (id: 'SYPH', query: 'sífilis', answer: 'SÍFILIS — abordagem clínica', authority: 'CDC', year: '2021'),
      (id: 'GONO', query: 'gonorreia', answer: 'GONORREIA — abordagem clínica', authority: 'CDC', year: '2021'),
      (id: 'CHLAM', query: 'clamídia', answer: 'CLAMÍDIA — abordagem clínica', authority: 'CDC', year: '2021'),
      (id: 'HSV', query: 'herpes genital', answer: 'HERPES GENITAL — abordagem clínica', authority: 'CDC', year: '2021'),
      (id: 'PID', query: 'doença inflamatória pélvica', answer: 'DOENÇA INFLAMATÓRIA PÉLVICA — abordagem clínica', authority: 'CDC', year: '2021'),
      (id: 'CDI', query: 'Clostridioides difficile', answer: 'CLOSTRIDIOIDES DIFFICILE — abordagem clínica', authority: 'SHEA/IDSA', year: '2021'),
      (id: 'COVID', query: 'COVID-19', answer: 'COVID-19 — abordagem clínica', authority: 'IDSA', year: '2025'),
      (id: 'FLU', query: 'influenza', answer: 'INFLUENZA — abordagem clínica', authority: 'CDC', year: '2026'),
    ];

    test('os 15 temas do Batch06 resolvem curadoria com >=3 URLs HTTPS', () {
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

    test('PrEP, PEP e OI vencem HIV genérico', () {
      final prep = joined(resolve(
        'PrEP para HIV',
        'PREP PARA HIV — prevenção',
      ));
      expect(prep, contains('Clinical Guidance for PrEP'));
      expect(prep, contains('2026'));

      final pep = joined(resolve(
        'PEP para HIV',
        'PEP PARA HIV — pós-exposição',
      ));
      expect(pep, contains('Postexposure Prophylaxis'));
      expect(pep, contains('2025'));

      final oi = joined(resolve(
        'infecções oportunistas no HIV',
        'HIV — INFECÇÕES OPORTUNISTAS',
      ));
      expect(oi, contains('Opportunistic Infections'));
      expect(oi, contains('2026'));
    });

    test('Batch01 a Batch06 permanecem curated-only no mesmo resolver', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      expect(source, contains('_top150Batch01Domains.contains(domain)'));
      expect(source, contains('_top150Batch02Domains.contains(domain)'));
      expect(source, contains('_top150Batch03Domains.contains(domain)'));
      expect(source, contains('_top150Batch04Domains.contains(domain)'));
      expect(source, contains('_top150Batch05Domains.contains(domain)'));
      expect(source, contains('_top150Batch06Domains.contains(domain)'));
      expect(source, contains("case 'hiv_antiretroviral_therapy':"));
      expect(source, contains("case 'influenza':"));
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
