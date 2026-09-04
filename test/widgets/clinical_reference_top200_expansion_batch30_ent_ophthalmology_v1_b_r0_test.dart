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

  group('Top200 Expansion Batch30 ENT ophthalmology V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String marker,
    })>[
      (
        id: 'ARS',
        query: 'rinossinusite aguda bacteriana',
        answer: 'RINOSSINUSITE AGUDA',
        authority: 'AAO-HNSF',
        marker: '2025'
      ),
      (
        id: 'CRS',
        query: 'rinossinusite crônica',
        answer: 'RINOSSINUSITE CRÔNICA',
        authority: 'AAO-HNSF',
        marker: '2025'
      ),
      (
        id: 'AR',
        query: 'rinite alérgica',
        answer: 'RINITE ALÉRGICA',
        authority: 'ARIA–EAACI',
        marker: '2026'
      ),
      (
        id: 'AOE',
        query: 'otite externa aguda',
        answer: 'OTITE EXTERNA',
        authority: 'AAO-HNSF',
        marker: 'Acute Otitis Externa'
      ),
      (
        id: 'SSNHL',
        query: 'perda auditiva neurossensorial súbita',
        answer: 'SSNHL',
        authority: 'AAO-HNSF',
        marker: 'Sudden Hearing Loss'
      ),
      (
        id: 'CONJ',
        query: 'conjuntivite bacteriana',
        answer: 'CONJUNTIVITE',
        authority: 'AAO',
        marker: '2024'
      ),
      (
        id: 'KER',
        query: 'ceratite bacteriana',
        answer: 'CERATITE BACTERIANA',
        authority: 'AAO',
        marker: '2024'
      ),
      (
        id: 'UVE',
        query: 'uveíte anterior não infecciosa',
        answer: 'UVEÍTE',
        authority: 'DOG/BVA',
        marker: '2025'
      ),
      (
        id: 'GLAU',
        query: 'glaucoma primário de ângulo aberto',
        answer: 'GLAUCOMA',
        authority: 'AAO',
        marker: '2026'
      ),
      (
        id: 'CAT',
        query: 'catarata relacionada à idade',
        answer: 'CATARATA',
        authority: 'AAO',
        marker: 'Cataract'
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
          q: 'acute bacterial rhinosinusitis ABRS',
          a: 'ACUTE RHINOSINUSITIS',
          marker: '2025'
        ),
        (
          q: 'chronic rhinosinusitis CRS',
          a: 'CHRONIC RHINOSINUSITIS',
          marker: 'Chronic Rhinosinusitis'
        ),
        (q: 'allergic rhinitis', a: 'ALLERGIC RHINITIS', marker: 'ARIA'),
        (
          q: "swimmer's ear acute otitis externa",
          a: 'ACUTE OTITIS EXTERNA',
          marker: 'AAO-HNSF'
        ),
        (
          q: 'sudden sensorineural hearing loss SSNHL',
          a: 'SSNHL',
          marker: 'Sudden Hearing Loss'
        ),
        (
          q: 'bacterial conjunctivitis',
          a: 'CONJUNCTIVITIS',
          marker: 'Preferred Practice Pattern'
        ),
        (
          q: 'bacterial keratitis',
          a: 'BACTERIAL KERATITIS',
          marker: 'Preferred Practice Pattern'
        ),
        (
          q: 'noninfectious anterior uveitis',
          a: 'ANTERIOR UVEITIS',
          marker: 'DOG/BVA'
        ),
        (
          q: 'primary open-angle glaucoma POAG',
          a: 'PRIMARY OPEN-ANGLE GLAUCOMA',
          marker: '2026'
        ),
        (q: 'age-related cataract', a: 'CATARACT', marker: 'NICE'),
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

    test('precedência específica protege colisões ENT e oftalmológicas', () {
      final acute = joined(resolve(
        'rinossinusite aguda bacteriana versus rinossinusite crônica',
        'ACUTE BACTERIAL RHINOSINUSITIS',
      ));
      expect(acute, contains('Adult Sinusitis Update'));
      expect(acute, contains('2025'));

      final chronic = joined(resolve(
        'rinossinusite crônica com pólipos nasais',
        'CHRONIC RHINOSINUSITIS',
      ));
      expect(
          chronic, contains('Surgical Management of Chronic Rhinosinusitis'));

      final allergic = joined(resolve(
        'rinite alérgica com sinusite recorrente',
        'ALLERGIC RHINITIS',
      ));
      expect(allergic, contains('ARIA'));

      final aoe = joined(resolve(
        'otite externa aguda versus otite média aguda',
        'ACUTE OTITIS EXTERNA',
      ));
      expect(aoe, contains('Acute Otitis Externa'));

      final ssnhl = joined(resolve(
        'perda auditiva neurossensorial súbita unilateral',
        'SUDDEN SENSORINEURAL HEARING LOSS',
      ));
      expect(ssnhl, contains('Sudden Hearing Loss'));

      final conjunctivitis = joined(resolve(
        'conjuntivite bacteriana versus ceratite',
        'BACTERIAL CONJUNCTIVITIS',
      ));
      expect(conjunctivitis,
          contains('Conjunctivitis Preferred Practice Pattern'));

      final keratitis = joined(resolve(
        'ceratite bacteriana versus conjuntivite',
        'BACTERIAL KERATITIS',
      ));
      expect(keratitis,
          contains('Bacterial Keratitis Preferred Practice Pattern'));

      final uveitis = joined(resolve(
        'uveíte anterior versus conjuntivite',
        'ANTERIOR UVEITIS',
      ));
      expect(uveitis, contains('DOG/BVA'));

      final glaucoma = joined(resolve(
        'glaucoma primário de ângulo aberto com catarata',
        'PRIMARY OPEN-ANGLE GLAUCOMA',
      ));
      expect(glaucoma, contains('2026'));
      expect(glaucoma, contains('Primary Open-Angle Glaucoma'));

      final cataract = joined(resolve(
        'catarata relacionada à idade com glaucoma',
        'AGE-RELATED CATARACT',
      ));
      expect(cataract, contains('Cataract in the Adult Eye'));
      expect(cataract, contains('NICE'));
    });

    test('Batch01–30 permanecem curated-only', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      for (var i = 1; i <= 10; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }
      for (var i = 11; i <= 30; i++) {
        expect(source,
            contains('_top200ExpansionBatch${i}Domains.contains(domain)'));
      }

      for (final domain in <String>[
        'acute_rhinosinusitis_aao_hns_2025',
        'chronic_rhinosinusitis_aao_hns_2025',
        'allergic_rhinitis_aria_eaaci_2026',
        'acute_otitis_externa_aao_hns_current',
        'sudden_sensorineural_hearing_loss_aao_hns_japan',
        'conjunctivitis_aao_2024',
        'bacterial_keratitis_aao_2024',
        'uveitis_dog_ser_consensus_2025',
        'primary_open_angle_glaucoma_aao_2026',
        'adult_cataract_aao_nice_current',
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
