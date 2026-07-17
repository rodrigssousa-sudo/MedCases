import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/action_button_policy.dart';

void main() {
  group('ActionButtonPolicy.resolveStudyAction', () {
    test('preserva ação válida do Modo Estudo', () {
      final result = ActionButtonPolicy.resolveStudyAction(
        isPlantaoMode: false,
        studyNextPrompt: 'Explique a farmacologia avançada.',
        studyNextLabel: 'Aprofundar farmacologia >',
        lastSentStudyPrompt: '',
        languageCode: 'pt',
      );

      expect(result.hasStudyNext, isTrue);
      expect(result.isRepeatedPathophysiology, isFalse);
      expect(result.prompt, 'Explique a farmacologia avançada.');
      expect(result.label, 'Aprofundar farmacologia >');
    });

    test('desabilita ação pedagógica no Modo Plantão', () {
      final result = ActionButtonPolicy.resolveStudyAction(
        isPlantaoMode: true,
        studyNextPrompt: 'Aprofundar fisiopatologia.',
        studyNextLabel: 'Aprofundar fisiopatologia >',
        lastSentStudyPrompt: '',
        languageCode: 'pt',
      );

      expect(result.hasStudyNext, isFalse);
      expect(result.prompt, isEmpty);
      expect(result.label, isEmpty);
    });

    test('exige prompt e label simultaneamente', () {
      final withoutLabel = ActionButtonPolicy.resolveStudyAction(
        isPlantaoMode: false,
        studyNextPrompt: 'Avançar conteúdo.',
        studyNextLabel: '',
        lastSentStudyPrompt: '',
        languageCode: 'pt',
      );

      final withoutPrompt = ActionButtonPolicy.resolveStudyAction(
        isPlantaoMode: false,
        studyNextPrompt: '',
        studyNextLabel: 'Avançar conteúdo >',
        lastSentStudyPrompt: '',
        languageCode: 'pt',
      );

      expect(withoutLabel.hasStudyNext, isFalse);
      expect(withoutPrompt.hasStudyNext, isFalse);
    });

    test('interrompe repetição de fisiopatologia em português', () {
      final result = ActionButtonPolicy.resolveStudyAction(
        isPlantaoMode: false,
        studyNextPrompt: 'Aprofunde a fisiopatologia da doença.',
        studyNextLabel: 'Aprofundar Fisiopatologia >',
        lastSentStudyPrompt: 'Explique a fisiopatologia celular.',
        languageCode: 'pt',
      );

      expect(result.hasStudyNext, isTrue);
      expect(result.isRepeatedPathophysiology, isTrue);
      expect(result.prompt, contains('mecanismos celulares'));
      expect(result.prompt, contains('Proibido repetir'));
      expect(result.label, 'Mecanismos Moleculares Avançados >');
    });

    test('interrompe repetição de fisiopatologia em espanhol', () {
      final result = ActionButtonPolicy.resolveStudyAction(
        isPlantaoMode: false,
        studyNextPrompt: 'Profundiza la fisiopatología.',
        studyNextLabel: 'Profundizar fisiopatología >',
        lastSentStudyPrompt: 'Explica la fisiopatología avanzada.',
        languageCode: 'es',
      );

      expect(result.isRepeatedPathophysiology, isTrue);
      expect(result.label, 'Mecanismos Moleculares Avanzados >');
    });
  });

  group('ActionButtonPolicy.sanitizeToolLabel', () {
    test('remove emoji e símbolos do início', () {
      expect(
        ActionButtonPolicy.sanitizeToolLabel('💊 Abrir Amiodarona'),
        'Abrir Amiodarona',
      );
      expect(
        ActionButtonPolicy.sanitizeToolLabel('⚗️ Potássio (eletrólitos)'),
        'Potássio (eletrólitos)',
      );
    });

    test('preserva label que já começa com texto', () {
      expect(
        ActionButtonPolicy.sanitizeToolLabel('Calcular dose'),
        'Calcular dose',
      );
    });
  });
}
