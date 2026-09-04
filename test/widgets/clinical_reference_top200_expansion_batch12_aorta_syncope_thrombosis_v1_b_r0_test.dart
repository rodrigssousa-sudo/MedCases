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

  group('Top200 Expansion Batch12 aorta syncope thrombosis V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String year,
    })>[
      (
        id: 'AAA',
        query: 'aneurisma de aorta abdominal',
        answer: 'ANEURISMA DE AORTA ABDOMINAL — abordagem clínica',
        authority: 'ESC',
        year: '2024',
      ),
      (
        id: 'TAA',
        query: 'aneurisma de aorta torácica',
        answer: 'ANEURISMA DE AORTA TORÁCICA — abordagem clínica',
        authority: 'ESC',
        year: '2024',
      ),
      (
        id: 'DVT',
        query: 'trombose venosa profunda',
        answer: 'TROMBOSE VENOSA PROFUNDA — abordagem clínica',
        authority: 'ASH',
        year: '2020',
      ),
      (
        id: 'CVD',
        query: 'insuficiência venosa crônica',
        answer: 'INSUFICIÊNCIA VENOSA CRÔNICA — abordagem clínica',
        authority: 'ESVS',
        year: '2022',
      ),
      (
        id: 'SVT',
        query: 'tromboflebite superficial',
        answer: 'TROMBOFLEBITE SUPERFICIAL — abordagem clínica',
        authority: 'ESVS',
        year: '2021',
      ),
      (
        id: 'VVS',
        query: 'síncope vasovagal',
        answer: 'SÍNCOPE VASOVAGAL — abordagem clínica',
        authority: 'ESC',
        year: '2018',
      ),
      (
        id: 'OH',
        query: 'hipotensão ortostática',
        answer: 'HIPOTENSÃO ORTOSTÁTICA — abordagem clínica',
        authority: 'AHA',
        year: '2024',
      ),
      (
        id: 'POTS',
        query: 'síndrome de taquicardia postural ortostática POTS',
        answer: 'POTS — abordagem clínica',
        authority: 'HRS',
        year: '2015',
      ),
      (
        id: 'RF',
        query: 'febre reumática e cardiopatia reumática',
        answer: 'FEBRE REUMÁTICA — abordagem clínica',
        authority: 'WHO',
        year: '2024',
      ),
      (
        id: 'HTNE',
        query: 'emergência hipertensiva',
        answer: 'EMERGÊNCIA HIPERTENSIVA — abordagem clínica',
        authority: 'AHA',
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
          query: 'aneurisma aórtico abdominal',
          answer: 'ANEURISMA AÓRTICO ABDOMINAL',
          marker: 'Peripheral Arterial and Aortic Diseases',
        ),
        (
          query: 'abdominal aortic aneurysm',
          answer: 'ABDOMINAL AORTIC ANEURYSM',
          marker: 'Peripheral Arterial and Aortic Diseases',
        ),
        (
          query: 'aneurisma aórtico torácico',
          answer: 'ANEURISMA AÓRTICO TORÁCICO',
          marker: 'Aortic Disease',
        ),
        (
          query: 'thoracic aortic aneurysm',
          answer: 'THORACIC AORTIC ANEURYSM',
          marker: 'Aortic Disease',
        ),
        (
          query: 'trombosis venosa profunda',
          answer: 'TROMBOSIS VENOSA PROFUNDA',
          marker: 'Deep Vein Thrombosis',
        ),
        (
          query: 'deep vein thrombosis',
          answer: 'DEEP VEIN THROMBOSIS',
          marker: 'Deep Vein Thrombosis',
        ),
        (
          query: 'insuficiencia venosa crónica',
          answer: 'INSUFICIENCIA VENOSA CRÓNICA',
          marker: 'Chronic Venous Disease',
        ),
        (
          query: 'chronic venous insufficiency',
          answer: 'CHRONIC VENOUS INSUFFICIENCY',
          marker: 'Chronic Venous Disease',
        ),
        (
          query: 'tromboflebitis superficial',
          answer: 'TROMBOFLEBITIS SUPERFICIAL',
          marker: 'superficial vein thrombosis',
        ),
        (
          query: 'superficial vein thrombosis',
          answer: 'SUPERFICIAL VEIN THROMBOSIS',
          marker: 'superficial vein thrombosis',
        ),
        (
          query: 'síncope refleja',
          answer: 'SÍNCOPE REFLEJA',
          marker: 'Syncope',
        ),
        (
          query: 'vasovagal syncope',
          answer: 'VASOVAGAL SYNCOPE',
          marker: 'Syncope',
        ),
        (
          query: 'hipotensión ortostática',
          answer: 'HIPOTENSIÓN ORTOSTÁTICA',
          marker: 'Orthostatic Hypotension',
        ),
        (
          query: 'orthostatic hypotension',
          answer: 'ORTHOSTATIC HYPOTENSION',
          marker: 'Orthostatic Hypotension',
        ),
        (
          query: 'síndrome de taquicardia postural ortostática',
          answer: 'POTS',
          marker: 'Postural Tachycardia',
        ),
        (
          query: 'postural orthostatic tachycardia syndrome',
          answer: 'POTS',
          marker: 'Postural Tachycardia',
        ),
        (
          query: 'fiebre reumática',
          answer: 'FIEBRE REUMÁTICA',
          marker: 'WHO',
        ),
        (
          query: 'rheumatic heart disease',
          answer: 'RHEUMATIC HEART DISEASE',
          marker: 'WHO',
        ),
        (
          query: 'crisis hipertensiva',
          answer: 'CRISIS HIPERTENSIVA',
          marker: 'Acute Care Setting',
        ),
        (
          query: 'hypertensive emergency',
          answer: 'HYPERTENSIVE EMERGENCY',
          marker: 'Acute Care Setting',
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
      final pots = joined(resolve(
        'POTS síndrome de taquicardia postural ortostática',
        'POTS',
      ));
      expect(pots, contains('Postural Tachycardia'));

      final oh = joined(resolve(
        'hipotensão ortostática',
        'HIPOTENSÃO ORTOSTÁTICA',
      ));
      expect(oh, contains('Orthostatic Hypotension'));

      final htnEmergency = joined(resolve(
        'emergência hipertensiva com lesão aguda de órgão-alvo',
        'EMERGÊNCIA HIPERTENSIVA',
      ));
      expect(htnEmergency, contains('Acute Care Setting'));
      expect(htnEmergency, contains('2024'));

      final genericHtn = joined(resolve(
        'hipertensão arterial sistêmica',
        'HIPERTENSÃO ARTERIAL',
      ));
      expect(genericHtn, isNot(contains('Acute Care Setting')));

      final svt = joined(resolve(
        'trombose venosa superficial',
        'TROMBOSE VENOSA SUPERFICIAL',
      ));
      expect(svt, contains('superficial vein thrombosis'));

      final dvt = joined(resolve(
        'trombose venosa profunda',
        'TROMBOSE VENOSA PROFUNDA',
      ));
      expect(dvt, contains('Deep Vein Thrombosis'));

      final aaa = joined(resolve(
        'aneurisma de aorta abdominal',
        'ANEURISMA DE AORTA ABDOMINAL',
      ));
      expect(aaa, contains('Aortic Diseases'));

      final taa = joined(resolve(
        'aneurisma de aorta torácica',
        'ANEURISMA DE AORTA TORÁCICA',
      ));
      expect(taa, contains('Aortic Disease'));
    });

    test('Batch01–12 permanecem curated-only', () {
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
      expect(
        source,
        contains('_top200ExpansionBatch12Domains.contains(domain)'),
      );

      for (final domain in <String>[
        'abdominal_aortic_aneurysm_esc_2024',
        'thoracic_aortic_aneurysm_esc_2024',
        'deep_vein_thrombosis_ash',
        'chronic_venous_disease_esvs_2022',
        'superficial_venous_thrombosis_esvs_2021',
        'vasovagal_reflex_syncope',
        'orthostatic_hypotension_aha_2024',
        'postural_orthostatic_tachycardia_syndrome',
        'rheumatic_fever_rheumatic_heart_disease_who_2024',
        'hypertensive_emergency_aha_2024',
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
