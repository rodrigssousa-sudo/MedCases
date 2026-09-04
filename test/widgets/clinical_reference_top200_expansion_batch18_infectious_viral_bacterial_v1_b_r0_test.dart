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

  group('Top200 Expansion Batch18 infectious viral bacterial V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String marker,
    })>[
      (
        id: 'HZ',
        query: 'herpes zoster',
        answer: 'HERPES ZOSTER',
        authority: 'CDC',
        marker: 'Shingles'
      ),
      (
        id: 'VAR',
        query: 'varicela',
        answer: 'VARICELA',
        authority: 'CDC',
        marker: 'Chickenpox'
      ),
      (
        id: 'EBV',
        query: 'mononucleose infecciosa',
        answer: 'MONONUCLEOSE INFECCIOSA',
        authority: 'CDC',
        marker: 'Epstein-Barr'
      ),
      (
        id: 'CMV',
        query: 'doença por citomegalovirus',
        answer: 'CITOMEGALOVIRUS',
        authority: 'NIH',
        marker: '2026'
      ),
      (
        id: 'TOXO',
        query: 'toxoplasmose',
        answer: 'TOXOPLASMOSE',
        authority: 'CDC',
        marker: '2026'
      ),
      (
        id: 'HAV',
        query: 'hepatite A',
        answer: 'HEPATITE A',
        authority: 'CDC',
        marker: '2025'
      ),
      (
        id: 'CELL',
        query: 'celulite bacteriana não purulenta',
        answer: 'CELULITE BACTERIANA',
        authority: 'IDSA',
        marker: 'Skin and Soft Tissue'
      ),
      (
        id: 'ERYS',
        query: 'erisipela',
        answer: 'ERISIPELA',
        authority: 'NICE',
        marker: 'Erysipelas'
      ),
      (
        id: 'OM',
        query: 'osteomielite',
        answer: 'OSTEOMIELITE',
        authority: 'IDSA',
        marker: 'Osteomyelitis'
      ),
      (
        id: 'SA',
        query: 'artrite séptica',
        answer: 'ARTRITE SÉPTICA',
        authority: 'SANJO/EBJIS',
        marker: 'Septic Arthritis'
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
        (q: 'shingles', a: 'HERPES ZOSTER', marker: 'Shingles'),
        (q: 'chickenpox', a: 'VARICELLA', marker: 'Chickenpox'),
        (
          q: 'infectious mononucleosis',
          a: 'INFECTIOUS MONONUCLEOSIS',
          marker: 'Epstein-Barr'
        ),
        (
          q: 'cytomegalovirus disease',
          a: 'CMV DISEASE',
          marker: 'Cytomegalovirus'
        ),
        (
          q: 'toxoplasma encephalitis',
          a: 'TOXOPLASMOSIS',
          marker: 'Toxoplasmosis'
        ),
        (
          q: 'hepatitis A virus infection',
          a: 'HEPATITIS A',
          marker: 'Hepatitis A'
        ),
        (
          q: 'bacterial cellulitis',
          a: 'BACTERIAL CELLULITIS',
          marker: 'Skin and Soft Tissue'
        ),
        (q: 'erysipelas', a: 'ERYSIPELAS', marker: 'Erysipelas'),
        (q: 'osteomyelitis', a: 'OSTEOMYELITIS', marker: 'Osteomyelitis'),
        (
          q: 'septic arthritis',
          a: 'SEPTIC ARTHRITIS',
          marker: 'Septic Arthritis'
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

    test('toxoplasma encephalitis nunca cai no owner de asma', () {
      final toxo = joined(resolve(
        'toxoplasma encephalitis',
        'TOXOPLASMOSIS',
        lang: 'en',
      ));
      expect(toxo, contains('Toxoplasmosis'));
      expect(toxo, isNot(contains('GINA')));
      expect(toxo, isNot(contains('Asthma')));
    });

    test('precedência específica protege colisões infecciosas', () {
      final zoster = joined(resolve(
        'herpes zoster em paciente com HIV',
        'HERPES ZOSTER',
      ));
      expect(zoster, contains('Shingles'));

      final varicella = joined(resolve(
        'varicela em imunocomprometido',
        'VARICELA',
      ));
      expect(varicella, contains('Chickenpox'));

      final cmv = joined(resolve(
        'doença por CMV em paciente com HIV',
        'CITOMEGALOVIRUS',
      ));
      expect(cmv, contains('Cytomegalovirus'));

      final toxo = joined(resolve(
        'toxoplasmose cerebral em paciente com HIV',
        'TOXOPLASMOSE CEREBRAL',
      ));
      expect(toxo, contains('Toxoplasmosis'));

      final hav = joined(resolve(
        'hepatite A aguda',
        'HEPATITE A',
      ));
      expect(hav, contains('Hepatitis A'));

      final ery = joined(resolve(
        'erisipela facial com celulite',
        'ERISIPELA',
      ));
      expect(ery, contains('Erysipelas'));

      final osteo = joined(resolve(
        'osteomielite com sepse',
        'OSTEOMIELITE',
      ));
      expect(osteo, contains('Osteomyelitis'));

      final septic = joined(resolve(
        'artrite séptica com sepse',
        'ARTRITE SÉPTICA',
      ));
      expect(septic, contains('Septic Arthritis'));
    });

    test('Batch01–18 permanecem curated-only', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      for (var i = 1; i <= 10; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }
      for (var i = 11; i <= 18; i++) {
        expect(source,
            contains('_top200ExpansionBatch${i}Domains.contains(domain)'));
      }

      for (final domain in <String>[
        'herpes_zoster_cdc_nih_2026',
        'varicella_cdc_nih_2026',
        'infectious_mononucleosis_ebv_cdc',
        'cytomegalovirus_disease_nih_2026',
        'toxoplasmosis_cdc_nih_2026',
        'hepatitis_a_cdc_2025',
        'cellulitis_ssti_idsa_nice',
        'erysipelas_idsa_nice',
        'osteomyelitis_idsa_pids',
        'septic_arthritis_sanjo_pids_idsa',
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
