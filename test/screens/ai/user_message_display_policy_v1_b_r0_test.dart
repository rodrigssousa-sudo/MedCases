import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/user_message_display_policy.dart';

void main() {
  group('UserMessageDisplayPolicy V1-B-R0', () {
    test('ES questions action keeps provider prompt hidden visually', () {
      const raw =
          'Enumera solamente las preguntas clínicas clave que debo hacer al '
          'paciente para discriminar los diagnósticos diferenciales de '
          'METRORRAGIA GESTACIONAL. No inventes respuestas del paciente.';

      expect(
        UserMessageDisplayPolicy.visibleText(raw),
        'Preguntas clave',
      );
    });

    test('PT questions action keeps provider prompt hidden visually', () {
      const raw =
          'Liste somente as perguntas clínicas-chave que devo fazer ao paciente '
          'para discriminar os diagnósticos diferenciais de METRORRAGIA '
          'GESTACIONAL. Não invente respostas do paciente.';

      expect(
        UserMessageDisplayPolicy.visibleText(raw),
        'Perguntas-chave',
      );
    });

    test('normal manually typed user message remains byte-identical', () {
      const raw = 'Paciente com dor torácica há 30 minutos.';
      expect(
        UserMessageDisplayPolicy.visibleText(raw),
        raw,
      );
    });

    test('similar phrase without internal sentinel is not compacted', () {
      const raw =
          'Enumera solamente las preguntas clínicas clave que debo hacer.';
      expect(
        UserMessageDisplayPolicy.visibleText(raw),
        raw,
      );
    });

    test('ai screen uses projection only in UserBubble surface', () {
      final source = File('lib/screens/ai_screen.dart').readAsStringSync();

      expect(
        RegExp(
          r'UserMessageDisplayPolicy\.visibleText\(\s*msg\.text,\s*\)',
          multiLine: true,
        ).hasMatch(source),
        isTrue,
      );
      expect(
        RegExp(
          r"_ChatMsg\(\s*role:\s*'user',\s*text:\s*trimmed,",
          multiLine: true,
        ).hasMatch(source),
        isTrue,
      );
      expect(
        source,
        contains(
          'String _bindPlantaoCaseAnchorForButton(String actionText)',
        ),
      );
    });

    test('full questions prompt remains owned by NextActionEngine', () {
      final source =
          File('lib/services/ai_next_action_engine.dart').readAsStringSync();

      expect(
        source,
        contains(
          'Enumera solamente las preguntas clínicas clave que debo hacer al '
          'paciente para discriminar los diagnósticos diferenciales',
        ),
      );
      expect(
        source,
        contains('No inventes respuestas del paciente.'),
      );
      expect(
        source,
        contains(
          'Liste somente as perguntas clínicas-chave que devo fazer ao paciente '
          'para discriminar os diagnósticos diferenciais',
        ),
      );
      expect(
        source,
        contains('Não invente respostas do paciente.'),
      );
    });
  });
}
