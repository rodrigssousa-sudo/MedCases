import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/clinical_thread_manager.dart';

void main() {
  group('R20 Study pedagogical topic normalization', () {
    test('Explicarme asma anchors topic as asma', () {
      final manager = ClinicalThreadManager();
      final status = manager.evaluate(
        currentUserText: 'Explicarme asma',
        isPlantaoMode: false,
      );
      expect(status.action, ThreadAction.newThread);
      expect(manager.activeTopic, 'asma');
    });

    test('Me explique asma anchors topic as asma', () {
      final manager = ClinicalThreadManager();
      manager.evaluate(
        currentUserText: 'Me explique asma',
        isPlantaoMode: false,
      );
      expect(manager.activeTopic, 'asma');
    });

    test('Explícame el asma anchors topic as asma', () {
      final manager = ClinicalThreadManager();
      manager.evaluate(
        currentUserText: 'Explícame el asma',
        isPlantaoMode: false,
      );
      expect(manager.activeTopic, 'asma');
    });

    test('bare same pathology stays in same Study thread', () {
      final manager = ClinicalThreadManager();
      manager.evaluate(
        currentUserText: 'Explicarme asma',
        isPlantaoMode: false,
      );
      final second = manager.evaluate(
        currentUserText: 'asma',
        isPlantaoMode: false,
      );
      expect(second.action, ThreadAction.continueThread);
      expect(second.reason, 'study_same_topic_isolated_term');
      expect(manager.activeTopic, 'asma');
    });

    test('primeFromHistory restores canonical pathology', () {
      final manager = ClinicalThreadManager();
      manager.primeFromHistory(const <Map<String, String>>[
        {'role': 'user', 'content': 'Me explique asma'},
        {'role': 'assistant', 'content': 'Resumo sobre asma'},
      ]);
      expect(manager.activeTopic, 'asma');
    });

    test('Plantao isolated pathology switching remains active', () {
      final manager = ClinicalThreadManager();
      manager.evaluate(
        currentUserText: 'sertralina',
        isPlantaoMode: true,
      );
      final switched = manager.evaluate(
        currentUserText: 'asma',
        isPlantaoMode: true,
      );
      expect(switched.action, ThreadAction.newThread);
    });
  });
}
