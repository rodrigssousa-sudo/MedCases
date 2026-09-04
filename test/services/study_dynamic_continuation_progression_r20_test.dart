import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_next_action_engine.dart';

void main() {
  group('R20 Study dynamic continuation progression', () {
    test('covered physiology does not generate physiology again', () {
      final action = NextActionEngine.build(
        lastUserMessage: 'Explícame el asma',
        lastAiResponse: '''
ASMA
Fisiopatología:
La inflamación crónica, la hiperreactividad bronquial y la obstrucción
variable explican los síntomas.
''',
        isPlantaoMode: false,
        currentLanguage: 'es',
        chatHistory: const <String>[],
      );

      expect(action.label.toLowerCase(), isNot(contains('fisiopat')));
    });

    test('topic extraction does not keep pedagogical command', () {
      final action = NextActionEngine.build(
        lastUserMessage: 'Explícame el asma',
        lastAiResponse: 'Resumen académico inicial.',
        isPlantaoMode: false,
        currentLanguage: 'es',
        chatHistory: const <String>[],
      );

      expect(
        action.promptToSend.toLowerCase(),
        isNot(contains('explicame el asma')),
      );
      expect(action.promptToSend.toLowerCase(), contains('asma'));
    });

    test('history after physiology selection advances focus', () {
      final action = NextActionEngine.build(
        lastUserMessage:
            'Explica la fisiopatología de asma de forma progresiva.',
        lastAiResponse: 'Mecanismos fisiopatológicos ya desarrollados.',
        isPlantaoMode: false,
        currentLanguage: 'es',
        chatHistory: const <String>[
          'asma',
          'Explica la fisiopatología de asma de forma progresiva.',
        ],
      );

      expect(action.label.toLowerCase(), isNot(contains('fisiopat')));
    });

    test('productive Study picker fails closed instead of forcing last', () {
      final source =
          File('lib/services/ai_next_action_engine.dart').readAsStringSync();

      expect(source, contains('static SmartNextAction _pickStudyAction({'));
      expect(source, contains('return _emptyStudyAction;'));
      expect(
        source,
        isNot(contains('return _pickAction(targetList, chatHistory);')),
      );
      expect(source, contains("label: es ? 'Aplicación clínica'"));
    });
  });
}
