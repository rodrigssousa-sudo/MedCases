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

  group('Top200 Expansion Batch26 derm inflammatory infectious V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String marker,
    })>[
      (
        id: 'AD',
        query: 'dermatite atópica',
        answer: 'DERMATITE ATÓPICA',
        authority: 'AAD',
        marker: '2026'
      ),
      (
        id: 'CD',
        query: 'dermatite de contato',
        answer: 'DERMATITE DE CONTATO',
        authority: 'British Association of Dermatologists',
        marker: '2025'
      ),
      (
        id: 'SD',
        query: 'dermatite seborreica',
        answer: 'DERMATITE SEBORREICA',
        authority: 'EADV',
        marker: '2026'
      ),
      (
        id: 'PSO',
        query: 'psoríase em placas',
        answer: 'PSORÍASE',
        authority: 'AAD/NPF',
        marker: 'Psoriasis'
      ),
      (
        id: 'URT',
        query: 'urticária crônica espontânea',
        answer: 'URTICÁRIA CRÔNICA',
        authority: 'EuroGuiDerm',
        marker: 'Urticaria'
      ),
      (
        id: 'ANG',
        query: 'angioedema hereditário',
        answer: 'ANGIOEDEMA HEREDITÁRIO',
        authority: 'WAO',
        marker: '2025'
      ),
      (
        id: 'ACNE',
        query: 'acne vulgar inflamatória',
        answer: 'ACNE VULGAR',
        authority: 'AAD',
        marker: '2024'
      ),
      (
        id: 'ROS',
        query: 'rosácea papulopustular',
        answer: 'ROSÁCEA',
        authority: 'Consensus',
        marker: '2024'
      ),
      (
        id: 'IMP',
        query: 'impetigo não bolhoso',
        answer: 'IMPETIGO',
        authority: 'NICE',
        marker: '2026'
      ),
      (
        id: 'SCAB',
        query: 'escabiose',
        answer: 'ESCABIOSE',
        authority: 'CDC',
        marker: 'Scabies'
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
        (q: 'atopic dermatitis', a: 'ATOPIC DERMATITIS', marker: 'AAD'),
        (
          q: 'allergic contact dermatitis',
          a: 'CONTACT DERMATITIS',
          marker: 'Contact Dermatitis'
        ),
        (
          q: 'seborrheic dermatitis',
          a: 'SEBORRHEIC DERMATITIS',
          marker: 'Seborrheic'
        ),
        (q: 'plaque psoriasis', a: 'PSORIASIS', marker: 'Psoriasis'),
        (
          q: 'chronic spontaneous urticaria',
          a: 'CHRONIC URTICARIA',
          marker: 'Urticaria'
        ),
        (
          q: 'hereditary angioedema HAE',
          a: 'HEREDITARY ANGIOEDEMA',
          marker: '2025'
        ),
        (
          q: 'acne vulgaris inflammatory acne',
          a: 'ACNE VULGARIS',
          marker: '2024'
        ),
        (q: 'papulopustular rosacea', a: 'ROSACEA', marker: '2024'),
        (q: 'non-bullous impetigo', a: 'IMPETIGO', marker: 'NICE'),
        (q: 'human scabies', a: 'SCABIES', marker: 'CDC'),
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

    test('precedência específica protege colisões dermatológicas', () {
      final ad = joined(resolve(
        'eczema por dermatite atópica',
        'DERMATITE ATÓPICA',
      ));
      expect(ad, contains('Atopic Dermatitis'));

      final contact = joined(resolve(
        'eczema por dermatite alérgica de contato',
        'DERMATITE DE CONTATO',
      ));
      expect(contact, contains('Contact Dermatitis'));

      final seb = joined(resolve(
        'eczema do couro cabeludo por dermatite seborreica',
        'DERMATITE SEBORREICA',
      ));
      expect(seb, contains('Seborrheic'));

      final urt = joined(resolve(
        'urticária crônica espontânea com angioedema',
        'URTICÁRIA CRÔNICA',
      ));
      expect(urt, contains('Urticaria'));

      final hae = joined(resolve(
        'angioedema hereditário sem urticária',
        'ANGIOEDEMA HEREDITÁRIO',
      ));
      expect(hae, contains('WAO'));
      expect(hae, contains('2025'));

      final acne = joined(resolve(
        'acne vulgar inflamatória versus rosácea',
        'ACNE VULGAR',
      ));
      expect(acne, contains('Acne'));

      final rosacea = joined(resolve(
        'rosácea papulopustular versus acne',
        'ROSÁCEA',
      ));
      expect(rosacea, contains('Rosacea'));

      final impetigo = joined(resolve(
        'impetigo não bolhoso versus celulite',
        'IMPETIGO',
      ));
      expect(impetigo, contains('NICE'));

      final scabies = joined(resolve(
        'escabiose com impetiginização secundária',
        'ESCABIOSE',
      ));
      expect(scabies, contains('CDC'));
      expect(scabies, contains('Scabies'));
    });

    test('Batch01–26 permanecem curated-only', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      for (var i = 1; i <= 10; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }
      for (var i = 11; i <= 26; i++) {
        expect(source,
            contains('_top200ExpansionBatch${i}Domains.contains(domain)'));
      }

      for (final domain in <String>[
        'atopic_dermatitis_aad_2026',
        'contact_dermatitis_bad_escd_2025',
        'seborrheic_dermatitis_eadv_2026',
        'psoriasis_aad_npf_current',
        'chronic_urticaria_euroguiderm_eaaci_2022',
        'hereditary_angioedema_wao_2025',
        'acne_vulgaris_aad_2024',
        'rosacea_global_consensus_2024',
        'impetigo_nice_2026',
        'scabies_cdc_current',
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
