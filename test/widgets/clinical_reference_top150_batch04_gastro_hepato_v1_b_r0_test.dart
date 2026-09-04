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

  group('Top150 Batch04 gastro hepato V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String year,
    })>[
      (id: 'GERD', query: 'refluxo gastroesofágico', answer: 'REFLUXO GASTROESOFÁGICO — abordagem clínica', authority: 'ACG', year: '2022'),
      (id: 'BARRETT', query: 'esôfago de Barrett', answer: 'ESÔFAGO DE BARRETT — abordagem clínica', authority: 'ACG', year: '2022'),
      (id: 'EOE', query: 'esofagite eosinofílica', answer: 'ESOFAGITE EOSINOFÍLICA — abordagem clínica', authority: 'ACG', year: '2025'),
      (id: 'UC', query: 'retocolite ulcerativa', answer: 'RETOCOLITE ULCERATIVA — abordagem clínica', authority: 'ACG', year: '2025'),
      (id: 'CROHN', query: 'doença de Crohn', answer: 'DOENÇA DE CROHN — abordagem clínica', authority: 'ACG', year: '2025'),
      (id: 'CELIAC', query: 'doença celíaca', answer: 'DOENÇA CELÍACA — abordagem clínica', authority: 'ACG', year: '2023'),
      (id: 'IBS', query: 'síndrome do intestino irritável', answer: 'SÍNDROME DO INTESTINO IRRITÁVEL — abordagem clínica', authority: 'ACG', year: '2021'),
      (id: 'CIC', query: 'constipação idiopática crônica', answer: 'CONSTIPAÇÃO IDIOPÁTICA CRÔNICA — abordagem clínica', authority: 'AGA/ACG', year: '2023'),
      (id: 'MASLD', query: 'MASLD e MASH', answer: 'MASLD / MASH — abordagem clínica', authority: 'AASLD', year: '2025'),
      (id: 'PORTAL', query: 'cirrose com hipertensão portal', answer: 'CIRROSE E HIPERTENSÃO PORTAL — abordagem clínica', authority: 'AASLD', year: '2024'),
      (id: 'ASCITES', query: 'ascite cirrótica e peritonite bacteriana espontânea', answer: 'ASCITE / PBE / HRS — abordagem clínica', authority: 'AASLD', year: '2021'),
      (id: 'HE', query: 'encefalopatia hepática', answer: 'ENCEFALOPATIA HEPÁTICA — abordagem clínica', authority: 'ACG', year: '2026'),
      (id: 'HCC', query: 'carcinoma hepatocelular', answer: 'CARCINOMA HEPATOCELULAR — abordagem clínica', authority: 'AASLD', year: '2023'),
      (id: 'HBV', query: 'hepatite B crônica', answer: 'HEPATITE B CRÔNICA — abordagem clínica', authority: 'AASLD/IDSA', year: '2025'),
      (id: 'HCV', query: 'hepatite C crônica', answer: 'HEPATITE C — abordagem clínica', authority: 'AASLD/IDSA', year: '2023'),
    ];

    test('os 15 temas do Batch04 resolvem curadoria com >=3 URLs HTTPS', () {
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

    test('hipertensão portal vence hipertensão arterial sistêmica', () {
      final portal = joined(resolve(
        'cirrose com hipertensão portal',
        'CIRROSE E HIPERTENSÃO PORTAL — abordagem clínica',
      ));

      expect(portal, contains('AASLD'));
      expect(portal, contains('Portal Hypertension'));
      expect(portal, isNot(contains('High Blood Pressure Guideline')));
    });

    test('domínios hepatológicos específicos vencem cirrose genérica', () {
      final he = joined(resolve(
        'encefalopatia hepática em paciente com cirrose',
        'ENCEFALOPATIA HEPÁTICA — abordagem clínica em cirrose',
      ));
      expect(he, contains('Hepatic Encephalopathy'));
      expect(he, contains('2026'));

      final hcc = joined(resolve(
        'carcinoma hepatocelular em cirrose',
        'CARCINOMA HEPATOCELULAR — abordagem clínica em cirrose',
      ));
      expect(hcc, contains('Hepatocellular Carcinoma'));
      expect(hcc, contains('2023'));
    });

    test('Batch01 a Batch04 permanecem curated-only no mesmo resolver', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      expect(source, contains('_top150Batch01Domains.contains(domain)'));
      expect(source, contains('_top150Batch02Domains.contains(domain)'));
      expect(source, contains('_top150Batch03Domains.contains(domain)'));
      expect(source, contains('_top150Batch04Domains.contains(domain)'));
      expect(source, contains("case 'gastroesophageal_reflux_disease':"));
      expect(source, contains("case 'hepatitis_c':"));
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
