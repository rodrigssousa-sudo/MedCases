import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/clinical_session_memory.dart';
import 'package:medcases/services/clinical_thread_manager.dart';
import 'package:medcases/services/tep_2026_plantao_response_guard.dart';

const b1Case =
    'Paciente de 42 anos, TEP agudo confirmado por angioTC, sintomatico, '
    'com embolia subsegmentar isolada. PA 124/76 mmHg, FC 82 bpm, '
    'FR 18/min, SpO2 96% em ar ambiente. sPESI = 0. '
    'Ecocardiograma sem disfuncao de VD, troponina e BNP normais, '
    'lactato 1,2 mmol/L. Sem sinais de hipoperfusao. '
    'Doppler de membros inferiores sem TVP proximal.';

void main() {
  group('Plantao context anchor + TEP full classification V1-B-R0', () {
    test(
      'physical Spanish follow-up sequence remains in the active TEP case',
      () {
        final manager = ClinicalThreadManager();

        final first = manager.evaluate(
          currentUserText: b1Case,
          isPlantaoMode: true,
        );
        expect(first.action, ThreadAction.newThread);

        for (final query in const <String>[
          '¿Y cuál es la clasificación?',
          '¿Por qué corresponde a esa categoría?',
          '¿Necesita internación?',
          '¿Y trombólisis?',
          '¿Y qué harías con la anticoagulación?',
          '¿En este paciente se podría considerar manejo ambulatorio?',
        ]) {
          final status = manager.evaluate(
            currentUserText: query,
            isPlantaoMode: true,
          );
          expect(status.action, ThreadAction.continueThread, reason: query);
        }
      },
    );

    test('ClinicalSessionMemory does not reset across the same sequence', () {
      final memory = ClinicalSessionMemory();
      expect(memory.resetIfTopicChanged(b1Case), isFalse);

      for (final query in const <String>[
        '¿Y cuál es la clasificación?',
        '¿Por qué corresponde a esa categoría?',
        '¿Necesita internación?',
        '¿Y trombólisis?',
        '¿Y qué harías con la anticoagulación?',
        '¿En este paciente se podría considerar manejo ambulatorio?',
      ]) {
        expect(memory.resetIfTopicChanged(query), isFalse, reason: query);
      }
    });

    test(
      'Plantao transport keeps original case anchor after many follow-ups',
      () {
        final manager = ClinicalThreadManager();
        manager.evaluate(currentUserText: b1Case, isPlantaoMode: true);

        final status = manager.evaluate(
          currentUserText:
              '¿En este paciente se podría considerar manejo ambulatorio?',
          isPlantaoMode: true,
        );

        final history = <Map<String, String>>[
          {'role': 'user', 'content': b1Case},
          {'role': 'assistant', 'content': 'B1 + conducta inicial'},
          {'role': 'user', 'content': '¿Y cuál es la clasificación?'},
          {'role': 'assistant', 'content': 'Clasificación completa B1'},
          {'role': 'user', 'content': '¿Por qué corresponde a esa categoría?'},
          {'role': 'assistant', 'content': 'Por criterios B1'},
          {'role': 'user', 'content': '¿Necesita internación?'},
          {'role': 'assistant', 'content': 'Evaluar manejo ambulatorio'},
          {'role': 'user', 'content': '¿Y trombólisis?'},
          {'role': 'assistant', 'content': 'No de rutina'},
          {'role': 'user', 'content': '¿Y qué harías con la anticoagulación?'},
          {'role': 'assistant', 'content': 'Individualizar anticoagulación'},
        ];

        final sent = ClinicalThreadManager.buildThreadHistory(
          fullHistory: history,
          status: status,
          isPlantaoMode: true,
        );

        expect(sent.length, lessThanOrEqualTo(6));
        expect(
          sent.any((m) => m['role'] == 'user' && m['content'] == b1Case),
          isTrue,
        );
        expect(
          sent.any(
            (m) =>
                m['role'] == 'assistant' &&
                m['content'] == 'B1 + conducta inicial',
          ),
          isTrue,
        );
      },
    );

    test('direct classification renders the complete A-E plus R framework', () {
      final out = Tep2026PlantaoResponseGuard.materialize(
        userInput: '¿Y cuál es la clasificación?',
        assistantOutput: 'RESPUESTA MODELO CORTA',
        languageCode: 'es',
        recentUserTurns: const [b1Case],
      );

      expect(out, contains('CLASIFICACIÓN AHA/ACC 2026'));
      expect(out, contains('Categoría del paciente: B1'));
      expect(out, contains('**A — Subclínico:**'));
      expect(out, contains('**B1:** subsegmentario.'));
      expect(out, contains('**B2:** segmentario o más proximal.'));
      expect(out, contains('**C1:**'));
      expect(out, contains('**C2:**'));
      expect(out, contains('**C3:**'));
      expect(out, contains('**D1:**'));
      expect(out, contains('**D2:**'));
      expect(out, contains('**E1:**'));
      expect(out, contains('**E2:**'));
      expect(out, contains('**R:**'));
      expect(out, contains('Clasificación final de este paciente: **B1**'));
      expect(out, contains('Clasificación del paciente:'));
      expect(out, isNot(contains('🚨 Conducta inmediata:')));
      expect(out, contains('Puntos clave:'));
      expect(out, contains('RED FLAGS:'));
      expect(out.length, greaterThan(1000));
    });

    test(
      'explanatory category question is not hijacked by classification renderer',
      () {
        const raw =
            'B1 corresponde por ser un TEP subsegmentario sintomático con baja severidad.';
        final out = Tep2026PlantaoResponseGuard.materialize(
          userInput: '¿Por qué corresponde a esa categoría?',
          assistantOutput: raw,
          languageCode: 'es',
          recentUserTurns: const [b1Case],
        );

        expect(out, raw);
      },
    );

    test('classify plus management still uses complete management renderer', () {
      final out = Tep2026PlantaoResponseGuard.materialize(
        userInput:
            '$b1Case Clasifica el TEP según AHA/ACC 2026 e indica la conducta.',
        assistantOutput: 'RAW',
        languageCode: 'es',
      );

      expect(out, contains('TEP AGUDO CONFIRMADO — B1'));
      expect(out, contains('Conducta inmediata:'));
      expect(out, contains('NO realizar trombólisis'));
      expect(out, isNot(contains('**A — Subclínico:**')));
    });

    test('explicit new case still breaks inheritance', () {
      final manager = ClinicalThreadManager();
      manager.evaluate(currentUserText: b1Case, isPlantaoMode: true);

      final next = manager.evaluate(
        currentUserText:
            'Nuevo caso: paciente con meningitis bacteriana. ¿Necesita internación?',
        isPlantaoMode: true,
      );

      expect(next.action, ThreadAction.newThread);
    });

    test('first-message dependent phrase still has no old case to inherit', () {
      final manager = ClinicalThreadManager();
      final first = manager.evaluate(
        currentUserText: '¿Y trombólisis?',
        isPlantaoMode: true,
      );
      expect(first.action, ThreadAction.newThread);
    });
  });
}
