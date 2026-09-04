import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/clinical_thread_manager.dart';

void main() {
  group('Plantão stage continuity', () {
    test('history details stay in active abdominal case', () {
      final manager = ClinicalThreadManager();
      final first = manager.evaluate(
        currentUserText: 'Dor na fossa ilíaca',
        isPlantaoMode: true,
      );
      expect(first.action, ThreadAction.newThread);

      final history = manager.evaluate(
        currentUserText:
            'Dor começou há 12 horas na região periumbilical e migrou para FID. '
            'Febre 38,1 C, náuseas, sem sintomas urinários.',
        isPlantaoMode: true,
      );
      expect(history.action, ThreadAction.continueThread);
      expect(history.reason, 'contextual_clinical_followup');
      expect(history.topic, first.topic);
    });

    test('laboratory and imaging results stay in active case', () {
      final manager = ClinicalThreadManager();
      final first = manager.evaluate(
        currentUserText: 'Dor na fossa ilíaca',
        isPlantaoMode: true,
      );
      manager.evaluate(
        currentUserText:
            'Dor começou há 12 horas e migrou para FID. Febre 38,1 C e náuseas.',
        isPlantaoMode: true,
      );

      final labs = manager.evaluate(
        currentUserText:
            'Leucócitos 15.800, neutrofilia, PCR elevada. USG inconclusiva.',
        isPlantaoMode: true,
      );
      expect(labs.action, ThreadAction.continueThread);
      expect(labs.reason, 'contextual_clinical_followup');
      expect(labs.topic, first.topic);
    });

    test('single different complaint with only one evolution marker remains a new thread', () {
      final manager = ClinicalThreadManager();
      manager.evaluate(
        currentUserText: 'Dor na fossa ilíaca',
        isPlantaoMode: true,
      );

      final next = manager.evaluate(
        currentUserText: 'Cefaleia começou hoje',
        isPlantaoMode: true,
      );
      expect(next.action, ThreadAction.newThread);
    });

    test('strong IAMCSST switch leaves unrelated abdominal thread', () {
      final manager = ClinicalThreadManager();
      manager.evaluate(
        currentUserText: 'Dor na fossa ilíaca',
        isPlantaoMode: true,
      );
      manager.evaluate(
        currentUserText:
            'Leucócitos 15.800, neutrofilia, PCR elevada. USG inconclusiva.',
        isPlantaoMode: true,
      );

      final next = manager.evaluate(
        currentUserText: 'IAMCSST confirmado no ECG',
        isPlantaoMode: true,
      );

      expect(next.action, ThreadAction.newThread);
      expect(next.reason, isNot('contextual_clinical_followup'));
      expect(next.topic, isNot(contains('fossa')));
    });

    test('short STEMI alias also leaves unrelated abdominal thread', () {
      final manager = ClinicalThreadManager();
      manager.evaluate(
        currentUserText: 'Dor na fossa ilíaca',
        isPlantaoMode: true,
      );

      final next = manager.evaluate(
        currentUserText: 'STEMI confirmado',
        isPlantaoMode: true,
      );

      expect(next.action, ThreadAction.newThread);
      expect(next.topic, isNot(contains('fossa')));
    });

    test('confirmed IAM remains same thread when progressing from chest pain', () {
      final manager = ClinicalThreadManager();
      final first = manager.evaluate(
        currentUserText: 'Dor torácica opressiva',
        isPlantaoMode: true,
      );
      expect(first.action, ThreadAction.newThread);

      final next = manager.evaluate(
        currentUserText: 'IAMCSST confirmado no ECG',
        isPlantaoMode: true,
      );

      expect(next.action, ThreadAction.continueThread);
      expect(next.reason, 'compatible_diagnostic_progression');
      expect(next.topic, first.topic);
    });

    test('explicit new case still starts another thread', () {
      final manager = ClinicalThreadManager();
      manager.evaluate(
        currentUserText: 'Dor na fossa ilíaca',
        isPlantaoMode: true,
      );

      final next = manager.evaluate(
        currentUserText: 'Novo caso: outro paciente com cefaleia súbita intensa.',
        isPlantaoMode: true,
      );
      expect(next.action, ThreadAction.newThread);
    });
  });
}
