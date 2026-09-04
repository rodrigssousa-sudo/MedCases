import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_next_action_engine.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_continuation_type.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_section.dart';
import 'package:medcases/services/plantao_continuation_policy.dart';

const genericEvolutionEs = SmartNextAction(
  label: 'Estudios y evolución',
  promptToSend: 'Completar estudios y evolución del caso.',
  continuationType: PlantaoContinuationType.examsEvolution,
  requestedSections: <PlantaoSection>[
    PlantaoSection.exams,
    PlantaoSection.evolution,
  ],
);

void main() {
  test('complete acute core chooses destination before generic studies', () {
    const physical = '''
Patología/diagnóstico: Anafilaxia.
Conducta inmediata: Administrar adrenalina IM 0,01 mg/kg de solución 1 mg/mL; evaluar vía aérea, ventilación y circulación; administrar oxígeno; obtener acceso IV y cristaloide si hipotensión/shock.
Tratamiento farmacológico: Adrenalina IM como primera línea.
Monitorización y reevaluación: Observar hasta la resolución completa; reevaluar inmediatamente después de cada intervención.
Puntos clave: La adrenalina es el tratamiento de primera línea.
Red flags/escalamiento: Escalar a emergencias/UCI ante shock, obstrucción de vía aérea, hipoxemia o refractariedad.
''';

    final action = PlantaoContinuationPolicy.resolve(
      baseAction: genericEvolutionEs,
      lastUserMessage: 'Anafilaxia con urticaria, disnea e hipotensión.',
      lastAiResponse: physical,
      chatHistory: const <String>[],
      languageCode: 'es',
    );

    expect(action.label, 'Definir destino');
    expect(action.label, isNot('Completar estudios'));
    expect(
      action.continuationType,
      PlantaoContinuationType.prognosisDisposition,
    );
    expect(action.requestedSections, contains(PlantaoSection.disposition));
  });

  test('studies remain available when acute core is incomplete', () {
    const partial = '''
Patología/diagnóstico: Cuadro agudo.
Monitorización: vigilar signos vitales y evolución.
''';

    final action = PlantaoContinuationPolicy.resolve(
      baseAction: genericEvolutionEs,
      lastUserMessage: '¿Cómo seguimos?',
      lastAiResponse: partial,
      chatHistory: const <String>[],
      languageCode: 'es',
    );

    expect(action.label, 'Completar estudios');
  });
}
