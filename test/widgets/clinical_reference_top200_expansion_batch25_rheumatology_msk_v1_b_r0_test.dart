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

  group('Top200 Expansion Batch25 rheumatology MSK V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String marker,
    })>[
      (
        id: 'FM',
        query: 'fibromialgia',
        answer: 'FIBROMIALGIA',
        authority: 'EULAR',
        marker: 'Fibromyalgia'
      ),
      (
        id: 'REA',
        query: 'artrite reativa',
        answer: 'ARTRITE REATIVA',
        authority: 'ACR',
        marker: '2025'
      ),
      (
        id: 'CPPD',
        query: 'doença por deposição de pirofosfato de cálcio',
        answer: 'CPPD',
        authority: 'ACR/EULAR',
        marker: '2023'
      ),
      (
        id: 'IIM',
        query: 'dermatomiosite',
        answer: 'MIOPATIA INFLAMATÓRIA IDIOPÁTICA',
        authority: 'BSR',
        marker: '2022'
      ),
      (
        id: 'JIA',
        query: 'artrite idiopática juvenil',
        answer: 'AIJ / JIA',
        authority: 'ACR',
        marker: '2026'
      ),
      (
        id: 'RP',
        query: 'Raynaud primário',
        answer: 'FENÔMENO DE RAYNAUD PRIMÁRIO',
        authority: 'ACR',
        marker: '2025'
      ),
      (
        id: 'LBP',
        query: 'lombalgia inespecífica',
        answer: 'LOMBALGIA INESPECÍFICA',
        authority: 'WHO',
        marker: '2023'
      ),
      (
        id: 'SCI',
        query: 'radiculopatia lombar com ciatalgia',
        answer: 'CIÁTICA / RADICULOPATIA LOMBAR',
        authority: 'NICE',
        marker: 'NG59'
      ),
      (
        id: 'NECK',
        query: 'cervicalgia inespecífica',
        answer: 'CERVICALGIA',
        authority: 'JOSPT/APTA',
        marker: '2017'
      ),
      (
        id: 'RC',
        query: 'lesão do manguito rotador',
        answer: 'MANGUITO ROTADOR',
        authority: 'AAOS',
        marker: '2025'
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
        (q: 'fibromyalgia syndrome', a: 'FIBROMYALGIA', marker: 'Fibromyalgia'),
        (
          q: 'reactive arthritis',
          a: 'REACTIVE ARTHRITIS',
          marker: 'Reactive Arthritis'
        ),
        (
          q: 'calcium pyrophosphate deposition disease CPPD',
          a: 'CPPD',
          marker: 'ACR/EULAR'
        ),
        (
          q: 'idiopathic inflammatory myopathy dermatomyositis',
          a: 'DERMATOMYOSITIS',
          marker: 'BSR'
        ),
        (q: 'juvenile idiopathic arthritis JIA', a: 'JIA', marker: '2026'),
        (
          q: "primary Raynaud's phenomenon",
          a: 'PRIMARY RAYNAUD',
          marker: 'Raynaud'
        ),
        (q: 'nonspecific low back pain', a: 'LOW BACK PAIN', marker: 'WHO'),
        (q: 'lumbar radiculopathy sciatica', a: 'SCIATICA', marker: 'NG59'),
        (q: 'nonspecific neck pain', a: 'NECK PAIN', marker: 'JOSPT'),
        (q: 'rotator cuff tear', a: 'ROTATOR CUFF INJURY', marker: 'AAOS'),
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

    test('precedência específica protege colisões reumato-MSK', () {
      expect(
        joined(resolve('fibromialgia com dor crônica difusa', 'FIBROMIALGIA')),
        contains('Fibromyalgia'),
      );

      expect(
        joined(resolve('artrite reativa após infecção', 'ARTRITE REATIVA')),
        contains('Reactive Arthritis'),
      );

      final cppd = joined(resolve(
        'pseudogota por CPPD versus gota',
        'CPPD',
      ));
      expect(cppd, contains('ACR/EULAR'));

      final iim = joined(resolve(
        'dermatomiosite com fraqueza muscular',
        'DERMATOMIOSITE',
      ));
      expect(iim, contains('BSR'));

      final jia = joined(resolve(
        'artrite idiopática juvenil poliarticular',
        'JIA',
      ));
      expect(jia, contains('2026'));

      final raynaud = joined(resolve(
        'Raynaud primário sem esclerose sistêmica',
        'PRIMARY RAYNAUD',
      ));
      expect(raynaud, contains('Raynaud'));

      final lbp = joined(resolve(
        'lombalgia inespecífica crônica sem radiculopatia',
        'LOW BACK PAIN',
      ));
      expect(lbp, contains('WHO'));

      final sci = joined(resolve(
        'dor lombar com radiculopatia lombar e ciática',
        'SCIATICA',
      ));
      expect(sci, contains('NG59'));

      final neck = joined(resolve(
        'cervicalgia inespecífica sem mielopatia',
        'NECK PAIN',
      ));
      expect(neck, contains('JOSPT'));

      final rc = joined(resolve(
        'dor no ombro por lesão do manguito rotador',
        'ROTATOR CUFF INJURY',
      ));
      expect(rc, contains('AAOS'));
      expect(rc, contains('2025'));
    });

    test('Batch01–25 permanecem curated-only', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      for (var i = 1; i <= 10; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }
      for (var i = 11; i <= 25; i++) {
        expect(source,
            contains('_top200ExpansionBatch${i}Domains.contains(domain)'));
      }

      for (final domain in <String>[
        'fibromyalgia_eular_nice_current',
        'reactive_arthritis_acr_2025',
        'cppd_acr_eular_2023',
        'idiopathic_inflammatory_myopathy_bsr_2022',
        'juvenile_idiopathic_arthritis_acr_2026',
        'primary_raynaud_acr_2025',
        'nonspecific_low_back_pain_who_nice',
        'lumbar_radiculopathy_sciatica_nice',
        'nonspecific_cervicalgia_jospt_current',
        'rotator_cuff_injury_aaos_2025',
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
