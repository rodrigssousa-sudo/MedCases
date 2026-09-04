import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao_clinical_response_consistency_guard.dart';
import 'package:medcases/services/clinical_thread_manager.dart';

void main() {
  group('M77 R7 physical exact prompts final closure', () {
    test('PT short prompts rotate IAMCEST -> hemothorax -> septic shock', () {
      final manager = ClinicalThreadManager();

      final first = manager.evaluate(
        currentUserText: 'IAM com elevação do ST — conduta imediata',
        isPlantaoMode: true,
      );
      expect(first.action, ThreadAction.newThread);
      expect(first.reason, 'first_message');

      final second = manager.evaluate(
        currentUserText: 'Hemotórax maciço — conduta imediata',
        isPlantaoMode: true,
      );
      expect(second.action, ThreadAction.newThread);
      expect(second.reason, isNot('first_message'));

      final third = manager.evaluate(
        currentUserText: 'Choque séptico — conduta imediata',
        isPlantaoMode: true,
      );
      expect(third.action, ThreadAction.newThread);
      expect(third.reason, isNot('first_message'));
    });

    test('ES short prompts rotate IAMCEST -> hemothorax -> septic shock', () {
      final manager = ClinicalThreadManager();

      manager.evaluate(
        currentUserText: 'IAM con elevación del ST — conducta inmediata',
        isPlantaoMode: true,
      );

      final second = manager.evaluate(
        currentUserText: 'Hemotórax masivo — conducta inmediata',
        isPlantaoMode: true,
      );
      expect(second.action, ThreadAction.newThread);
      expect(second.reason, isNot('first_message'));

      final third = manager.evaluate(
        currentUserText: 'Shock séptico — conducta inmediata',
        isPlantaoMode: true,
      );
      expect(third.action, ThreadAction.newThread);
      expect(third.reason, isNot('first_message'));
    });

    test('dependent follow-up still remains inside the active IAM thread', () {
      final manager = ClinicalThreadManager();
      manager.evaluate(
        currentUserText: 'IAM com elevação do ST — conduta imediata',
        isPlantaoMode: true,
      );
      final followUp = manager.evaluate(
        currentUserText: 'E qual a classificação?',
        isPlantaoMode: true,
      );
      expect(followUp.action, ThreadAction.continueThread);
    });

    test('physical PT hemothorax output always materializes operative thresholds', () {
      const raw = '''
HEMOTÓRAX MACIÇO

Conduta imediata
• Realizar toracostomia imediata para drenagem pleural.

Tratamento farmacológico
• Transfusão de hemoderivados — enquanto volume de sangue perdido for significativo (> 1500 ml ou 30%).

Pontos-chave
• Avaliar rapidamente a necessidade de cirurgia torácica.
• Monitorar possíveis sinais de choque hemorrágico.

RED FLAGS
• Instabilidade hemodinâmica persistente após drenagem e reposição.
''';

      final out = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: 'Hemotórax maciço — conduta imediata',
        assistantOutput: raw,
      );

      expect(
        out,
        contains(
          '>1500 mL iniciais ou >200 mL/h por 3 horas consecutivas',
        ),
      );
      expect(out, contains('exploração cirúrgica/toracotomia'));
      expect(out, contains('integrando fisiologia'));

      final transfusionLine = out
          .split('\n')
          .firstWhere((line) => line.toLowerCase().contains('transfund'));
      expect(transfusionLine, isNot(contains('1500')));
      expect(
        transfusionLine,
        contains('não usar um volume isolado como único gatilho transfusional'),
      );
    });

    test('physical hemothorax correction is idempotent', () {
      const raw = '''
HEMOTÓRAX MACIÇO
• Transfusão de hemoderivados — perda significativa (> 1500 ml ou 30%).
• Avaliar rapidamente a necessidade de cirurgia torácica.
''';
      final once = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: 'Hemotórax maciço — conduta imediata',
        assistantOutput: raw,
      );
      final twice = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: 'Hemotórax maciço — conduta imediata',
        assistantOutput: once,
      );
      expect(twice, once);
    });

    test('unrelated pathology stays byte exact', () {
      const raw = 'Transfusão 1500 mL; débito 200 mL/h.';
      final out = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: 'Choque séptico — conduta imediata',
        assistantOutput: raw,
      );
      expect(out, raw);
    });
  });
}
