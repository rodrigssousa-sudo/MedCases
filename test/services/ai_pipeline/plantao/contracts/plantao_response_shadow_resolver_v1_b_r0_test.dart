import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_response_contract.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_response_shadow_resolver.dart';
import 'package:medcases/services/plantao_pipeline.dart';

void expectUncontestedModel(
  Iterable<String> queries,
  PlantaoResponseModelId expected,
) {
  for (final query in queries) {
    final resolved = PlantaoResponseShadowResolver.resolveUserMessage(
      query,
      languageCode: 'es',
    );

    expect(resolved.hasStructuralConflict, isFalse, reason: query);
    expect(resolved.specialTemplateModelId, isNull, reason: query);
    expect(resolved.responseModelId, expected, reason: query);
    expect(resolved.contract?.id, expected, reason: query);
    expect(resolved.legacyMatrixModelId, expected, reason: query);
    expect(
      resolved.signals,
      {PlantaoShadowStructuralSignal.legacyMatrix},
      reason: query,
    );
  }
}

void main() {
  group('Plantao response shadow resolver V1-B-R1', () {
    test('metrorrhagia management synonyms converge without conflict', () {
      expectUncontestedModel(
        const [
          'Tratamiento de metrorragia gestacional',
          'Manejo de metrorragia gestacional',
          'Conducta en metrorragia gestacional',
          'Qué hacer en metrorragia gestacional',
          'Que hacer en metrorragia gestacional',
          'Tratamento da metrorragia gestacional',
          'Manejo da metrorragia gestacional',
          'Conduta na metrorragia gestacional',
          'O que fazer na metrorragia gestacional',
        ],
        PlantaoResponseModelId.casoClinicoEmergencia,
      );
    });

    test('potassium spelling variants converge without conflict', () {
      expectUncontestedModel(
        const [
          'Hiperkalemia grave',
          'Hiperkaliemia grave',
          'Hipercaliemia grave',
          'Hyperkalemia grave',
          'Hiperpotasemia grave',
          'Hipercalemia grave',
        ],
        PlantaoResponseModelId.disturbioEletrolitico,
      );
    });

    test('potassium management synonyms keep one electrolyte model', () {
      expectUncontestedModel(
        const [
          'Tratamiento de hiperkalemia grave',
          'Manejo de hiperkalemia grave',
          'Conducta en hiperkalemia grave',
          'Tratamento da hipercalemia grave',
          'Manejo da hipercalemia grave',
          'Conduta na hipercalemia grave',
        ],
        PlantaoResponseModelId.disturbioEletrolitico,
      );
    });

    test('TEP action wording converges without conflict', () {
      expectUncontestedModel(
        const [
          'Tratamiento TEP',
          'Manejo TEP',
          'Conducta en TEP',
          'Qué hacer en TEP',
          'Tratamento TEP',
          'Manejo TEP',
          'Conduta no TEP',
          'O que fazer no TEP',
        ],
        PlantaoResponseModelId.casoClinicoEmergencia,
      );
    });

    test('shock/sepsis action route is uncontested', () {
      expectUncontestedModel(
        const [
          'Tratamiento de sepsis con shock',
          'Manejo de sepsis con shock',
          'Tratamento da sepse com choque',
        ],
        PlantaoResponseModelId.choque,
      );
    });

    test('dose heparin for TEP observes current matrix without conflict', () {
      final resolved = PlantaoResponseShadowResolver.resolveUserMessage(
        'Dosis de heparina no fraccionada en TEP',
        languageCode: 'es',
      );

      expect(resolved.legacyMatrixNumber, 1);
      expect(
        resolved.legacyMatrixModelId,
        PlantaoResponseModelId.casoClinicoEmergencia,
      );
      expect(resolved.hasStructuralConflict, isFalse);
      expect(
        resolved.responseModelId,
        PlantaoResponseModelId.casoClinicoEmergencia,
      );
    });

    test('isolated amiodarone exposes matrix/template structural conflict', () {
      final resolved = PlantaoResponseShadowResolver.resolveUserMessage(
        'Amiodarona',
        languageCode: 'es',
      );

      expect(resolved.legacyMatrixNumber, 4);
      expect(resolved.legacyMatrixModelId, PlantaoResponseModelId.arritmia);
      expect(
        resolved.specialTemplateModelId,
        PlantaoResponseModelId.farmacoIsolado,
      );
      expect(resolved.hasStructuralConflict, isTrue);
      expect(resolved.responseModelId, isNull);
      expect(resolved.contract, isNull);
      expect(
        resolved.signals,
        {
          PlantaoShadowStructuralSignal.legacyMatrix,
          PlantaoShadowStructuralSignal.isolatedDrugSpecialTemplate,
        },
      );
    });

    test('nine audited isolated drugs expose the same dual-authority conflict',
        () {
      const cases = <(String, int, PlantaoResponseModelId)>[
        ('Amiodarona', 4, PlantaoResponseModelId.arritmia),
        ('Adenosina', 4, PlantaoResponseModelId.arritmia),
        ('Noradrenalina', 15, PlantaoResponseModelId.choque),
        ('Ceftriaxona', 8, PlantaoResponseModelId.sepseChoqueSeptico),
        ('Midazolam', 21, PlantaoResponseModelId.consultaClinicaGeral),
        ('Fentanil', 21, PlantaoResponseModelId.consultaClinicaGeral),
        ('Furosemida', 1, PlantaoResponseModelId.casoClinicoEmergencia),
        ('Enoxaparina', 1, PlantaoResponseModelId.casoClinicoEmergencia),
        ('Ketamina', 16, PlantaoResponseModelId.viaAereaVentilacaoMecanica),
      ];

      for (final item in cases) {
        final resolved = PlantaoResponseShadowResolver.resolveUserMessage(
          item.$1,
          languageCode: 'es',
        );

        expect(resolved.legacyMatrixNumber, item.$2, reason: item.$1);
        expect(resolved.legacyMatrixModelId, item.$3, reason: item.$1);
        expect(
          resolved.specialTemplateModelId,
          PlantaoResponseModelId.farmacoIsolado,
          reason: item.$1,
        );
        expect(resolved.hasStructuralConflict, isTrue, reason: item.$1);
        expect(resolved.responseModelId, isNull, reason: item.$1);

        print(
          '[SHADOW_STRUCTURAL_CONFLICT]'
          '|query=${item.$1}'
          '|legacyMatrix=${resolved.legacyMatrixNumber}'
          '|legacyModel=${resolved.legacyMatrixModelId.wireName}'
          '|specialModel=${resolved.specialTemplateModelId?.wireName}'
          '|canonicalCandidate=${resolved.responseModelId?.wireName ?? "NONE"}',
        );
      }
    });

    test('magnesium sulfate remains electrolyte and has no special template',
        () {
      final resolved = PlantaoResponseShadowResolver.resolveUserMessage(
        'Sulfato de magnésio',
        languageCode: 'es',
      );

      expect(resolved.legacyMatrixNumber, 5);
      expect(
        resolved.legacyMatrixModelId,
        PlantaoResponseModelId.disturbioEletrolitico,
      );
      expect(resolved.specialTemplateModelId, isNull);
      expect(resolved.hasStructuralConflict, isFalse);
      expect(
        resolved.responseModelId,
        PlantaoResponseModelId.disturbioEletrolitico,
      );
    });

    test('Spanish infusion wording can expose a classifier/template conflict',
        () {
      final analysis = PlantaoIntentEngine.analyze(
        'Infusión de noradrenalina en shock',
      );
      final resolved = PlantaoResponseShadowResolver.resolveAnalysis(
        analysis,
        languageCode: 'es',
      );

      print(
        '[SHADOW_LANGUAGE_BACKLOG]'
        '|query=Infusión de noradrenalina en shock'
        '|intent=${analysis.primaryIntent.name}'
        '|context=${analysis.clinicalContext.name}'
        '|legacyMatrix=${resolved.legacyMatrixNumber}'
        '|legacyModel=${resolved.legacyMatrixModelId.wireName}'
        '|specialModel=${resolved.specialTemplateModelId?.wireName}'
        '|conflict=${resolved.hasStructuralConflict}',
      );

      // Observational: do not adjudicate ES "infusión" in this build.
    });

    test('language changes labels, not an uncontested model identity', () {
      const query = 'Tratamiento de hiperkalemia grave';

      final es = PlantaoResponseShadowResolver.resolveUserMessage(
        query,
        languageCode: 'es',
      );
      final pt = PlantaoResponseShadowResolver.resolveUserMessage(
        query,
        languageCode: 'pt',
      );

      expect(es.hasStructuralConflict, isFalse);
      expect(pt.hasStructuralConflict, isFalse);
      expect(es.responseModelId, pt.responseModelId);
      expect(es.legacyMatrixNumber, pt.legacyMatrixNumber);
      expect(es.contract?.titleTemplate.forLanguage('es'), isNotEmpty);
      expect(pt.contract?.titleTemplate.forLanguage('pt'), isNotEmpty);
    });

    test('known context precedence cases remain observational backlog', () {
      final fa = PlantaoIntentEngine.analyze(
        'FA com resposta ventricular rápida',
      );
      final tepHypoxemia = PlantaoIntentEngine.analyze(
        'TEP com hipoxemia',
      );

      final faShadow = PlantaoResponseShadowResolver.resolveAnalysis(fa);
      final tepShadow = PlantaoResponseShadowResolver.resolveAnalysis(
        tepHypoxemia,
      );

      print(
        '[SHADOW_CONTEXT_BACKLOG]'
        '|case=FA_START'
        '|context=${fa.clinicalContext.name}'
        '|legacyMatrix=${faShadow.legacyMatrixNumber}'
        '|legacyModel=${faShadow.legacyMatrixModelId.wireName}'
        '|candidate=${faShadow.responseModelId?.wireName ?? "NONE"}',
      );

      print(
        '[SHADOW_CONTEXT_BACKLOG]'
        '|case=TEP_WITH_HYPOXEMIA'
        '|context=${tepHypoxemia.clinicalContext.name}'
        '|legacyMatrix=${tepShadow.legacyMatrixNumber}'
        '|legacyModel=${tepShadow.legacyMatrixModelId.wireName}'
        '|candidate=${tepShadow.responseModelId?.wireName ?? "NONE"}',
      );
    });
  });
}
