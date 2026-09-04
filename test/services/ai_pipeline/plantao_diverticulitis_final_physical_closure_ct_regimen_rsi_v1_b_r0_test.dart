import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_next_action_engine.dart';
import 'package:medcases/services/ai_pipeline/plantao_clinical_response_consistency_guard.dart';

void main() {
  group('Diverticulitis final physical closure CT/regimen/RSI V1-B-R0', () {
    test('recurrent uncomplicated confirm/localize CT is not automatic', () {
      const raw = '''
DIVERTICULITIS AGUDA NO COMPLICADA
Conducta inmediata:
• TC abdomen/pelvis para confirmar/localizar diverticulitis
• Considerar manejo ambulatorio si no hay complicaciones
''';

      final out = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: 'diverticulite aguda recorrente não complicada',
        assistantOutput: raw,
        languageCode: 'es',
      );

      expect(
        out,
        contains(
          'En recurrencia típica ya documentada, no es automática '
          'si no hay duda ni signos de complicación.',
        ),
      );
      expect(
        out,
        isNot(contains('TC abdomen/pelvis para confirmar/localizar')),
      );
    });

    test('fixed metronidazole dose becomes selective-antibiotic policy', () {
      const raw = '''
DIVERTICULITIS AGUDA NO COMPLICADA
Tratamiento farmacológico:
• Metronidazol 500 mg VO cada 8 horas — cobertura anaerobia
''';

      final out = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: 'diverticulite aguda recorrente não complicada',
        assistantOutput: raw,
        languageCode: 'es',
      );

      expect(out, isNot(contains('Metronidazol 500 mg')));
      expect(out, contains('Antibióticos selectivos, no automáticos'));
      expect(out, contains('inmunocompromiso'));
      expect(out, contains('seguimiento/apoyo no fiable'));
    });

    test('existing adequate selective line prevents duplicate replacement', () {
      const raw = '''
DIVERTICULITIS AGUDA NO COMPLICADA
Tratamiento farmacológico:
• Metronidazol 500 mg VO cada 8 horas — cobertura anaerobia
• Antibióticos selectivos, no automáticos en toda diverticulitis no complicada: indicarlos si hay inmunocompromiso, fragilidad/complejidad médica, intolerancia oral, empeoramiento clínico, marcadores inflamatorios muy elevados, imagen de mayor riesgo o seguimiento/apoyo no fiable.
''';

      final out = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: 'diverticulitis aguda recurrente no complicada',
        assistantOutput: raw,
        languageCode: 'es',
      );

      expect(out, isNot(contains('Metronidazol 500 mg')));
      expect(
        RegExp(
          'Antibióticos selectivos, no automáticos',
        ).allMatches(out).length,
        1,
      );
    });

    test('fixed dose remains untouched outside uncomplicated route', () {
      const raw = '''
DIVERTICULITIS COMPLICADA CON ABSCESO
Tratamiento farmacológico:
• Metronidazol 500 mg VO cada 8 horas
''';

      final out = PlantaoClinicalResponseConsistencyGuard.enforce(
        userInput: 'diverticulitis complicada con absceso',
        assistantOutput: raw,
        languageCode: 'es',
      );

      expect(out, raw);
    });

    test('persistentes no longer false-matches RSI/intubation', () {
      final action = NextActionEngine.build(
        lastUserMessage: 'diverticulitis aguda no complicada recurrente',
        lastAiResponse: '''
DIVERTICULITIS AGUDA NO COMPLICADA
Red flags:
• No tolerar la dieta por náuseas o vómitos persistentes
• Fiebre alta o signos de peritonitis
''',
        isPlantaoMode: true,
        currentLanguage: 'es',
        chatHistory: const <String>[],
      );

      expect(action.label, isNot('Dosis de secuencia rápida'));
      expect(action.promptToSend.toLowerCase(), isNot(contains('sri:')));
      expect(action.promptToSend.toLowerCase(), isNot(contains('rocuronio')));
      expect(
        action.promptToSend.toLowerCase(),
        isNot(contains('succinilcolina')),
      );
    });

    test('genuine standalone RSI gets airway priority', () {
      final action = NextActionEngine.build(
        lastUserMessage: 'Paciente requiere intubación con RSI',
        lastAiResponse: '''
VÍA AÉREA AVANZADA
• Preoxigenar y monitorizar antes del procedimiento
''',
        isPlantaoMode: true,
        currentLanguage: 'es',
        chatHistory: const <String>[],
      );

      expect(action.label, 'Dosis de secuencia rápida');
      expect(action.promptToSend.toLowerCase(), contains('sri:'));
    });

    test('Spanish intubation wording remains airway context without RSI', () {
      final action = NextActionEngine.build(
        lastUserMessage: 'Paciente requiere intubación orotraqueal',
        lastAiResponse: '''
VÍA AÉREA AVANZADA
• Preoxigenar y monitorizar antes del procedimiento
''',
        isPlantaoMode: true,
        currentLanguage: 'es',
        chatHistory: const <String>[],
      );

      expect(action.label, 'Dosis de secuencia rápida');
    });

    test(
      'IOT-like substring inside antibiotic wording does not become airway',
      () {
        final action = NextActionEngine.build(
          lastUserMessage:
              'diverticulitis no complicada con antibióticos selectivos',
          lastAiResponse: '''
DIVERTICULITIS AGUDA NO COMPLICADA
• Seguimiento clínico y tolerancia oral
''',
          isPlantaoMode: true,
          currentLanguage: 'es',
          chatHistory: const <String>[],
        );

        expect(action.label, isNot('Dosis de secuencia rápida'));
      },
    );

    test(
      'source gives explicit airway priority with safe token boundaries',
      () {
        final source = File(
          'lib/services/ai_next_action_engine.dart',
        ).readAsStringSync();

        expect(
          source,
          contains('_isExplicitAirwayIntubationRequest(lastUserMessage)'),
        );
        expect(
          source,
          contains(
            'final topic = _isExplicitAirwayIntubationRequest(lastUserMessage)',
          ),
        );
        expect(source, contains(r"r'(^| )rsi( |$)'"));
        expect(source, contains(r"r'(^| )iot( |$)'"));
        expect(source, contains("'intubacion'"));
        expect(source, contains("'secuencia rapida'"));
        expect(
          source,
          isNot(
            contains(
              "['intubação', 'iot ', 'sequência rápida', 'rsi', 'bougie']",
            ),
          ),
        );
      },
    );
  });
}
