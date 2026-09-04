import 'package:flutter_test/flutter_test.dart';

import '../../lib/screens/ai/widgets/message_render_policy.dart';

void main() {
  group('R18.6AA-R1C-R1 — limpeza da continuação', () {
    test('remove pin órfão antes das tags ocultas', () {
      final result = MessageRenderPolicy.parseStudyAction(
        text: '''
Investigación y diferenciales.

📌
[NEXT_ACTION_LABEL: Manejo inicial]
[NEXT_ACTION_PROMPT: ¿Cómo se realiza el manejo inicial de la LRA?]
''',
        isStudyMode: true,
      );

      expect(
        result.displayText,
        'Investigación y diferenciales.',
      );

      expect(
        result.prompt,
        '¿Cómo se realiza el manejo inicial de la LRA?',
      );

      expect(
        result.label,
        'Manejo inicial',
      );
    });

    test('remove pin órfão mesmo sem tags', () {
      final result = MessageRenderPolicy.parseStudyAction(
        text: 'Clínica e diagnóstico.\n\n📌\n\n',
        isStudyMode: true,
      );

      expect(
        result.displayText,
        'Clínica e diagnóstico.',
      );

      expect(result.hasAction, isFalse);
    });

    test('preserva linha clínica iniciada por pin', () {
      final result = MessageRenderPolicy.parseStudyAction(
        text: '📌 Monitorar: creatinina, diurese e potássio.',
        isStudyMode: true,
      );

      expect(
        result.displayText,
        '📌 Monitorar: creatinina, diurese e potássio.',
      );
    });

    test('modo Plantão continua intacto', () {
      const text = '📌 Monitorar: pressão arterial.';

      final result = MessageRenderPolicy.parseStudyAction(
        text: text,
        isStudyMode: false,
      );

      expect(result.displayText, text);
      expect(result.hasAction, isFalse);
    });
    test('remove frase pedagógica antiga com pin', () {
      final result = MessageRenderPolicy.parseStudyAction(
        text: '''
Clínica, investigação e diferenciais.

📌 Me gustaría saber más sobre las causas del síndrome cerebeloso.
''',
        isStudyMode: true,
      );

      expect(
        result.displayText,
        'Clínica, investigação e diferenciais.',
      );
    });

    test('preserva pin clínico com monitorização', () {
      final result = MessageRenderPolicy.parseStudyAction(
        text: '''
Conduta imediata.

📌 Monitorar: creatinina, potássio e diurese.
''',
        isStudyMode: true,
      );

      expect(
        result.displayText,
        contains('📌 Monitorar:'),
      );
    });
  });
}
