import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_next_action_engine.dart';

void main() {
  const hyperglycemiaQuestion = 'Tratamiento hiperglucemia 340';

  const hyperglycemiaResponse = """
🟥 HIPERGLUCEMIA AGUDA
Conducta inmediata:
• Evaluar cetonuria/cetonemia
• Buscar causas precipitantes
Tratamiento farmacológico:
• Insulina regular 0.1 U/kg SC
• Insulina rápida 0.1 U/kg SC
HARD STOP:
• Hipoglucemia < 70 mg/dL
Próximo paso:
• Monitorear glucemia capilar
""";

  group('H5C1-G1-V12-M9 — progressão Guardia', () {
    test('não repete tratamento já solicitado e avança para estudos', () {
      final action = NextActionEngine.build(
        lastUserMessage: hyperglycemiaQuestion,
        lastAiResponse: hyperglycemiaResponse,
        isPlantaoMode: true,
        currentLanguage: 'es',
      );

      expect(action.label, 'Estudios y evolución');
      expect(action.promptToSend, contains('exámenes complementarios'));
      expect(action.promptToSend, isNot(contains('dosis recomendadas')));
    });

    test('histórico impede retorno para condutas e não fabrica perguntas', () {
      const studiesQuestion =
          '¿Qué exámenes complementarios solicitar y '
          'cómo monitorear la evolución en HIPERGLUCEMIA AGUDA?';

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
          hyperglycemiaQuestion,
          hyperglycemiaResponse,
          studiesQuestion,
          studiesResponse,
        ],
      );

      expect(action.label, isEmpty);
      expect(action.promptToSend, isEmpty);
    });

    test('todos os candidatos usados ocultam o botão do Guardia', () {
      const studiesQuestion =
          '¿Qué exámenes complementarios solicitar y '
          'cómo monitorear la evolución en HIPERGLUCEMIA AGUDA?';

      const studiesResponse = '''
🟥 HIPERGLUCEMIA AGUDA
Estudios complementarios:
• Cetonemia
• Ionograma
Monitoreo:
• Glucemia capilar
• Potasio sérico
''';

      const questionsQuestion =
          '¿Qué preguntas clave debo hacer al paciente para orientar '
          'el manejo de HIPERGLUCEMIA AGUDA?';

      const questionsResponse = '''
🟥 HIPERGLUCEMIA AGUDA
Preguntas importantes:
• Uso previo de insulina
• Síntomas de infección
• Adherencia al tratamiento
''';

      final action = NextActionEngine.build(
        lastUserMessage: questionsQuestion,
        lastAiResponse: questionsResponse,
        isPlantaoMode: true,
        currentLanguage: 'es',
        chatHistory: const <String>[
          hyperglycemiaQuestion,
          hyperglycemiaResponse,
          studiesQuestion,
          studiesResponse,
          questionsQuestion,
          questionsResponse,
        ],
      );

      expect(action.label, isEmpty);
      expect(action.promptToSend, isEmpty);
    });

    test('conteúdo específico já respondido avança na ordem do SCA', () {
      final action = NextActionEngine.build(
        lastUserMessage: 'Manejo inicial del SCA',
        lastAiResponse: """
🟥 SÍNDROME CORONARIO AGUDO
• ECG de 12 derivaciones en menos de 10 minutos
• Troponina ultrasensible seriada
""",
        isPlantaoMode: true,
        currentLanguage: 'es',
      );

      expect(action.label, 'Doble antiagregación: dosis');
      expect(action.promptToSend, contains('Clopidogrel'));
    });

    test('Estudo preserva continuação não vazia e fallback próprio', () {
      final action = NextActionEngine.build(
        lastUserMessage: 'Explique sepse.',
        lastAiResponse: 'Sepse e disfunção orgânica.',
        isPlantaoMode: false,
        currentLanguage: 'pt',
      );

      expect(action.label, isNotEmpty);
      expect(action.promptToSend, isNotEmpty);
    });

    test('ActionButtonsRow já oculta ação vazia sem alterar owner', () {
      final source = File(
        'lib/screens/ai/widgets/action_buttons_row.dart',
      ).readAsStringSync();

      expect(source, contains('hasStudyNext || action.label.isNotEmpty'));
      expect(
        source,
        contains('hasStudyNext ? effectiveStudyPrompt : action.promptToSend'),
      );
      expect(source, contains('return const SizedBox.shrink();'));
    });

    test('comparação ignora continuidade escondida após Próximo paso', () {
      final action = NextActionEngine.build(
        lastUserMessage: hyperglycemiaQuestion,
        lastAiResponse: hyperglycemiaResponse,
        isPlantaoMode: true,
        currentLanguage: 'es',
        chatHistory: const <String>[
          hyperglycemiaQuestion,
          hyperglycemiaResponse,
        ],
      );

      expect(action.label, 'Estudios y evolución');
    });
  });
}
