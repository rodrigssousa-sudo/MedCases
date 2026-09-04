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

  group('Top200 Expansion Batch17 nephrology urology V1-B-R0', () {
    final cases = <({
      String id,
      String query,
      String answer,
      String authority,
      String marker,
    })>[
      (
        id: 'PSGN',
        query: 'glomerulonefrite pós-estreptocócica',
        answer: 'GLOMERULONEFRITE PÓS-ESTREPTOCÓCICA',
        authority: 'KDIGO',
        marker: 'Infection-Related'
      ),
      (
        id: 'AGBM',
        query: 'síndrome de Goodpasture anti-GBM',
        answer: 'DOENÇA ANTI-GBM',
        authority: 'KDIGO',
        marker: 'Anti-GBM'
      ),
      (
        id: 'MN',
        query: 'nefropatia membranosa',
        answer: 'NEFROPATIA MEMBRANOSA',
        authority: 'KDIGO',
        marker: 'Membranous'
      ),
      (
        id: 'FSGS',
        query: 'glomeruloesclerose segmentar e focal',
        answer: 'FSGS',
        authority: 'KDIGO',
        marker: 'FSGS'
      ),
      (
        id: 'HUS',
        query: 'síndrome hemolítico-urêmica atípica',
        answer: 'SHU ATÍPICA',
        authority: 'KDIGO',
        marker: 'Atypical HUS'
      ),
      (
        id: 'AIN',
        query: 'nefrite intersticial aguda',
        answer: 'NEFRITE INTERSTICIAL AGUDA',
        authority: 'Clinical Kidney Journal',
        marker: '2024'
      ),
      (
        id: 'RTA',
        query: 'acidose tubular renal',
        answer: 'ACIDOSE TUBULAR RENAL',
        authority: 'American Journal of Kidney Diseases',
        marker: '2025'
      ),
      (
        id: 'IC',
        query: 'cistite intersticial síndrome da dor vesical',
        answer: 'CISTITE INTERSTICIAL / BPS',
        authority: 'EAU',
        marker: '2026'
      ),
      (
        id: 'BPH',
        query: 'hiperplasia prostática benigna',
        answer: 'HIPERPLASIA PROSTÁTICA BENIGNA',
        authority: 'EAU',
        marker: '2026'
      ),
      (
        id: 'PROS',
        query: 'prostatite bacteriana',
        answer: 'PROSTATITE BACTERIANA',
        authority: 'EAU',
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

        for (final line in urls) {
          final url = line.substring(line.indexOf('https://')).trim();
          final uri = Uri.tryParse(url);
          expect(uri, isNotNull, reason: '${c.id}:$url');
          expect(uri!.scheme, 'https', reason: '${c.id}:$url');
          expect(uri.host, isNotEmpty, reason: '${c.id}:$url');
        }
      }
    });

    test('aliases PT ES EN mantêm identidade temática', () {
      final probes = <({String q, String a, String marker})>[
        (
          q: 'post-streptococcal glomerulonephritis',
          a: 'POST-STREPTOCOCCAL GLOMERULONEPHRITIS',
          marker: 'Infection-Related'
        ),
        (
          q: 'Goodpasture syndrome anti-GBM disease',
          a: 'ANTI-GBM DISEASE',
          marker: 'Anti-GBM'
        ),
        (
          q: 'membranous nephropathy',
          a: 'MEMBRANOUS NEPHROPATHY',
          marker: 'Membranous'
        ),
        (
          q: 'focal segmental glomerulosclerosis FSGS',
          a: 'FSGS',
          marker: 'FSGS'
        ),
        (
          q: 'atypical hemolytic uremic syndrome aHUS',
          a: 'ATYPICAL HUS',
          marker: 'Atypical HUS'
        ),
        (
          q: 'acute interstitial nephritis',
          a: 'ACUTE INTERSTITIAL NEPHRITIS',
          marker: 'Acute Interstitial'
        ),
        (
          q: 'renal tubular acidosis',
          a: 'RENAL TUBULAR ACIDOSIS',
          marker: 'Core Curriculum 2025'
        ),
        (
          q: 'interstitial cystitis bladder pain syndrome',
          a: 'IC BPS',
          marker: 'Bladder Pain'
        ),
        (q: 'benign prostatic hyperplasia BPH', a: 'BPH', marker: 'Male LUTS'),
        (
          q: 'acute bacterial prostatitis',
          a: 'BACTERIAL PROSTATITIS',
          marker: 'Bacterial Prostatitis'
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

    test('precedência específica protege colisões nefro-urológicas', () {
      final hus = joined(resolve(
        'síndrome hemolítico-urêmica atípica com microangiopatia trombótica',
        'SHU ATÍPICA',
      ));
      expect(hus, contains('Atypical HUS'));

      final antiGbm = joined(resolve(
        'síndrome de Goodpasture anti-GBM com hemorragia alveolar',
        'DOENÇA ANTI-GBM',
      ));
      expect(antiGbm, contains('Anti-GBM'));

      final mn = joined(resolve(
        'síndrome nefrótica por nefropatia membranosa',
        'NEFROPATIA MEMBRANOSA',
      ));
      expect(mn, contains('Membranous'));

      final fsgs = joined(resolve(
        'síndrome nefrótica por FSGS',
        'FSGS',
      ));
      expect(fsgs, contains('FSGS'));

      final ain = joined(resolve(
        'lesão renal aguda por nefrite intersticial aguda',
        'NEFRITE INTERSTICIAL AGUDA',
      ));
      expect(ain, contains('Acute Interstitial'));

      final ic = joined(resolve(
        'cistite intersticial com dor vesical crônica',
        'CISTITE INTERSTICIAL',
      ));
      expect(ic, contains('Bladder Pain'));

      final prostatitis = joined(resolve(
        'prostatite bacteriana aguda com sintomas urinários',
        'PROSTATITE BACTERIANA',
      ));
      expect(prostatitis, contains('Bacterial Prostatitis'));

      final bph = joined(resolve(
        'hiperplasia prostática benigna com LUTS',
        'HIPERPLASIA PROSTÁTICA BENIGNA',
      ));
      expect(bph, contains('Male LUTS'));
    });

    test('Batch01–17 permanecem curated-only', () {
      final source = File(
        'lib/screens/ai/widgets/clinical_reference_resolver.dart',
      ).readAsStringSync();

      for (var i = 1; i <= 10; i++) {
        final id = i.toString().padLeft(2, '0');
        expect(source, contains('_top150Batch${id}Domains.contains(domain)'));
      }
      for (var i = 11; i <= 17; i++) {
        expect(source,
            contains('_top200ExpansionBatch${i}Domains.contains(domain)'));
      }

      for (final domain in <String>[
        'poststreptococcal_infection_related_gn_kdigo',
        'anti_gbm_goodpasture_kdigo',
        'membranous_nephropathy_kdigo',
        'fsgs_kdigo',
        'hemolytic_uremic_syndrome_complement_2026',
        'acute_interstitial_nephritis_2024',
        'renal_tubular_acidosis_core_2025',
        'interstitial_cystitis_bladder_pain_2026',
        'benign_prostatic_hyperplasia_luts_2026',
        'bacterial_prostatitis_eau_2026',
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
