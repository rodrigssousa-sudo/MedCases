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

  group('Top200 Expansion Batch11 cardio V1-B-R2', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String year,
    })>[
      (
        id: 'CCD',
        query: 'síndrome coronariana crônica',
        answer: 'SÍNDROME CORONARIANA CRÔNICA — abordagem clínica',
        authority: 'ESC',
        year: '2024',
      ),
      (
        id: 'PSVT',
        query: 'taquicardia supraventricular paroxística',
        answer: 'TAQUICARDIA SUPRAVENTRICULAR PAROXÍSTICA — abordagem clínica',
        authority: 'ESC',
        year: '2019',
      ),
      (
        id: 'AFL',
        query: 'flutter atrial',
        answer: 'FLUTTER ATRIAL — abordagem clínica',
        authority: 'ESC',
        year: '2024',
      ),
      (
        id: 'SVT',
        query: 'taquicardia ventricular sustentada',
        answer: 'TAQUICARDIA VENTRICULAR SUSTENTADA — abordagem clínica',
        authority: 'ESC',
        year: '2022',
      ),
      (
        id: 'AVB',
        query: 'bloqueio atrioventricular',
        answer: 'BLOQUEIO ATRIOVENTRICULAR — abordagem clínica',
        authority: 'ACC/AHA/HRS',
        year: '2018',
      ),
      (
        id: 'WPW',
        query: 'síndrome de Wolff-Parkinson-White',
        answer: 'SÍNDROME DE WOLFF-PARKINSON-WHITE — abordagem clínica',
        authority: 'ESC',
        year: '2019',
      ),
      (
        id: 'LQTS',
        query: 'síndrome do QT longo',
        answer: 'SÍNDROME DO QT LONGO — abordagem clínica',
        authority: 'ESC',
        year: '2022',
      ),
      (
        id: 'BRUGADA',
        query: 'síndrome de Brugada',
        answer: 'SÍNDROME DE BRUGADA — abordagem clínica',
        authority: 'ESC',
        year: '2022',
      ),
      (
        id: 'DCM',
        query: 'cardiomiopatia dilatada',
        answer: 'CARDIOMIOPATIA DILATADA — abordagem clínica',
        authority: 'ESC',
        year: '2023',
      ),
      (
        id: 'TAKOTSUBO',
        query: 'cardiomiopatia por estresse Takotsubo',
        answer: 'TAKOTSUBO — abordagem clínica',
        authority: 'International Expert Consensus',
        year: '2024',
      ),
    ];

    test('10/10 temas resolvem curadoria com >=3 URLs HTTPS', () {
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
          query: 'síndrome coronaria crónica',
          answer: 'SÍNDROME CORONARIA CRÓNICA',
          marker: 'Chronic Coronary',
        ),
        (
          query: 'chronic coronary syndrome',
          answer: 'CHRONIC CORONARY SYNDROME',
          marker: 'Chronic Coronary',
        ),
        (
          query: 'taquicardia paroxística supraventricular',
          answer: 'TAQUICARDIA PAROXÍSTICA SUPRAVENTRICULAR',
          marker: 'Supraventricular Tachycardia',
        ),
        (
          query: 'paroxysmal supraventricular tachycardia',
          answer: 'PAROXYSMAL SUPRAVENTRICULAR TACHYCARDIA',
          marker: 'Supraventricular Tachycardia',
        ),
        (
          query: 'aleteo auricular',
          answer: 'ALETEO AURICULAR',
          marker: 'atrial flutter',
        ),
        (
          query: 'atrial flutter',
          answer: 'ATRIAL FLUTTER',
          marker: 'atrial flutter',
        ),
        (
          query: 'taquicardia ventricular sostenida',
          answer: 'TAQUICARDIA VENTRICULAR SOSTENIDA',
          marker: 'Ventricular Arrhythmias',
        ),
        (
          query: 'sustained ventricular tachycardia',
          answer: 'SUSTAINED VENTRICULAR TACHYCARDIA',
          marker: 'Ventricular Arrhythmias',
        ),
        (
          query: 'bloqueo auriculoventricular',
          answer: 'BLOQUEO AURICULOVENTRICULAR',
          marker: 'Bradycardia and Cardiac Conduction',
        ),
        (
          query: 'atrioventricular block',
          answer: 'ATRIOVENTRICULAR BLOCK',
          marker: 'Bradycardia and Cardiac Conduction',
        ),
        (
          query: 'WPW syndrome',
          answer: 'WOLFF-PARKINSON-WHITE',
          marker: 'pre-excitation/WPW',
        ),
        (
          query: 'long QT syndrome',
          answer: 'LONG QT SYNDROME',
          marker: 'Long QT Syndrome',
        ),
        (
          query: 'Brugada syndrome',
          answer: 'BRUGADA SYNDROME',
          marker: 'Brugada Syndrome',
        ),
        (
          query: 'dilated cardiomyopathy',
          answer: 'DILATED CARDIOMYOPATHY',
          marker: 'Cardiomyopathies',
        ),
        (
          query: 'Takotsubo stress cardiomyopathy',
          answer: 'TAKOTSUBO STRESS CARDIOMYOPATHY',
          marker: '39417524',
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

    test('precedência específica protege colisões principais', () {
      expect(
        joined(resolve(
          'síndrome coronariana crônica',
          'SÍNDROME CORONARIANA CRÔNICA',
        )),
        contains('Chronic Coronary Syndromes'),
      );

      expect(
        joined(resolve(
          'síndrome coronariana aguda',
          'SÍNDROME CORONARIANA AGUDA',
        )),
        isNot(contains('Chronic Coronary Syndromes (2024)')),
      );

      expect(
        joined(resolve(
          'stable CAD',
          'STABLE CHRONIC CORONARY DISEASE',
          lang: 'en',
        )),
        contains('Chronic Coronary'),
      );

      expect(
        joined(resolve('CAD', 'CETOACIDOSE DIABÉTICA')),
        isNot(contains('Chronic Coronary Syndromes')),
      );

      expect(
        joined(resolve(
          'WPW com taquicardia supraventricular paroxística',
          'WOLFF-PARKINSON-WHITE',
        )),
        contains('pre-excitation/WPW'),
      );

      final dcm = joined(resolve(
        'cardiomiopatia dilatada com insuficiência cardíaca',
        'CARDIOMIOPATIA DILATADA',
      ));
      expect(dcm, contains('Cardiomyopathies'));
      expect(dcm, contains('2023'));

      expect(
        joined(resolve(
          'Takotsubo simulando síndrome coronariana aguda',
          'TAKOTSUBO',
        )),
        contains('39417524'),
      );
    });

    test('Batch01–10 + Batch11 permanecem curated-only', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      for (var i = 1; i <= 10; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }

      expect(
        source,
        contains('_top200ExpansionBatch11Domains.contains(domain)'),
      );

      for (final domain in <String>[
        'chronic_coronary_syndrome_esc_2024',
        'paroxysmal_supraventricular_tachycardia',
        'atrial_flutter',
        'sustained_ventricular_tachycardia',
        'atrioventricular_block',
        'wolff_parkinson_white_wpw',
        'long_qt_syndrome',
        'brugada_syndrome',
        'dilated_cardiomyopathy_esc_2023',
        'takotsubo_syndrome_consensus_2024',
      ]) {
        expect(source, contains("case '$domain':"), reason: domain);
      }

      expect(source, contains('limit: 4'));
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
