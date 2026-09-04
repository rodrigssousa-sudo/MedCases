import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_service.dart';
import 'package:medcases/services/tep_2026_plantao_response_guard.dart';

void main() {
  group('M55A global response order + classification 2-column table', () {
    test('global initial response contract is strict and bilingual', () {
      final es = AiService.buildM54PhysicalHomologationContractForTesting(
        'Paciente con IAMCEST. Clasifica y define conducta inicial.',
        isEs: true,
      );
      final pt = AiService.buildM54PhysicalHomologationContractForTesting(
        'Paciente com IAMCEST. Classifique e defina conduta inicial.',
        isEs: false,
      );

      expect(es, contains('M55A_ESTRUCTURA_Y_CLASIFICACION_2_COLUMNAS'));
      expect(es, contains('1) PATOLOGÍA/TEMA CLÍNICO'));
      expect(es, contains('2) Conducta inmediata'));
      expect(es, contains('3) Tratamiento farmacológico'));
      expect(es, contains('4) Clasificación'));
      expect(es, contains('5) Puntos clave'));
      expect(es, contains('6) RED FLAGS'));
      expect(
        es,
        contains('| Criterio / clasificación | Resultado en este paciente |'),
      );
      expect(es, contains('| --- | --- |'));

      expect(pt, contains('M55A_ESTRUTURA_E_CLASSIFICACAO_2_COLUNAS'));
      expect(pt, contains('1) PATOLOGIA/TEMA CLÍNICO'));
      expect(pt, contains('2) Conduta imediata'));
      expect(pt, contains('3) Tratamento farmacológico'));
      expect(pt, contains('4) Classificação'));
      expect(
        pt,
        contains('| Critério / classificação | Resultado neste paciente |'),
      );
    });

    test(
      'TEP exact physical C3R uses 2-column classification table and preserves 1,2',
      () {
        const input =
            'Paciente de 68 años con embolia pulmonar aguda confirmada por angio-TC. '
            'PA 118/72 mmHg, FC 118 lpm, FR 32 rpm, SpO2 88% al aire ambiente. '
            'No presentó hipotensión ni paro. La angio-TC muestra relación VD/VI de 1,2 '
            'y la troponina está elevada. Según AHA/ACC 2026 clasifique e indique conducta.';
        final out = Tep2026PlantaoResponseGuard.materialize(
          userInput: input,
          assistantOutput: 'RAW_LEGACY',
          languageCode: 'es',
        );
        expect(out, contains('C3R'));
        expect(out, contains('Clasificación AHA/ACC 2026:'));
        expect(
          out,
          contains('| Criterio / clasificación | Resultado en este paciente |'),
        );
        expect(out, contains('| --- | --- |'));
        expect(out, contains('| Categoría / resultado final | **C3R** |'));
        expect(out, contains('| Modificador respiratorio | **R** |'));
        expect(out, contains('| Relación VD/VI | **1,2** |'));
        expect(out.toLowerCase(), isNot(contains('wells')));
        expect(out, isNot(contains('Clase II')));
      },
    );

    test('true Flutter table renderer remains the rendering owner', () {
      final renderer = File(
        'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
      ).readAsStringSync();
      expect(renderer, contains('PLANTAO_MARKDOWN_TABLE_TRUE_RENDER_V1'));
      expect(renderer, contains('Table('));
      expect(renderer, contains('scrollDirection: Axis.horizontal'));
    });
  });
}
