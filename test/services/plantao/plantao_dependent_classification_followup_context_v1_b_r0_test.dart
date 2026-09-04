import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/clinical_session_memory.dart';
import 'package:medcases/services/clinical_thread_manager.dart';
import 'package:medcases/services/tep_2026_plantao_response_guard.dart';

const _b1Case =
    'Paciente de 42 anos, TEP agudo confirmado por angioTC, sintomatico, '
    'com embolia subsegmentar isolada. PA 124/76 mmHg, FC 82 bpm, '
    'FR 18/min, SpO2 96% em ar ambiente. sPESI = 0. '
    'Ecocardiograma sem disfuncao de VD, troponina e BNP normais, '
    'lactato 1,2 mmol/L. Sem sinais de hipoperfusao. '
    'Doppler de membros inferiores sem TVP proximal.';

void main() {
  group('Plantao dependent classification follow-up context V1-B-R0', () {
    test('PT diacritic dependent classification helper is true directly', () {
      expect(
        ClinicalThreadManager.isContextualClinicalFollowUp(
          'E qual é a classificação?',
        ),
        isTrue,
      );
      expect(
        ClinicalThreadManager.isContextualClinicalFollowUp(
          'E qual e a classificacao?',
        ),
        isTrue,
      );
    });

    test('PT exact dependent classification question continues active TEP case', () {
      final manager = ClinicalThreadManager();
      final first = manager.evaluate(
        currentUserText: _b1Case,
        isPlantaoMode: true,
      );
      expect(first.action, ThreadAction.newThread);

      final follow = manager.evaluate(
        currentUserText: 'E qual é a classificação?',
        isPlantaoMode: true,
      );
      expect(follow.action, ThreadAction.continueThread);
      expect(follow.reason, 'contextual_clinical_followup');
    });

    test('ES exact dependent classification question continues active TEP case', () {
      final manager = ClinicalThreadManager();
      manager.evaluate(currentUserText: _b1Case, isPlantaoMode: true);

      final follow = manager.evaluate(
        currentUserText: '¿Y cuál es la clasificación?',
        isPlantaoMode: true,
      );
      expect(follow.action, ThreadAction.continueThread);
      expect(follow.reason, 'contextual_clinical_followup');
    });

    test('punctuation variants remain dependent follow-ups', () {
      for (final query in const <String>[
        'Qual a categoria?',
        'E qual é a categoria?',
        'Qual o risco?',
        '¿Cuál es la categoría?',
        '¿Qué riesgo?',
      ]) {
        final manager = ClinicalThreadManager();
        manager.evaluate(currentUserText: _b1Case, isPlantaoMode: true);
        final follow = manager.evaluate(
          currentUserText: query,
          isPlantaoMode: true,
        );
        expect(
          follow.action,
          ThreadAction.continueThread,
          reason: query,
        );
      }
    });

    test('thread history keeps prior pair for dependent classification follow-up', () {
      final manager = ClinicalThreadManager();
      manager.evaluate(currentUserText: _b1Case, isPlantaoMode: true);
      final follow = manager.evaluate(
        currentUserText: 'E qual é a classificação?',
        isPlantaoMode: true,
      );

      final history = <Map<String, String>>[
        {'role': 'user', 'content': _b1Case},
        {'role': 'assistant', 'content': 'TEP AGUDO CONFIRMADO — B1'},
      ];

      final sent = ClinicalThreadManager.buildThreadHistory(
        fullHistory: history,
        status: follow,
        isPlantaoMode: true,
      );

      expect(sent, isNotEmpty);
      expect(sent.any((m) => m['role'] == 'user' && m['content'] == _b1Case), isTrue);
    });

    test('TEP guard resolves B1 from the preserved USER history', () {
      final manager = ClinicalThreadManager();
      manager.evaluate(currentUserText: _b1Case, isPlantaoMode: true);
      final follow = manager.evaluate(
        currentUserText: 'E qual é a classificação?',
        isPlantaoMode: true,
      );

      final history = <Map<String, String>>[
        {'role': 'user', 'content': _b1Case},
        {'role': 'assistant', 'content': 'respuesta previa'},
      ];
      final sent = ClinicalThreadManager.buildThreadHistory(
        fullHistory: history,
        status: follow,
        isPlantaoMode: true,
      );
      final recentUserTurns = sent
          .where((m) => m['role'] == 'user')
          .map((m) => m['content'] ?? '')
          .where((text) => text.isNotEmpty)
          .toList(growable: false);

      final out = Tep2026PlantaoResponseGuard.materialize(
        userInput: 'E qual é a classificação?',
        assistantOutput: 'Clasificación genérica sin contexto.',
        languageCode: 'es',
        recentUserTurns: recentUserTurns,
      );

      expect(out, contains('TEP AGUDO CONFIRMADO — B1'));
      expect(out, contains('Categoría final: **B1**'));
      expect(out, isNot(contains('Clasificación genérica sin contexto.')));
    });

    test('ClinicalSessionMemory also preserves dependent classification follow-up', () {
      final memory = ClinicalSessionMemory();
      expect(memory.resetIfTopicChanged(_b1Case), isFalse);
      expect(memory.resetIfTopicChanged('E qual é a classificação?'), isFalse);
    });

    test('explicit new case still wins and cannot inherit prior TEP', () {
      final manager = ClinicalThreadManager();
      manager.evaluate(currentUserText: _b1Case, isPlantaoMode: true);

      final next = manager.evaluate(
        currentUserText: 'Novo caso: meningite. Qual a classificação?',
        isPlantaoMode: true,
      );
      expect(next.action, ThreadAction.newThread);
    });

    test('classification of an explicitly named different disease is not auto-carried', () {
      final manager = ClinicalThreadManager();
      manager.evaluate(currentUserText: _b1Case, isPlantaoMode: true);

      final next = manager.evaluate(
        currentUserText: 'Qual a classificação da pneumonia adquirida na comunidade?',
        isPlantaoMode: true,
      );
      expect(next.action, ThreadAction.newThread);
    });

    test('first-message generic classification remains a new thread', () {
      final manager = ClinicalThreadManager();
      final first = manager.evaluate(
        currentUserText: 'E qual é a classificação?',
        isPlantaoMode: true,
      );
      expect(first.action, ThreadAction.newThread);
      expect(first.reason, 'first_message');
    });
  });
}
