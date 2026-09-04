import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_service.dart';

void main() {
  group('M55B R2 bronchiolitis + anaphylaxis clinical consistency', () {
    test(
      'bronchiolitis ES is supportive care first and forbids persistent wheeze salbutamol indication',
      () {
        final es = AiService.buildM54PhysicalHomologationContractForTesting(
          'Lactante de 4 meses con bronquiolitis aguda, primer episodio de sibilancias, sin asma.',
          isEs: true,
        );
        expect(es, contains('M55B_BRONQUIOLITIS_SUPPORTIVE_CARE'));
        expect(es, contains('manejo de rutina es principalmente de SOPORTE'));
        expect(es, contains('NO indicar salbutamol/albuterol de rutina'));
        expect(
          es,
          contains('sibilancias persistentes POR SÍ SOLAS NO son indicación'),
        );
        expect(es, contains('PROHIBIDO escribir que salbutamol'));
        expect(es, contains('NO usar corticoides de rutina'));
        expect(
          es,
          contains('NO usar antibióticos salvo sospecha/confirmación'),
        );
        expect(es, contains('SpO2 permanece <90%'));
        expect(es, contains('NO reinterpretar automáticamente como asma'));
      },
    );

    test('bronchiolitis PT parity', () {
      final pt = AiService.buildM54PhysicalHomologationContractForTesting(
        'Lactente de 4 meses com bronquiolite aguda, primeiro episódio de sibilância, sem asma.',
        isEs: false,
      );
      expect(pt, contains('M55B_BRONQUIOLITE_SUPORTE'));
      expect(pt, contains('manejo de rotina é principalmente de SUPORTE'));
      expect(pt, contains('NÃO indicar salbutamol/albuterol de rotina'));
      expect(
        pt,
        contains('sibilância persistente ISOLADAMENTE NÃO é indicação'),
      );
      expect(pt, contains('NÃO usar corticoide de rotina'));
      expect(pt, contains('NÃO usar antibiótico salvo suspeita/confirmação'));
    });

    test('anaphylaxis ES forces IM epinephrine as visible priority 1', () {
      final es = AiService.buildM54PhysicalHomologationContractForTesting(
        'Mujer con anafilaxia y choque tras maní. Define conducta inmediata.',
        isEs: true,
      );
      expect(es, contains('M55B_ANAFILAXIS_FIRST_ACTION_PRIORITY'));
      expect(es, contains('PRIMERA acción terapéutica visible'));
      expect(es, contains('ADRENALINA/EPINEFRINA IM'));
      expect(es, contains('ANTES de posición, oxígeno, acceso IV o fluidos'));
      expect(es, contains('ADRENALINA IM es el ítem 1'));
      expect(es, contains('NO sustituyen ni retrasan adrenalina IM'));
    });

    test('anaphylaxis PT parity', () {
      final pt = AiService.buildM54PhysicalHomologationContractForTesting(
        'Paciente com anafilaxia e choque após amendoim. Defina conduta imediata.',
        isEs: false,
      );
      expect(pt, contains('M55B_ANAFILAXIA_PRIORIDADE_PRIMEIRA_ACAO'));
      expect(pt, contains('PRIMEIRA ação terapêutica visível'));
      expect(pt, contains('ADRENALINA/EPINEFRINA IM'));
      expect(pt, contains('ANTES de posição, oxigênio, acesso IV ou fluidos'));
      expect(pt, contains('ADRENALINA IM é o item 1'));
    });

    test(
      'unrelated TEP does not receive bronchiolitis/anaphylaxis clinical contract',
      () {
        final es = AiService.buildM54PhysicalHomologationContractForTesting(
          'Paciente con TEP agudo confirmado. Clasifique AHA/ACC 2026.',
          isEs: true,
        );
        expect(es, isNot(contains('M55B_BRONQUIOLITIS_SUPPORTIVE_CARE')));
        expect(es, isNot(contains('M55B_ANAFILAXIS_FIRST_ACTION_PRIORITY')));
        expect(es, contains('M55A_ESTRUCTURA_Y_CLASIFICACION_2_COLUMNAS'));
      },
    );
  });
}
