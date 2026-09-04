import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_next_action_engine.dart';

void main() {
  group('Plantão no filler questions final logic V1-B-R0', () {
    test('generic Preguntas importantes owner is removed', () {
      final source = File(
        'lib/services/ai_next_action_engine.dart',
      ).readAsStringSync();

      expect(
        source,
        isNot(
          contains(
            "label: es ? 'Preguntas importantes' : 'Perguntas importantes'",
          ),
        ),
      );
      expect(
        source,
        contains("label: es ? 'Preguntas clave' : 'Perguntas-chave'"),
      );
      expect(source, contains('_emptyGuardiaAction'));
    });

    test('exhausted generic Guardia progression returns empty action', () {
      const studiesQuestion =
          '¿Qué exámenes complementarios solicitar y cómo monitorear '
          'la evolución en HIPERGLUCEMIA AGUDA?';

      const studiesResponse = """
🟥 HIPERGLUCEMIA AGUDA
Estudios complementarios:
• Cetonemia
• Ionograma
Monitoreo:
• Glucemia capilar
• Potasio sérico
""";

      final action = NextActionEngine.build(
        lastUserMessage: studiesQuestion,
        lastAiResponse: studiesResponse,
        isPlantaoMode: true,
        currentLanguage: 'es',
        chatHistory: const <String>[
          'Tratamiento hiperglucemia 340',
          """
🟥 HIPERGLUCEMIA AGUDA
Conducta inmediata:
• Evaluar cetonuria/cetonemia
Tratamiento farmacológico:
• Insulina regular 0.1 U/kg SC
""",
          studiesQuestion,
          studiesResponse,
        ],
      );

      expect(action.label, isEmpty);
      expect(action.promptToSend, isEmpty);
    });

    test(
      'adaptive differential questions remain available when meaningful',
      () {
        final action = NextActionEngine.build(
          lastUserMessage: 'dolor abdominal agudo sin diagnóstico definido',
          lastAiResponse: """
DIFERENCIALES PRIORITARIOS
• Apendicitis.
• Diverticulitis.
• Litiasis ureteral.
""",
          isPlantaoMode: true,
          currentLanguage: 'es',
          chatHistory: const <String>[],
        );

        expect(action.label, 'Preguntas clave');
        expect(action.promptToSend, isNotEmpty);
      },
    );

    test('Study mode remains outside this Plantão closure', () {
      final action = NextActionEngine.build(
        lastUserMessage: 'Explique sepse.',
        lastAiResponse: 'Sepse e disfunção orgânica.',
        isPlantaoMode: false,
        currentLanguage: 'pt',
        chatHistory: const <String>[],
      );

      expect(action.label, isNotEmpty);
      expect(action.promptToSend, isNotEmpty);
    });
  });
}
