import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/plantao_iamcest_killip_classification_guard.dart';

void main() {
  group('Plantao table intent + IAMCEST Killip composition M55D', () {
    const physicalCase =
        'Paciente de 62 años con IAMCEST confirmado, dolor torácico persistente '
        'y elevación del ST en V2-V5. PA 132/78 mmHg, FC 96 lpm, SpO2 96% '
        'al aire ambiente. Troponina elevada. Sin shock, sin edema agudo de '
        'pulmón y sin paro cardíaco. Analiza el caso e indica la conducta inicial.';

    test('global Plantao structure/table contracts remain retained', () {
      final ai = File('lib/services/ai_service.dart').readAsStringSync();
      final renderer = File(
        'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
      ).readAsStringSync();
      expect(
        ai,
        contains('M55A_GLOBAL_RESPONSE_ORDER_AND_CLASSIFICATION_2COL_TABLE_V1'),
      );
      expect(ai, contains('M55C_ZERO_EMOJI_AI_RESPONSE_CONTRACTS_V1'));
      expect(renderer, contains('PLANTAO_MARKDOWN_TABLE_TRUE_RENDER_V1'));
      expect(renderer, contains('Table('));
      expect(renderer, contains('scrollDirection: Axis.horizontal'));
    });

    test('classification follow-up is canonical 2-column Killip I', () {
      const model =
          'CLASIFICACIÓN DEL PACIENTE\n'
          'Puntos clave:\n'
          '* Clasificación del paciente: IAMCEST.\n'
          '* Sin choque, sin edema agudo de pulmón.';
      final out = PlantaoIamcestKillipClassificationGuard.materialize(
        userInput: '¿Y cuál es la clasificación?',
        assistantOutput: model,
        languageCode: 'es',
        recentUserTurns: const [physicalCase],
      );
      expect(
        out,
        contains('| Criterio / clasificación | Resultado en este paciente |'),
      );
      expect(out, contains('| --- | --- |'));
      expect(out, contains('| Killip | **Clase I** |'));
      expect(out, contains('| Sistema | Killip-Kimball |'));
      expect(out, contains('1967'));
      expect(out, isNot(contains('Clasificación final:')));
    });

    test('explicit table request uses the same canonical 2-column surface', () {
      final out = PlantaoIamcestKillipClassificationGuard.materialize(
        userInput: '¿Y cuál es la clasificación? Hazlo en una tabla.',
        assistantOutput: 'Clasificación final: IAMCEST sin complicaciones.',
        languageCode: 'es',
        recentUserTurns: const [physicalCase],
      );
      expect(
        out,
        contains('| Criterio / clasificación | Resultado en este paciente |'),
      );
      expect(out, contains('| Killip | **Clase I** |'));
      expect(out, isNot(contains('| Clasificación | Gravedad | Fundamento |')));
    });

    test('legacy 3-column IAM table is normalized to canonical 2 columns', () {
      const model =
          '| Clasificación | Gravedad | Fundamento |\n'
          '| --- | --- | --- |\n'
          '| IAMCEST | Killip I | Sin congestión ni shock. |';
      final out = PlantaoIamcestKillipClassificationGuard.materialize(
        userInput: 'Tabla de la clasificación del paciente.',
        assistantOutput: model,
        languageCode: 'es',
        recentUserTurns: const [physicalCase],
      );
      expect(
        out,
        contains('| Criterio / clasificación | Resultado en este paciente |'),
      );
      expect(out, contains('| Killip | **Clase I** |'));
      expect(out, isNot(contains('| Clasificación | Gravedad | Fundamento |')));
    });

    test('insufficient data fails closed except zero-emoji cleanup', () {
      final out = PlantaoIamcestKillipClassificationGuard.materialize(
        userInput: '¿Y cuál es la clasificación?',
        assistantOutput: '📌 Clasificación final: IAMCEST.',
        languageCode: 'es',
        recentUserTurns: const ['Paciente con IAMCEST confirmado por ECG.'],
      );
      expect(out, 'Clasificación final: IAMCEST.');
    });

    // M72C_SUPERSEDES_TEP_CROSS_PATH_EMOJI_CLEANUP_V1
    test('TEP never inherits old IAMCEST and remains byte-exact outside IAM owner', () {
      final out = PlantaoIamcestKillipClassificationGuard.materialize(
        userInput: '¿Cuál es la clasificación del TEP?',
        assistantOutput: '🟥 TEP AGUDO CONFIRMADO — B1',
        languageCode: 'es',
        recentUserTurns: const [
          physicalCase,
          'Nuevo caso: paciente con TEP agudo confirmado por angioTC.',
        ],
      );
      expect(out, '🟥 TEP AGUDO CONFIRMADO — B1');
      expect(out, isNot(contains('IAMCEST')));
    });

    test('management-only follow-up remains clinically untouched', () {
      const model = 'Tratamiento farmacológico completo.';
      final out = PlantaoIamcestKillipClassificationGuard.materialize(
        userInput:
            '¿Y qué tratamiento farmacológico completo indicarías ahora?',
        assistantOutput: model,
        languageCode: 'es',
        recentUserTurns: const [physicalCase],
      );
      expect(out, model);
    });

    test('Killip wiring remains after TEP guard', () {
      final app = File('lib/providers/app_provider.dart').readAsStringSync();
      expect(
        app.indexOf('final tep2026GuardedText ='),
        lessThan(app.indexOf('final iamcestKillipGuardedText =')),
      );
      expect(
        'PlantaoIamcestKillipClassificationGuard.materialize'
            .allMatches(app)
            .length,
        1,
      );
    });
  });
}
