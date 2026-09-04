import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/plantao_pipeline.dart';

String matrixFor(PlantaoQueryAnalysis qa) {
  final mandate = PlantaoIntentEngine.buildIntentMandateV2(qa, 'es');
  return RegExp(
        r'USE EXCLUSIVAMENTE A MATRIZ\s+(\d+)',
        caseSensitive: false,
      ).firstMatch(mandate)?.group(1) ??
      'UNRESOLVED';
}

void expectEquivalentRoute(String a, String b) {
  final qaA = PlantaoIntentEngine.analyze(a);
  final qaB = PlantaoIntentEngine.analyze(b);

  expect(
    qaA.primaryIntent,
    qaB.primaryIntent,
    reason: 'primaryIntent divergiu: "$a" × "$b"',
  );
  expect(
    qaA.clinicalContext,
    qaB.clinicalContext,
    reason: 'clinicalContext divergiu: "$a" × "$b"',
  );
  expect(
    matrixFor(qaA),
    matrixFor(qaB),
    reason: 'matriz divergiu: "$a" × "$b"',
  );
}

void main() {
  group('Plantão semantic normalization ES/PT V1-B-R0', () {
    test('7 audited ES/PT parity pairs converge', () {
      const pairs = <(String, String)>[
        (
          'Tratamiento de metrorragia gestacional',
          'Tratamento da metrorragia gestacional',
        ),
        (
          'Manejo de metrorragia gestacional',
          'Manejo da metrorragia gestacional',
        ),
        (
          'Conducta en metrorragia gestacional',
          'Conduta na metrorragia gestacional',
        ),
        (
          'Qué hacer en metrorragia gestacional',
          'O que fazer na metrorragia gestacional',
        ),
        (
          'Tratamiento de hiperkalemia grave',
          'Tratamento da hipercalemia grave',
        ),
        (
          'Manejo de hiperkalemia grave',
          'Manejo da hipercalemia grave',
        ),
        (
          'Conducta en hiperkalemia grave',
          'Conduta na hipercalemia grave',
        ),
      ];

      for (final pair in pairs) {
        expectEquivalentRoute(pair.$1, pair.$2);
      }
    });

    test('metrorragia management synonyms converge to conduta + matrix 1', () {
      const queries = <String>[
        'Tratamiento de metrorragia gestacional',
        'Manejo de metrorragia gestacional',
        'Conducta en metrorragia gestacional',
        'Qué hacer en metrorragia gestacional',
        'Que hacer en metrorragia gestacional',
        'Tratamento da metrorragia gestacional',
        'Manejo da metrorragia gestacional',
        'Conduta na metrorragia gestacional',
        'O que fazer na metrorragia gestacional',
      ];

      for (final query in queries) {
        final qa = PlantaoIntentEngine.analyze(query);
        expect(
          qa.primaryIntent,
          PlantaoIntent.conduta,
          reason: query,
        );
        expect(matrixFor(qa), '1', reason: query);
      }
    });

    test('potassium spelling variants converge to electrolyte context', () {
      const queries = <String>[
        'Hiperkalemia grave',
        'Hiperkaliemia grave',
        'Hipercaliemia grave',
        'Hyperkalemia grave',
        'Hiperpotasemia grave',
        'Hipercalemia grave',
      ];

      for (final query in queries) {
        final qa = PlantaoIntentEngine.analyze(query);
        expect(
          qa.clinicalContext,
          PlantaoContext.eletrolitos,
          reason: query,
        );
        expect(matrixFor(qa), '5', reason: query);
      }
    });

    test('treatment plus potassium keeps conduta primary deterministically',
        () {
      const queries = <String>[
        'Tratamiento de hiperkalemia grave',
        'Manejo de hiperkalemia grave',
        'Conducta en hiperkalemia grave',
        'Tratamento da hipercalemia grave',
        'Manejo da hipercalemia grave',
        'Conduta na hipercalemia grave',
      ];

      for (final query in queries) {
        final qa = PlantaoIntentEngine.analyze(query);
        expect(qa.primaryIntent, PlantaoIntent.conduta, reason: query);
        expect(qa.clinicalContext, PlantaoContext.eletrolitos, reason: query);
        expect(matrixFor(qa), '5', reason: query);
      }
    });

    test('legacy classifier also receives the shared ES/PT normalization', () {
      expect(
        PlantaoIntentClassifier.classify(
          'Tratamiento de metrorragia gestacional',
        ).intent,
        PlantaoIntent.conduta,
      );
      expect(
        PlantaoIntentClassifier.classify(
          'Conducta en metrorragia gestacional',
        ).intent,
        PlantaoIntent.conduta,
      );
      expect(
        PlantaoIntentClassifier.classify(
          'Qué hacer en metrorragia gestacional',
        ).intent,
        PlantaoIntent.conduta,
      );

      expect(
        PlantaoIntentClassifier.classify('Hiperkalemia grave').intent,
        PlantaoIntent.eletrolitos,
      );
      expect(
        PlantaoIntentClassifier.classify('Hiperpotasemia grave').intent,
        PlantaoIntent.eletrolitos,
      );
    });
  });
}
