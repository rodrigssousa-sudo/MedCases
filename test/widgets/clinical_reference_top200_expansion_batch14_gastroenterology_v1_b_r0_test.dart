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

  group('Top200 Expansion Batch14 gastroenterology V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String marker,
    })>[
      (
        id: 'PUD',
        query: 'úlcera péptica',
        answer: 'ÚLCERA PÉPTICA',
        authority: 'ESGE',
        marker: '2026'
      ),
      (
        id: 'NSAID',
        query: 'gastropatia por AINEs',
        answer: 'GASTROPATIA POR AINES',
        authority: 'ACG',
        marker: 'NSAID'
      ),
      (
        id: 'FD',
        query: 'dispepsia funcional',
        answer: 'DISPEPSIA FUNCIONAL',
        authority: 'BSG',
        marker: '2022'
      ),
      (
        id: 'GP',
        query: 'gastroparesia',
        answer: 'GASTROPARESIA',
        authority: 'AGA',
        marker: '2025'
      ),
      (
        id: 'DIV',
        query: 'doença diverticular não complicada',
        answer: 'DOENÇA DIVERTICULAR NÃO COMPLICADA',
        authority: 'ACG',
        marker: '2026'
      ),
      (
        id: 'LGIB',
        query: 'hemorragia digestiva baixa',
        answer: 'HEMORRAGIA DIGESTIVA BAIXA',
        authority: 'ACG',
        marker: '2023'
      ),
      (
        id: 'MC',
        query: 'colite microscópica',
        answer: 'COLITE MICROSCÓPICA',
        authority: 'UEG/EMCG',
        marker: '2021'
      ),
      (
        id: 'IC',
        query: 'colite isquêmica',
        answer: 'COLITE ISQUÊMICA',
        authority: 'ACG',
        marker: 'Colon Ischemia'
      ),
      (
        id: 'PROCT',
        query: 'proctite',
        answer: 'PROCTITE',
        authority: 'CDC',
        marker: 'Proctitis'
      ),
      (
        id: 'FI',
        query: 'incontinência fecal',
        answer: 'INCONTINÊNCIA FECAL',
        authority: 'ASCRS',
        marker: '2023'
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
          q: 'peptic ulcer disease',
          a: 'PEPTIC ULCER DISEASE',
          marker: 'Peptic Ulcer'
        ),
        (q: 'nsaid gastropathy', a: 'NSAID GASTROPATHY', marker: 'NSAID'),
        (
          q: 'functional dyspepsia',
          a: 'FUNCTIONAL DYSPEPSIA',
          marker: 'Functional Dyspepsia'
        ),
        (q: 'gastroparesis', a: 'GASTROPARESIS', marker: 'Gastroparesis'),
        (
          q: 'enfermedad diverticular no complicada',
          a: 'ENFERMEDAD DIVERTICULAR NO COMPLICADA',
          marker: 'Diverticulitis'
        ),
        (
          q: 'lower gastrointestinal bleeding',
          a: 'LOWER GI BLEEDING',
          marker: 'Lower Gastrointestinal'
        ),
        (
          q: 'microscopic colitis',
          a: 'MICROSCOPIC COLITIS',
          marker: 'Microscopic Colitis'
        ),
        (
          q: 'ischemic colitis',
          a: 'ISCHEMIC COLITIS',
          marker: 'Colon Ischemia'
        ),
        (q: 'proctitis', a: 'PROCTITIS', marker: 'Proctitis'),
        (
          q: 'faecal incontinence',
          a: 'FAECAL INCONTINENCE',
          marker: 'Fecal Incontinence'
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

    test('precedência específica bloqueia colisões GI', () {
      final nsaid = joined(resolve(
        'gastropatia por AINEs com úlcera péptica',
        'GASTROPATIA POR AINES',
      ));
      expect(nsaid, contains('NSAID-Related'));
      expect(
          nsaid,
          isNot(contains(
              'Endoscopic Diagnosis and Management of Peptic Ulcer Bleeding: Guideline Update')));

      final gp = joined(resolve(
        'gastroparesia com dispepsia funcional',
        'GASTROPARESIA',
      ));
      expect(gp, contains('AGA'));
      expect(gp, contains('2025'));

      final ischemic = joined(resolve(
        'colite isquêmica com diarreia',
        'COLITE ISQUÊMICA',
      ));
      expect(ischemic, contains('Colon Ischemia'));

      final microscopic = joined(resolve(
        'colite microscópica',
        'COLITE MICROSCÓPICA',
      ));
      expect(microscopic, contains('UEG/EMCG'));

      final proctitis = joined(resolve(
        'proctite',
        'PROCTITE',
      ));
      expect(proctitis, contains('CDC'));

      final diverticular = joined(resolve(
        'doença diverticular não complicada',
        'DOENÇA DIVERTICULAR NÃO COMPLICADA',
      ));
      expect(diverticular, contains('2026'));
    });

    test('Batch01–14 permanecem curated-only', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      for (var i = 1; i <= 10; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }
      for (var i = 11; i <= 14; i++) {
        expect(source,
            contains('_top200ExpansionBatch${i}Domains.contains(domain)'));
      }

      for (final domain in <String>[
        'peptic_ulcer_disease_esge_2026',
        'nsaid_gastropathy_ulcer_prevention',
        'functional_dyspepsia_bsg_2022',
        'gastroparesis_aga_2025',
        'uncomplicated_diverticular_disease_acg_2026',
        'lower_gi_bleeding_acg_2023',
        'microscopic_colitis_ueg_emcg_2021',
        'ischemic_colitis_acg',
        'proctitis_multietiology_guidance',
        'fecal_incontinence_ascrs_2023',
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
