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

  group('Top200 Expansion Batch19 tropical emerging V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String marker,
    })>[
      (
        id: 'LEPTO',
        query: 'leptospirose',
        answer: 'LEPTOSPIROSE',
        authority: 'CDC',
        marker: '2026'
      ),
      (
        id: 'CHAGAS',
        query: 'doença de Chagas',
        answer: 'DOENÇA DE CHAGAS',
        authority: 'WHO',
        marker: '2026'
      ),
      (
        id: 'VL',
        query: 'leishmaniose visceral kala-azar',
        answer: 'LEISHMANIOSE VISCERAL',
        authority: 'WHO',
        marker: '2026'
      ),
      (
        id: 'YF',
        query: 'febre amarela',
        answer: 'FEBRE AMARELA',
        authority: 'WHO',
        marker: 'Yellow Fever'
      ),
      (
        id: 'CHIK',
        query: 'chikungunya',
        answer: 'CHIKUNGUNYA',
        authority: 'CDC',
        marker: '2026'
      ),
      (
        id: 'ZIKA',
        query: 'Zika',
        answer: 'ZIKA',
        authority: 'CDC',
        marker: 'Zika'
      ),
      (
        id: 'TYPH',
        query: 'febre tifóide',
        answer: 'FEBRE TIFÓIDE',
        authority: 'CDC',
        marker: 'Typhoid'
      ),
      (
        id: 'BRUC',
        query: 'brucelose',
        answer: 'BRUCELOSE',
        authority: 'CDC',
        marker: '2026'
      ),
      (
        id: 'RICK',
        query: 'febre maculosa',
        answer: 'FEBRE MACULOSA',
        authority: 'CDC',
        marker: 'Spotted Fever'
      ),
      (
        id: 'MPOX',
        query: 'mpox',
        answer: 'MPOX',
        authority: 'WHO',
        marker: 'Living Guideline'
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
          q: 'leptospirosis Weil disease',
          a: 'LEPTOSPIROSIS',
          marker: 'Leptospirosis'
        ),
        (
          q: 'American trypanosomiasis Trypanosoma cruzi',
          a: 'CHAGAS DISEASE',
          marker: 'Chagas'
        ),
        (
          q: 'visceral leishmaniasis kala-azar',
          a: 'VISCERAL LEISHMANIASIS',
          marker: 'Visceral Leishmaniasis'
        ),
        (q: 'yellow fever', a: 'YELLOW FEVER', marker: 'Yellow Fever'),
        (
          q: 'chikungunya virus disease',
          a: 'CHIKUNGUNYA',
          marker: 'Chikungunya'
        ),
        (q: 'Zika virus disease', a: 'ZIKA', marker: 'Zika'),
        (
          q: 'typhoid fever Salmonella Typhi',
          a: 'TYPHOID FEVER',
          marker: 'Typhoid'
        ),
        (q: 'brucellosis Malta fever', a: 'BRUCELLOSIS', marker: 'Brucellosis'),
        (
          q: 'Rocky Mountain spotted fever RMSF',
          a: 'SPOTTED FEVER RICKETTSIOSIS',
          marker: 'Spotted Fever'
        ),
        (q: 'monkeypox mpox', a: 'MPOX', marker: 'Monkeypox'),
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

    test('precedência específica protege colisões tropicais', () {
      final vl = joined(resolve(
        'leishmaniose visceral kala-azar',
        'LEISHMANIOSE VISCERAL',
      ));
      expect(vl, contains('Visceral Leishmaniasis'));
      expect(vl, contains('2026'));

      final yf = joined(resolve(
        'febre amarela em área com dengue',
        'FEBRE AMARELA',
      ));
      expect(yf, contains('Yellow Fever'));

      final chik = joined(resolve(
        'chikungunya versus dengue',
        'CHIKUNGUNYA',
      ));
      expect(chik, contains('Treatment and Prevention of Chikungunya'));

      final zika = joined(resolve(
        'Zika em gestante com diferencial de dengue',
        'ZIKA',
      ));
      expect(zika, contains('Zika Virus Disease'));

      final typhoid = joined(resolve(
        'febre tifóide com sepse',
        'FEBRE TIFÓIDE',
      ));
      expect(typhoid, contains('Typhoid'));

      final rick = joined(resolve(
        'febre maculosa com sepse',
        'FEBRE MACULOSA',
      ));
      expect(rick, contains('Spotted Fever'));

      final mpox = joined(resolve(
        'mpox com lesões vesiculares',
        'MPOX',
      ));
      expect(mpox, contains('Mpox'));
    });

    test('Batch01–19 permanecem curated-only', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      for (var i = 1; i <= 10; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }
      for (var i = 11; i <= 19; i++) {
        expect(source,
            contains('_top200ExpansionBatch${i}Domains.contains(domain)'));
      }

      for (final domain in <String>[
        'leptospirosis_cdc_2026',
        'chagas_who_paho_2026',
        'visceral_leishmaniasis_who_2026',
        'yellow_fever_who_cdc_2026',
        'chikungunya_who_cdc_2026',
        'zika_who_cdc_2025',
        'typhoid_fever_cdc_2026',
        'brucellosis_cdc_2026',
        'spotted_fever_rickettsiosis_cdc_2025',
        'mpox_who_cdc_2026',
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
