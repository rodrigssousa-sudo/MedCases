import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/data/clinical_crosscutting_evidence_database.dart';
import 'package:medcases/services/clinical_crosscutting_evidence_resolver.dart';

void main() {
  group('Rich cross-cutting clinical evidence database V1', () {
    test('contains at least 10 curated sources with traceable metadata', () {
      expect(
          clinicalCrosscuttingEvidenceSources.length, greaterThanOrEqualTo(10));

      final ids = <String>{};
      for (final source in clinicalCrosscuttingEvidenceSources) {
        expect(source.id.trim(), isNotEmpty);
        expect(ids.add(source.id), isTrue, reason: source.id);
        expect(source.organization.trim(), isNotEmpty);
        expect(source.title.trim(), isNotEmpty);
        expect(source.sourceType.trim(), isNotEmpty);
        expect(source.publicationDate.trim(), isNotEmpty);
        expect(source.url, startsWith('https://'));
      }
    });

    test(
        'fluid maintenance pack prevents invented volume-status classification',
        () {
      final result = ClinicalCrosscuttingEvidenceResolver.enrich(
        query: '''
Paciente adulto de 75 kg, sem comorbidades.
Quanto de fluido de manutenção devo passar por dia?
Resposta anterior: 25–30 mL/kg/dia.
E qual a classificação?
''',
        baseContext: '',
        lang: 'pt',
      );

      expect(result, contains('adult_iv_fluid_therapy'));
      expect(result, contains('25–30 mL/kg/dia'));
      expect(result, contains('manutenção rotineira'));
      expect(result, contains('Peso isolado NÃO classifica'));
      expect(result, contains('NÃO autoriza inferir euvolemia'));
      expect(result, isNot(contains('hidratação adequada em adulto')));
    });

    test('Spanish fluid pack carries the same no-invention boundary', () {
      final result = ClinicalCrosscuttingEvidenceResolver.enrich(
        query: '''
Adulto de 75 kg. ¿Cuánto volumen de mantenimiento?
¿Y cuál es la clasificación?
''',
        baseContext: '',
        lang: 'es',
      );

      expect(result, contains('adult_iv_fluid_therapy'));
      expect(result, contains('mantenimiento rutinario'));
      expect(result, contains('El peso aislado NO clasifica'));
      expect(result, contains('en vez de inventar una clasificación'));
    });

    test('STEMI pack binds P2Y12 loading to reperfusion strategy', () {
      final result = ClinicalCrosscuttingEvidenceResolver.enrich(
        query: '''
Paciente de 68 años con dolor torácico y elevación del ST en V2-V5.
Conducta para IAMCEST, considerar PCI o fibrinólisis.
''',
        baseContext: '',
        lang: 'es',
      );

      expect(result, contains('acs_stemi_reperfusion_antiplatelet'));
      expect(result, contains('Clopidogrel 600 mg'));
      expect(result, contains('NO debe presentarse como carga universal'));
      expect(result, contains('300 mg'));
      expect(result, contains('68 años'));
      expect(result, contains('ambas guías convergen'));
      expect(result, contains('PCI versus fibrinólisis'));
    });

    test('norepinephrine pack corrects outdated central-line-only framing', () {
      final result = ClinicalCrosscuttingEvidenceResolver.enrich(
        query: '''
Paciente en shock séptico con norepinefrina.
¿Cómo preparar y por qué vía iniciar la infusión?
''',
        baseContext: '',
        lang: 'es',
      );

      expect(result, contains('norepinephrine_preparation_and_access'));
      expect(result, contains('primera línea'));
      expect(result, contains('acceso periférico'));
      expect(result, contains('preferible a retrasar'));
      expect(result, contains('4 mg/250 mL'));
      expect(result, contains('8 mg/250 mL'));
      expect(result, contains('extravasación'));
    });

    test('unrelated query receives no evidence injection', () {
      const base = 'BASE_CONTEXT';
      final result = ClinicalCrosscuttingEvidenceResolver.enrich(
        query: 'Paciente com dermatite leve em antebraço.',
        baseContext: base,
        lang: 'pt',
      );
      expect(result, base);
    });

    test(
        'AppProvider injects cross-cutting evidence into all three local RAG paths',
        () {
      final source = File('lib/providers/app_provider.dart').readAsStringSync();

      expect(
        source,
        contains(
            "import '../services/clinical_crosscutting_evidence_resolver.dart';"),
      );
      expect(
        RegExp(r'ClinicalCrosscuttingEvidenceResolver\.enrich\s*\(')
            .allMatches(source)
            .length,
        3,
      );
      expect(source, contains('query: qaExpandedInput'));
      expect(RegExp(r'query:\s+expandedInput').allMatches(source).length, 2);
    });

    test('resolver is data-driven and has no network/provider calls', () {
      final source = File(
        'lib/services/clinical_crosscutting_evidence_resolver.dart',
      ).readAsStringSync();

      for (final forbidden in <String>[
        'FirebaseFirestore',
        'callGpt',
        'gptProxy',
        'Gemini',
        'sendMessage',
        'sendStream',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });
}
