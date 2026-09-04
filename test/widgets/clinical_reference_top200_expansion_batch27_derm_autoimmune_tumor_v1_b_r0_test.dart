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

  group('Top200 Expansion Batch27 derm autoimmune tumor V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String marker,
    })>[
      (
        id: 'TINEA',
        query: 'tinea corporis',
        answer: 'DERMATOFITOSE',
        authority: 'AAD',
        marker: 'Dermatophyt'
      ),
      (
        id: 'CAND',
        query: 'candidíase cutânea',
        answer: 'CANDIDÍASE CUTÂNEA',
        authority: 'IDSA',
        marker: 'Candidiasis'
      ),
      (
        id: 'HS',
        query: 'hidradenite supurativa',
        answer: 'HIDRADENITE SUPURATIVA',
        authority: 'AAD',
        marker: '2026'
      ),
      (
        id: 'VIT',
        query: 'vitiligo não segmentar',
        answer: 'VITILIGO',
        authority: 'British Association of Dermatologists',
        marker: 'Vitiligo'
      ),
      (
        id: 'AA',
        query: 'alopecia areata',
        answer: 'ALOPECIA AREATA',
        authority: 'British Association of Dermatologists',
        marker: '2024'
      ),
      (
        id: 'PV',
        query: 'pênfigo vulgar',
        answer: 'PÊNFIGO VULGAR',
        authority: 'EADV',
        marker: 'Pemphigus'
      ),
      (
        id: 'BP',
        query: 'penfigoide bolhoso',
        answer: 'PENFIGOIDE BOLHOSO',
        authority: 'EADV',
        marker: '2022'
      ),
      (
        id: 'MEL',
        query: 'melanoma cutâneo',
        answer: 'MELANOMA',
        authority: 'AAD',
        marker: 'Melanoma'
      ),
      (
        id: 'BCC',
        query: 'carcinoma basocelular',
        answer: 'CARCINOMA BASOCELULAR',
        authority: 'AAD',
        marker: 'Basal Cell'
      ),
      (
        id: 'CSCC',
        query: 'carcinoma espinocelular cutâneo',
        answer: 'CARCINOMA ESPINOCELULAR',
        authority: 'AAD',
        marker: 'Squamous Cell'
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
          q: 'cutaneous dermatophytosis ringworm',
          a: 'TINEA',
          marker: 'Dermatophyt'
        ),
        (
          q: 'cutaneous candidiasis candidal intertrigo',
          a: 'CUTANEOUS CANDIDIASIS',
          marker: 'IDSA'
        ),
        (
          q: 'hidradenitis suppurativa acne inversa',
          a: 'HIDRADENITIS SUPPURATIVA',
          marker: 'AAD'
        ),
        (q: 'nonsegmental vitiligo', a: 'VITILIGO', marker: 'Vitiligo'),
        (
          q: 'alopecia areata alopecia totalis',
          a: 'ALOPECIA AREATA',
          marker: '2024'
        ),
        (q: 'pemphigus vulgaris', a: 'PEMPHIGUS VULGARIS', marker: 'EADV'),
        (q: 'bullous pemphigoid', a: 'BULLOUS PEMPHIGOID', marker: '2022'),
        (q: 'cutaneous melanoma', a: 'MELANOMA', marker: 'AAD'),
        (
          q: 'basal cell carcinoma BCC',
          a: 'BASAL CELL CARCINOMA',
          marker: 'Basal Cell'
        ),
        (
          q: 'cutaneous squamous cell carcinoma cSCC',
          a: 'CUTANEOUS SCC',
          marker: 'Squamous Cell'
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

    test(
        'precedência específica protege colisões dermatológicas tumorais e autoimunes',
        () {
      final tinea = joined(resolve(
        'tinea corporis por dermatófito',
        'DERMATOFITOSE',
      ));
      expect(tinea, contains('Dermatophyt'));

      final candida = joined(resolve(
        'intertrigo por candidíase cutânea',
        'CANDIDÍASE CUTÂNEA',
      ));
      expect(candida, contains('IDSA'));
      expect(candida, contains('Candidiasis'));

      final hs = joined(resolve(
        'hidradenite supurativa versus acne',
        'HIDRADENITE SUPURATIVA',
      ));
      expect(hs, contains('Hidradenitis Suppurativa'));

      final vit = joined(resolve(
        'vitiligo não segmentar autoimune',
        'VITILIGO',
      ));
      expect(vit, contains('Vitiligo'));

      final aa = joined(resolve(
        'alopecia areata versus alopecia androgenética',
        'ALOPECIA AREATA',
      ));
      expect(aa, contains('2024'));

      final pv = joined(resolve(
        'pênfigo vulgar com bolhas mucosas',
        'PÊNFIGO VULGAR',
      ));
      expect(pv, contains('Pemphigus'));

      final bp = joined(resolve(
        'penfigoide bolhoso em idoso',
        'BULLOUS PEMPHIGOID',
      ));
      expect(bp, contains('2022'));

      final melanoma = joined(resolve(
        'câncer de pele melanoma cutâneo',
        'CUTANEOUS MELANOMA',
      ));
      expect(melanoma, contains('Melanoma'));

      final bcc = joined(resolve(
        'câncer de pele carcinoma basocelular',
        'BASAL CELL CARCINOMA',
      ));
      expect(bcc, contains('Basal Cell'));

      final cscc = joined(resolve(
        'câncer de pele carcinoma espinocelular cutâneo',
        'CUTANEOUS SQUAMOUS CELL CARCINOMA',
      ));
      expect(cscc, contains('Squamous Cell'));
    });

    test('Batch01–27 permanecem curated-only', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      for (var i = 1; i <= 10; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }
      for (var i = 11; i <= 27; i++) {
        expect(source,
            contains('_top200ExpansionBatch${i}Domains.contains(domain)'));
      }

      for (final domain in <String>[
        'cutaneous_dermatophytosis_aad_cdc_2026',
        'cutaneous_candidiasis_idsa_cdc_current',
        'hidradenitis_suppurativa_aad_2026',
        'vitiligo_bad_2021_current',
        'alopecia_areata_bad_living_2024',
        'pemphigus_vulgaris_eadv_2020_current',
        'bullous_pemphigoid_eadv_2022_current',
        'cutaneous_melanoma_aad_current',
        'basal_cell_carcinoma_aad_current',
        'cutaneous_squamous_cell_carcinoma_aad_current',
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
