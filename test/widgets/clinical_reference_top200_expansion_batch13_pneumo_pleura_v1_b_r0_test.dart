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

  group('Top200 Expansion Batch13 pneumology pleura V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String year,
    })>[
      (
        id: 'SP',
        query: 'pneumotórax espontâneo',
        answer: 'PNEUMOTÓRAX ESPONTÂNEO — abordagem clínica',
        authority: 'ERS/EACTS/ESTS',
        year: '2024',
      ),
      (
        id: 'HTX',
        query: 'hemotórax',
        answer: 'HEMOTÓRAX — abordagem clínica',
        authority: 'EAST',
        year: 'Hemothorax',
      ),
      (
        id: 'PE',
        query: 'derrame pleural',
        answer: 'DERRAME PLEURAL — abordagem clínica',
        authority: 'BTS',
        year: '2023',
      ),
      (
        id: 'EMP',
        query: 'empiema pleural',
        answer: 'EMPIEMA PLEURAL — abordagem clínica',
        authority: 'BTS',
        year: '2023',
      ),
      (
        id: 'LA',
        query: 'abscesso pulmonar',
        answer: 'ABSCESSO PULMONAR — abordagem clínica',
        authority: 'BTS',
        year: '2023',
      ),
      (
        id: 'ASP',
        query: 'pneumonia aspirativa',
        answer: 'PNEUMONIA ASPIRATIVA — abordagem clínica',
        authority: 'BTS',
        year: '2023',
      ),
      (
        id: 'AB',
        query: 'bronquite aguda',
        answer: 'BRONQUITE AGUDA — abordagem clínica',
        authority: 'CDC',
        year: 'Acute',
      ),
      (
        id: 'CC',
        query: 'tosse crônica',
        answer: 'TOSSE CRÔNICA — abordagem clínica',
        authority: 'ERS',
        year: '2020',
      ),
      (
        id: 'SARC',
        query: 'sarcoidose pulmonar',
        answer: 'SARCOIDOSE PULMONAR — abordagem clínica',
        authority: 'ERS',
        year: '2021',
      ),
      (
        id: 'CF',
        query: 'fibrose cística',
        answer: 'FIBROSE CÍSTICA — abordagem clínica',
        authority: 'ECFS',
        year: '2024',
      ),
    ];

    test('10/10 temas resolvem curadoria com 3–4 URLs HTTPS', () {
      expect(cases.length, 10);
      for (final c in cases) {
        final result = resolve(c.query, c.answer);
        final text = joined(result);
        final urlLines =
            result.lines.where((line) => line.contains('https://')).toList();

        expect(text, contains(c.authority), reason: c.id);
        expect(text, contains(c.year), reason: c.id);
        expect(urlLines.length, greaterThanOrEqualTo(3), reason: c.id);
        expect(urlLines.length, lessThanOrEqualTo(4), reason: c.id);

        for (final line in urlLines) {
          final url = line.substring(line.indexOf('https://')).trim();
          final uri = Uri.tryParse(url);
          expect(uri, isNotNull, reason: '${c.id}:$url');
          expect(uri!.scheme, 'https', reason: '${c.id}:$url');
          expect(uri.host, isNotEmpty, reason: '${c.id}:$url');
        }
      }
    });

    test('aliases PT ES EN mantêm identidade temática', () {
      final probes = <({
        String query,
        String answer,
        String marker,
      })>[
        (
          query: 'neumotórax espontáneo',
          answer: 'NEUMOTÓRAX ESPONTÁNEO',
          marker: 'Spontaneous Pneumothorax',
        ),
        (
          query: 'spontaneous pneumothorax',
          answer: 'SPONTANEOUS PNEUMOTHORAX',
          marker: 'Spontaneous Pneumothorax',
        ),
        (
          query: 'hemothorax',
          answer: 'HEMOTHORAX',
          marker: 'Hemothorax',
        ),
        (
          query: 'pleural effusion',
          answer: 'PLEURAL EFFUSION',
          marker: 'Pleural Disease',
        ),
        (
          query: 'pleural empyema',
          answer: 'PLEURAL EMPYEMA',
          marker: 'Pleural Infection',
        ),
        (
          query: 'lung abscess',
          answer: 'LUNG ABSCESS',
          marker: 'Aspiration Pneumonia',
        ),
        (
          query: 'aspiration pneumonia',
          answer: 'ASPIRATION PNEUMONIA',
          marker: 'Aspiration Pneumonia',
        ),
        (
          query: 'acute bronchitis',
          answer: 'ACUTE BRONCHITIS',
          marker: 'CDC',
        ),
        (
          query: 'chronic cough',
          answer: 'CHRONIC COUGH',
          marker: 'Chronic Cough',
        ),
        (
          query: 'pulmonary sarcoidosis',
          answer: 'PULMONARY SARCOIDOSIS',
          marker: 'Sarcoidosis',
        ),
        (
          query: 'cystic fibrosis',
          answer: 'CYSTIC FIBROSIS',
          marker: 'ECFS',
        ),
      ];

      for (final p in probes) {
        final result = resolve(p.query, p.answer, lang: 'en');
        expect(joined(result), contains(p.marker), reason: p.query);
        expect(
          result.lines.where((line) => line.contains('https://')).length,
          greaterThanOrEqualTo(3),
          reason: p.query,
        );
      }
    });

    test('precedência específica protege colisões respiratórias', () {
      expect(
        joined(resolve(
          'pneumonia aspirativa',
          'PNEUMONIA ASPIRATIVA',
        )),
        contains('Aspiration Pneumonia'),
      );

      expect(
        joined(resolve(
          'abscesso pulmonar após aspiração',
          'ABSCESSO PULMONAR',
        )),
        contains('Aspiration Pneumonia'),
      );

      expect(
        joined(resolve(
          'empiema pleural com derrame pleural',
          'EMPIEMA PLEURAL',
        )),
        contains('Pleural Infection'),
      );

      final effusion = joined(resolve(
        'derrame pleural',
        'DERRAME PLEURAL',
      ));
      expect(effusion, contains('Pleural Disease'));
      expect(effusion, isNot(contains('Pleural Infection/Empyema')));

      expect(
        joined(resolve(
          'tosse crônica',
          'TOSSE CRÔNICA',
        )),
        contains('Chronic Cough'),
      );

      final cysticFibrosisWithChronicCough = joined(resolve(
        'fibrose cística com tosse crônica',
        'FIBROSE CÍSTICA COM TOSSE CRÔNICA',
      ));
      expect(cysticFibrosisWithChronicCough, contains('ECFS'));
      expect(
        cysticFibrosisWithChronicCough,
        isNot(contains(
            'Guidelines on the Diagnosis and Treatment of Chronic Cough')),
      );

      expect(
        joined(resolve(
          'derrame pleural',
          'DERRAME PLEURAL',
        )),
        contains('Pleural Disease'),
      );

      expect(
        joined(resolve(
          'empiema pleural com derrame pleural',
          'EMPIEMA PLEURAL',
        )),
        contains('Pleural Infection'),
      );

      final massiveHemothorax = joined(resolve(
        'hemotórax maciço traumático',
        'HEMOTÓRAX MACIÇO',
      ));
      expect(massiveHemothorax, contains('ATLS 11'));
      expect(massiveHemothorax, isNot(contains('EAST — Practice Management')));
    });

    test('Batch01–13 permanecem curated-only', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      for (var i = 1; i <= 10; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }

      expect(
          source, contains('_top200ExpansionBatch11Domains.contains(domain)'));
      expect(
          source, contains('_top200ExpansionBatch12Domains.contains(domain)'));
      expect(
          source, contains('_top200ExpansionBatch13Domains.contains(domain)'));

      for (final domain in <String>[
        'spontaneous_pneumothorax_ers_bts_2024',
        'hemothorax_trauma_guidelines',
        'pleural_effusion_bts_2023',
        'pleural_empyema_bts_2023',
        'lung_abscess_lower_respiratory_guidance',
        'aspiration_pneumonia_bts_2023',
        'acute_bronchitis_antibiotic_stewardship',
        'chronic_cough_ers_bts',
        'pulmonary_sarcoidosis_ers_ats',
        'cystic_fibrosis_ecfs_cff_2024',
      ]) {
        expect(source, contains("case '$domain':"), reason: domain);
      }

      expect(source, contains('limit: 4'));
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
