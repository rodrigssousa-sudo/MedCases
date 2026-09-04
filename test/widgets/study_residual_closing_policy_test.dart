import 'package:flutter_test/flutter_test.dart';

import '../../lib/screens/ai/widgets/message_render_policy.dart';

void main() {
  group(
    'R18.6AC-R1B-H3B — encerramento residual',
    () {
      test('remove exatamente o encerramento observado em espanhol', () {
        final result = MessageRenderPolicy.parseStudyAction(
          text: '''
Diferenciales: es fundamental diferenciar el delirio de la demencia y la psicosis.

- **Delirio vs. Demencia:** contenido clínico.
- **Trastorno Delirante vs. Esquizofrenia:** contenido clínico.

📌 Estoy listo para discutir el tratamiento del delirio o del trastorno delirante.
''',
          isStudyMode: true,
        );

        expect(
          result.displayText,
          isNot(
            contains('Estoy listo para discutir'),
          ),
        );

        expect(
          result.displayText,
          contains('Trastorno Delirante vs. Esquizofrenia'),
        );
      });

      test('remove variação portuguesa equivalente', () {
        final result = MessageRenderPolicy.parseStudyAction(
          text: '''
Conteúdo clínico completo.

📌 Estou pronto para discutir o tratamento e os diagnósticos diferenciais.
''',
          isStudyMode: true,
        );

        expect(
          result.displayText,
          'Conteúdo clínico completo.',
        );
      });

      test('remove convite opcional espanhol', () {
        final result = MessageRenderPolicy.parseStudyAction(
          text: '''
Contenido clínico completo.

📌 Si deseas, puedo explicar el manejo farmacológico.
''',
          isStudyMode: true,
        );

        expect(
          result.displayText,
          'Contenido clínico completo.',
        );
      });

      test('remove convite opcional português', () {
        final result = MessageRenderPolicy.parseStudyAction(
          text: '''
Conteúdo clínico completo.

📌 Se quiser, posso detalhar o manejo farmacológico.
''',
          isStudyMode: true,
        );

        expect(
          result.displayText,
          'Conteúdo clínico completo.',
        );
      });

      test('preserva monitorização clínica', () {
        const text = '''
Conduta clínica.

📌 Monitorar: creatinina, potássio, diurese e ECG.
''';

        final result = MessageRenderPolicy.parseStudyAction(
          text: text,
          isStudyMode: true,
        );

        expect(
          result.displayText,
          contains(
            '📌 Monitorar: creatinina, potássio, diurese e ECG.',
          ),
        );
      });

      test('preserva alerta clínico', () {
        const text = '''
Conduta clínica.

📌 Alerta: risco de arritmia ventricular.
''';

        final result = MessageRenderPolicy.parseStudyAction(
          text: text,
          isStudyMode: true,
        );

        expect(
          result.displayText,
          contains(
            '📌 Alerta: risco de arritmia ventricular.',
          ),
        );
      });

      test('preserva contraindicação e dose', () {
        const text = '''
Tratamento.

📌 Contraindicación: sangrado activo. Dosis inicial: 5 mg.
''';

        final result = MessageRenderPolicy.parseStudyAction(
          text: text,
          isStudyMode: true,
        );

        expect(
          result.displayText,
          contains('Contraindicación: sangrado activo'),
        );

        expect(
          result.displayText,
          contains('5 mg'),
        );
      });

      test('remove somente quando convite é o último parágrafo', () {
        const text = '''
📌 Estoy listo para discutir el tratamiento.

Después, se debe monitorizar la evolución clínica.
''';

        final result = MessageRenderPolicy.parseStudyAction(
          text: text,
          isStudyMode: true,
        );

        expect(
          result.displayText,
          contains('Estoy listo para discutir'),
        );

        expect(
          result.displayText,
          contains('monitorizar la evolución clínica'),
        );
      });

      test('Modo Plantão permanece byte a byte intacto', () {
        const text = '''
🟥 CONDUTA IMEDIATA

📌 Estou pronto para discutir o tratamento.
''';

        final result = MessageRenderPolicy.parseStudyAction(
          text: text,
          isStudyMode: false,
        );

        expect(result.displayText, text);
        expect(result.hasAction, isFalse);
      });

      test('tags continuam ocultas e convite residual é removido', () {
        final result = MessageRenderPolicy.parseStudyAction(
          text: '''
Conteúdo clínico completo.

📌 Estoy listo para discutir el tratamiento.

[NEXT_ACTION_LABEL: Manejo]
[NEXT_ACTION_PROMPT: ¿Cuál es el manejo del delirio?]
''',
          isStudyMode: true,
        );

        expect(
          result.displayText,
          'Conteúdo clínico completo.',
        );

        expect(
          result.displayText,
          isNot(contains('NEXT_ACTION_')),
        );

        expect(
          result.prompt,
          '¿Cuál es el manejo del delirio?',
        );
      });
    },
  );
}
