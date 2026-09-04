import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Guardia compact prompt contract', () {
    final source = File(
      'lib/services/ai_service.dart',
    ).readAsStringSync();

    String extract(
      String startMarker,
      String endMarker,
    ) {
      final start = source.indexOf(startMarker);
      final end = source.indexOf(endMarker, start);

      if (start < 0) {
        throw StateError(
          'guardia_prompt_start_marker_not_found:$startMarker',
        );
      }

      if (end <= start) {
        throw StateError(
          'guardia_prompt_end_marker_not_found:$endMarker',
        );
      }

      return source.substring(start, end);
    }

    final activeContract = extract(
      '      final ptUxFlowDoctrine = isEs',
      '      // ── BUILD 272: CONTEXTO PROPRIETÁRIO MedCases',
    );

    test('possui uma única doutrina e um único formato bilíngue', () {
      expect(
        'final ptUxFlowDoctrine = isEs'.allMatches(source).length,
        1,
      );
      expect(
        'final ptStreamFormat = isEs'.allMatches(source).length,
        1,
      );
    });

    test('exige hierarquia adaptativa bilíngue e preserva rota terapêutica', () {
      for (final label in <String>[
        '🚨 Evaluacion inicial:',
        '🚨 Avaliacao inicial:',
        '🔑 Puntos clave:',
        '🔑 Pontos-chave:',
        '🚩 RED FLAGS:',
        '🚨 Conducta inmediata:',
        '🚨 Conduta imediata:',
        '💊 Tratamiento farmacologico:',
        '💊 Tratamento farmacologico:',
      ]) {
        expect(activeContract, contains(label), reason: label);
      }
    });

    test('sintoma inespecífico usa rota diferencial antes de terapia específica', () {
      for (final token in <String>[
        'ROTA DIFERENCIAL',
        'RUTA DIFERENCIAL',
        'DIFERENCIAIS PRIORITARIOS',
        'DIFERENCIALES PRIORITARIOS',
        'Sintoma isolado não equivale a diagnóstico',
        'Un sintoma aislado no equivale a diagnostico',
        'sem AAS, nitrato, antibiótico, anticoagulante',
        'sin AAS, nitrato, antibiotico, anticoagulante',
      ]) {
        expect(source, contains(token), reason: token);
      }

      expect(
        activeContract,
        contains(
          'na ROTA DIFERENCIAL omita por completo Tratamento farmacologico',
        ),
      );
      expect(
        activeContract,
        contains(
          'en RUTA DIFERENCIAL omite por completo Tratamiento farmacologico',
        ),
      );
    });

    test('diagnóstico confirmado mantém rota terapêutica existente', () {
      expect(activeContract, contains('ROTA TERAPEUTICA'));
      expect(activeContract, contains('RUTA TERAPEUTICA'));
      expect(activeContract, contains('💊 Tratamento farmacologico:'));
      expect(activeContract, contains('💊 Tratamiento farmacologico:'));
    });

    test('remove gancho interno e cards farmacológicos antigos', () {
      for (final forbidden in <String>[
        'Próximo',
        'Siguiente paso',
        'T-FARMACO-CARD',
        'Dosis Habitual',
        'Dose Habitual',
        'Mecanismo de Acción',
        'Mecanismo de Ação',
        'DOBLE SALTO OBLIGATORIO',
        'DUPLA QUEBRA OBRIGATORIA',
      ]) {
        expect(activeContract, isNot(contains(forbidden)));
      }
    });

    test('delega continuidade exclusivamente ao botão azul', () {
      expect(activeContract, contains('boton azul del frontend'));
      expect(activeContract, contains('botao azul do frontend'));
      expect(
        activeContract,
        contains('No agregues preguntas finales'),
      );
      expect(
        activeContract,
        contains('Nao acrescente perguntas finais'),
      );
    });

    test('remove placeholders quadrados do contrato de saída', () {
      expect(activeContract, contains('🟥 DIAGNOSTICO EN MAYUSCULAS'));
      expect(activeContract, contains('🟥 DIAGNOSTICO EM MAIUSCULAS'));
      expect(activeContract, isNot(contains('🟥 [DIAGNOSTICO')));
      expect(activeContract, isNot(contains('🟥 [SINTOMA')));
      expect(activeContract, isNot(contains('**Farmaco + dose + via** [indicacao')));
      expect(activeContract, isNot(contains('**Farmaco + dosis + via** [indicacion')));
    });

    test('dados não informados permanecem desconhecidos', () {
      expect(activeContract, contains('DADO NAO INFORMADO = DESCONHECIDO'));
      expect(activeContract, contains('DATO NO INFORMADO = DESCONOCIDO'));
      expect(activeContract, contains('nunca transforme ausencia de informacao em achado negativo ou positivo'));
      expect(activeContract, contains('nunca conviertas ausencia de informacion en hallazgo negativo o positivo'));
    });

    test('não altera o limite entre Guardia e Estudo', () {
      final assembly = extract(
        '      // ── PLANTÃO ASSEMBLY',
        '      // ══ END PLANTÃO EARLY-RETURN',
      );

      expect(assembly, contains(r'$ptStreamFormat'));
      expect(assembly, contains(r'$ptUxFlowDoctrine'));
      expect(
        source,
        contains(
          '// ══ END PLANTÃO EARLY-RETURN — code below is ESTUDO only ══',
        ),
      );
    });

    test('mantém roteamento fora do proprietário do formato', () {
      final router = File(
        'lib/services/ai_smart_router.dart',
      ).readAsStringSync();

      expect(router, contains('CONTRACT_PLANTAO'));
      expect(router, isNot(contains('ptStreamFormat')));
    });
  });
}
