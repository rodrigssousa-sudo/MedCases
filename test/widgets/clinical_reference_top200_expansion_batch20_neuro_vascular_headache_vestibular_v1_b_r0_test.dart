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

  group('Top200 Expansion Batch20 neuro vascular headache vestibular V1-B-R0',
      () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String marker,
    })>[
      (
        id: 'TIA',
        query: 'ataque isquêmico transitório',
        answer: 'AIT / TIA',
        authority: 'AHA',
        marker: '2023'
      ),
      (
        id: 'ICH',
        query: 'hemorragia intracerebral espontânea',
        answer: 'HEMORRAGIA INTRACEREBRAL',
        authority: 'AHA/ASA',
        marker: '2022'
      ),
      (
        id: 'SAH',
        query: 'hemorragia subaracnóidea aneurismática',
        answer: 'HSA ANEURISMÁTICA',
        authority: 'AHA/ASA',
        marker: '2023'
      ),
      (
        id: 'CVT',
        query: 'trombose venosa cerebral',
        answer: 'TROMBOSE VENOSA CEREBRAL',
        authority: 'AHA',
        marker: '2024'
      ),
      (
        id: 'TN',
        query: 'neuralgia do trigêmeo',
        answer: 'NEURALGIA DO TRIGÊMEO',
        authority: 'EAN',
        marker: '2019'
      ),
      (
        id: 'CH',
        query: 'cefaleia em salvas',
        answer: 'CEFALEIA EM SALVAS',
        authority: 'EAN',
        marker: '2023'
      ),
      (
        id: 'TTH',
        query: 'cefaleia tipo tensão',
        answer: 'CEFALEIA TENSIONAL',
        authority: 'NICE',
        marker: '2025'
      ),
      (
        id: 'BPPV',
        query: 'vertigem posicional paroxística benigna',
        answer: 'VPPB',
        authority: 'AAO-HNSF',
        marker: '2026'
      ),
      (
        id: 'VN',
        query: 'neurite vestibular',
        answer: 'NEURITE VESTIBULAR',
        authority: 'Bárány Society',
        marker: '2022'
      ),
      (
        id: 'BELL',
        query: 'paralisia de Bell',
        answer: 'PARALISIA DE BELL',
        authority: 'AAO-HNSF',
        marker: 'Bell'
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
          q: 'transient ischemic attack',
          a: 'TRANSIENT ISCHEMIC ATTACK',
          marker: 'Transient Ischemic Attack'
        ),
        (
          q: 'spontaneous intracerebral hemorrhage',
          a: 'INTRACEREBRAL HEMORRHAGE',
          marker: 'Intracerebral Hemorrhage'
        ),
        (
          q: 'aneurysmal subarachnoid hemorrhage',
          a: 'ANEURYSMAL SAH',
          marker: 'Subarachnoid Hemorrhage'
        ),
        (
          q: 'cerebral venous thrombosis',
          a: 'CEREBRAL VENOUS THROMBOSIS',
          marker: 'Cerebral Venous Thrombosis'
        ),
        (
          q: 'trigeminal neuralgia',
          a: 'TRIGEMINAL NEURALGIA',
          marker: 'Trigeminal Neuralgia'
        ),
        (
          q: 'cluster headache',
          a: 'CLUSTER HEADACHE',
          marker: 'Cluster Headache'
        ),
        (
          q: 'tension-type headache',
          a: 'TENSION-TYPE HEADACHE',
          marker: 'Tension-Type'
        ),
        (
          q: 'benign paroxysmal positional vertigo',
          a: 'BPPV',
          marker: 'Benign Paroxysmal Positional Vertigo'
        ),
        (
          q: 'acute unilateral vestibulopathy vestibular neuritis',
          a: 'VESTIBULAR NEURITIS',
          marker: 'Vestibular Neuritis'
        ),
        (q: "Bell's palsy", a: 'BELL PALSY', marker: 'Bell'),
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
        'precedência específica protege colisões neurovasculares e vestibulares',
        () {
      final tia = joined(resolve(
        'ataque isquêmico transitório com alto risco de AVC',
        'AIT / TIA',
      ));
      expect(tia, contains('Transient Ischemic Attack'));
      expect(tia, contains('2023'));

      final ich = joined(resolve(
        'AVC hemorrágico por hemorragia intracerebral espontânea',
        'HEMORRAGIA INTRACEREBRAL',
      ));
      expect(ich, contains('Spontaneous Intracerebral Hemorrhage'));
      expect(ich, contains('2022'));

      final sah = joined(resolve(
        'AVC hemorrágico com hemorragia subaracnóidea aneurismática',
        'HSA ANEURISMÁTICA',
      ));
      expect(sah, contains('Aneurysmal Subarachnoid Hemorrhage'));
      expect(sah, contains('2023'));

      final cvt = joined(resolve(
        'trombose venosa cerebral com cefaleia',
        'TROMBOSE VENOSA CEREBRAL',
      ));
      expect(cvt, contains('Cerebral Venous Thrombosis'));
      expect(cvt, contains('2024'));

      final cluster = joined(resolve(
        'cefaleia em salvas, não migrânea',
        'CEFALEIA EM SALVAS',
      ));
      expect(cluster, contains('Cluster Headache'));

      final tth = joined(resolve(
        'cefaleia tensional crônica',
        'CEFALEIA TENSIONAL',
      ));
      expect(tth, contains('Tension-Type'));

      final bppv = joined(resolve(
        'vertigem por VPPB',
        'VERTIGEM POSICIONAL PAROXÍSTICA BENIGNA',
      ));
      expect(bppv, contains('Benign Paroxysmal Positional Vertigo'));

      final vn = joined(resolve(
        'vertigem aguda por neurite vestibular',
        'NEURITE VESTIBULAR',
      ));
      expect(vn, contains('Vestibular Neuritis'));

      final bell = joined(resolve(
        'paralisia facial periférica por paralisia de Bell',
        'PARALISIA DE BELL',
      ));
      expect(bell, contains('Bell'));
      expect(bell, isNot(contains('Stroke Guideline')));
    });

    test('Batch01–20 permanecem curated-only', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      for (var i = 1; i <= 10; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }
      for (var i = 11; i <= 20; i++) {
        expect(source,
            contains('_top200ExpansionBatch${i}Domains.contains(domain)'));
      }

      for (final domain in <String>[
        'transient_ischemic_attack_aha_2023',
        'spontaneous_intracerebral_hemorrhage_aha_2022',
        'aneurysmal_subarachnoid_hemorrhage_aha_2023',
        'cerebral_venous_thrombosis_aha_2024',
        'trigeminal_neuralgia_ean_2019',
        'cluster_headache_ean_2023',
        'tension_type_headache_nice_2025',
        'bppv_aao_hns_2026',
        'vestibular_neuritis_barany_2022',
        'bell_palsy_aao_hns_2026',
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
