import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plantão questions button resilient specific hidden trigger V1-B-R0', () {
    test('primary questions authority remains target 10 and becomes case-specific', () {
      final source = File('lib/services/ai_service.dart').readAsStringSync();

      expect(source, contains('Responder EXACTAMENTE 10 preguntas clínicas'));
      expect(source, contains('Responder EXATAMENTE 10 perguntas clínicas'));
      expect(
        source,
        contains(
          'Cada pregunta debe ser específica del diagnóstico/cuadro ACTIVO',
        ),
      );
      expect(
        source,
        contains(
          'Cada pergunta deve ser específica do diagnóstico/quadro ATIVO',
        ),
      );
      expect(
        source,
        contains(
          'Evita preguntas genéricas aplicables a cualquier paciente',
        ),
      );
      expect(
        source,
        contains(
          'Evite perguntas genéricas aplicáveis a qualquer paciente',
        ),
      );
    });

    test('final acceptance keeps 6-10 safe questions instead of discarding 6-9', () {
      final source = File('lib/providers/app_provider.dart').readAsStringSync();

      expect(
        source,
        contains('questionCount < 6 || questionCount > 10'),
      );
      expect(source, isNot(contains('_plantaoQuestionsExactTenCount(output) != 10')));
      expect(source, contains("requestId: '\${requestId}_q10r1'"));
      expect(source, contains('stage=repair_accept'));
    });

    test('provider failure becomes six useful questions, never old failure sentence', () {
      final source = File('lib/providers/app_provider.dart').readAsStringSync();

      expect(source, contains('stage=fallback_six'));
      expect(source, contains('fallbackQuestions=6'));
      expect(
        source,
        isNot(
          contains(
            'No fue posible validar un conjunto completo de 10 preguntas clínicas',
          ),
        ),
      );
      expect(
        source,
        isNot(
          contains(
            'Não foi possível validar um conjunto completo de 10 perguntas clínicas',
          ),
        ),
      );
      expect(
        source,
        contains(
          '¿Cuándo comenzaron los síntomas y cómo han evolucionado hasta ahora?',
        ),
      );
      expect(
        source,
        contains(
          'Quando os sintomas começaram e como evoluíram até agora?',
        ),
      );
    });

    test('repair explicitly rejects generic questions', () {
      final source = File('lib/providers/app_provider.dart').readAsStringSync();

      expect(
        source,
        contains(
          'Cada pregunta debe estar vinculada al cuadro de la SOLICITUD ORIGINAL',
        ),
      );
      expect(
        source,
        contains(
          'Cada pergunta deve estar vinculada ao quadro da SOLICITAÇÃO ORIGINAL',
        ),
      );
    });

    test('questions action remains canonical but its user bubble is hidden', () {
      final source = File('lib/screens/ai_screen.dart').readAsStringSync();

      expect(source, contains('final isQuestionsButtonProjection ='));
      expect(source, contains("normalizedDisplayCandidate == 'preguntas clave'"));
      expect(source, contains("normalizedDisplayCandidate == 'perguntas chave'"));
      expect(
        source,
        contains("'msg_\${msg.id}_plantao_questions_button_hidden'"),
      );

      expect(source, contains('editText: msg.text'));
      expect(
        RegExp(
          r'UserMessageDisplayPolicy\.visibleText\(\s*msg\.text,\s*\)',
          multiLine: true,
        ).hasMatch(source),
        isTrue,
      );
      expect(source, contains('msg.userDisplayText?.trim()'));
    });

    test('button owner, next action and renderer remain outside productive patch', () {
      final next =
          File('lib/services/ai_next_action_engine.dart').readAsStringSync();
      final row =
          File('lib/screens/ai/widgets/action_buttons_row.dart').readAsStringSync();
      final renderer = File(
        'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
      ).readAsStringSync();

      expect(next, contains('class NextActionEngine'));
      expect(row, contains('class ActionButtonsRow'));
      expect(renderer, contains('class GuardiaClinicalResponseView'));
    });
  });
}
