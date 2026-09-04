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

  group('Top200 Expansion Batch28 gynecology obstetrics V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String marker,
    })>[
      (
        id: 'FIB',
        query: 'mioma uterino sintomático',
        answer: 'MIOMA UTERINO',
        authority: 'ACOG',
        marker: '2025'
      ),
      (
        id: 'ADENO',
        query: 'adenomiose uterina',
        answer: 'ADENOMIOSE',
        authority: 'Asian Society',
        marker: '2023'
      ),
      (
        id: 'BV',
        query: 'vaginose bacteriana',
        answer: 'VAGINOSE BACTERIANA',
        authority: 'CDC',
        marker: 'Bacterial Vaginosis'
      ),
      (
        id: 'VVC',
        query: 'candidíase vulvovaginal',
        answer: 'CANDIDÍASE VULVOVAGINAL',
        authority: 'CDC',
        marker: 'Candidiasis'
      ),
      (
        id: 'TRICH',
        query: 'tricomoníase',
        answer: 'TRICOMONÍASE',
        authority: 'WHO',
        marker: 'Trichomonas'
      ),
      (
        id: 'GTD',
        query: 'doença trofoblástica gestacional',
        answer: 'DOENÇA TROFOBLÁSTICA GESTACIONAL',
        authority: 'FIGO',
        marker: '2025'
      ),
      (
        id: 'HG',
        query: 'hiperêmese gravídica',
        answer: 'HIPERÊMESE GRAVÍDICA',
        authority: 'RCOG',
        marker: '2024'
      ),
      (
        id: 'PREVIA',
        query: 'placenta prévia',
        answer: 'PLACENTA PRÉVIA',
        authority: 'RCOG',
        marker: '2026'
      ),
      (
        id: 'ABRUPT',
        query: 'descolamento prematuro de placenta',
        answer: 'DPP / ABRUPÇÃO PLACENTÁRIA',
        authority: 'RCOG',
        marker: 'Placental Abruption'
      ),
      (
        id: 'PROM',
        query: 'ruptura prematura de membranas',
        answer: 'PROM / PPROM',
        authority: 'ACOG',
        marker: '2026'
      ),
    ];

    test('10/10 temas resolvem curadoria com 3–4 URLs HTTPS', () {
      expect(cases.length, 10);
      for (final c in cases) {
        final result = resolve(c.query, c.answer);
        final text = joined(result);
        final urls =
            result.lines.where((line) => line.contains('https://')).toList();

        expect(text, contains(c.authority), reason: c.id);
        expect(text, contains(c.marker), reason: c.id);
        expect(urls.length, greaterThanOrEqualTo(3), reason: c.id);
        expect(urls.length, lessThanOrEqualTo(4), reason: c.id);
      }
    });

    test('aliases PT ES EN mantêm identidade temática', () {
      final probes = <({String q, String a, String marker})>[
        (
          q: 'uterine fibroids leiomyomas',
          a: 'UTERINE FIBROIDS',
          marker: 'Uterine'
        ),
        (q: 'uterine adenomyosis', a: 'ADENOMYOSIS', marker: 'Adenomyosis'),
        (
          q: 'bacterial vaginosis',
          a: 'BACTERIAL VAGINOSIS',
          marker: 'Bacterial Vaginosis'
        ),
        (
          q: 'vulvovaginal candidiasis VVC',
          a: 'VULVOVAGINAL CANDIDIASIS',
          marker: 'Candidiasis'
        ),
        (
          q: 'trichomoniasis Trichomonas vaginalis',
          a: 'TRICHOMONIASIS',
          marker: 'Trichomonas'
        ),
        (
          q: 'gestational trophoblastic disease molar pregnancy',
          a: 'GTD',
          marker: 'FIGO'
        ),
        (
          q: 'hyperemesis gravidarum HG',
          a: 'HYPEREMESIS GRAVIDARUM',
          marker: '2024'
        ),
        (q: 'placenta praevia', a: 'PLACENTA PREVIA', marker: '2026'),
        (
          q: 'placental abruption abruptio placentae',
          a: 'PLACENTAL ABRUPTION',
          marker: 'Placental Abruption'
        ),
        (
          q: 'preterm prelabor rupture of membranes PPROM',
          a: 'PPROM',
          marker: '2026'
        ),
      ];

      for (final p in probes) {
        final result = resolve(p.q, p.a, lang: 'en');
        expect(joined(result), contains(p.marker), reason: p.q);
        expect(
          result.lines.where((line) => line.contains('https://')).length,
          greaterThanOrEqualTo(3),
          reason: p.q,
        );
      }
    });

    test('precedência específica protege colisões gineco-obstétricas', () {
      final fibroid = joined(resolve(
        'sangramento uterino por mioma uterino',
        'MIOMA UTERINO',
      ));
      expect(fibroid, contains('Uterine Leiomyomas'));

      final adeno = joined(resolve(
        'sangramento uterino e adenomiose',
        'ADENOMIOSE',
      ));
      expect(adeno, contains('Adenomyosis'));

      final bv = joined(resolve(
        'vaginite por vaginose bacteriana',
        'VAGINOSE BACTERIANA',
      ));
      expect(bv, contains('Bacterial Vaginosis'));

      final vvc = joined(resolve(
        'vaginite por candidíase vulvovaginal',
        'CANDIDÍASE VULVOVAGINAL',
      ));
      expect(vvc, contains('Candidiasis'));

      final trich = joined(resolve(
        'vaginite por Trichomonas vaginalis',
        'TRICOMONÍASE',
      ));
      expect(trich, contains('Trichomonas'));

      final trichPtNormalized = joined(resolve(
        'tricomoniase',
        'TRICOMONIASE',
      ));
      expect(trichPtNormalized, contains('WHO'));
      expect(trichPtNormalized, contains('Trichomonas'));

      final gtd = joined(resolve(
        'mola hidatiforme e doença trofoblástica gestacional',
        'GESTATIONAL TROPHOBLASTIC DISEASE',
      ));
      expect(gtd, contains('FIGO'));
      expect(gtd, contains('2025'));

      final previa = joined(resolve(
        'hemorragia anteparto por placenta prévia',
        'PLACENTA PRÉVIA',
      ));
      expect(previa, contains('2026'));

      final abruption = joined(resolve(
        'hemorragia anteparto por descolamento prematuro de placenta',
        'PLACENTAL ABRUPTION',
      ));
      expect(abruption, contains('Placental Abruption'));

      final prom = joined(resolve(
        'trabalho de parto prematuro após PPROM',
        'PRETERM PRELABOR RUPTURE OF MEMBRANES',
      ));
      expect(prom, contains('Prelabor Rupture of Membranes'));
      expect(prom, contains('2026'));
    });

    test('Batch01–28 permanecem curated-only', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      for (var i = 1; i <= 10; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }
      for (var i = 11; i <= 28; i++) {
        expect(source,
            contains('_top200ExpansionBatch${i}Domains.contains(domain)'));
      }

      for (final domain in <String>[
        'uterine_fibroids_acog_nice_2025',
        'adenomyosis_asea_nice_2023',
        'bacterial_vaginosis_cdc_who_acog_2025',
        'vulvovaginal_candidiasis_cdc_who_idsa',
        'trichomoniasis_cdc_who_current',
        'gestational_trophoblastic_disease_figo_2025',
        'hyperemesis_gravidarum_rcog_2024',
        'placenta_previa_rcog_2026',
        'placental_abruption_rcog_acog_current',
        'prelabor_rupture_membranes_acog_2026',
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
