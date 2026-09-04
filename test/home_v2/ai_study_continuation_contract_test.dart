import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String router;
  late String policy;
  late String screen;
  late String actionRow;
  late String widget;

  setUpAll(() {
    router = File(
      'lib/services/ai_smart_router.dart',
    ).readAsStringSync();

    policy = File(
      'lib/screens/ai/widgets/message_render_policy.dart',
    ).readAsStringSync();

    screen = File(
      'lib/screens/ai_screen.dart',
    ).readAsStringSync();

    actionRow = File(
      'lib/screens/ai/widgets/action_buttons_row.dart',
    ).readAsStringSync();

    widget = File(
      'lib/screens/ai/widgets/study_continuation_button.dart',
    ).readAsStringSync();
  });

  group('R18.6AA-R1C-R1 — Study Continuation Button', () {
    test('prompt não exige pin visível', () {
      expect(
        router,
        isNot(contains('📌 único emoji')),
      );

      expect(
        router,
        contains(
          'Sem emoji 📌 de fechamento no texto visível.',
        ),
      );

      expect(
        router,
        contains(
          'pergunta direta de continuação',
        ),
      );

      expect(
        router,
        contains('terminada em ?'),
      );
    });

    test('metadados continuam ocultos', () {
      expect(
        policy,
        contains('_nextActionLabelPattern'),
      );

      expect(
        policy,
        contains('_nextActionPromptPattern'),
      );

      expect(
        policy,
        contains('_removeOrphanStudyPin'),
      );

      expect(
        policy,
        contains('final normalized = text.trimRight();'),
      );
    });

    test('AiScreen separa label visual do prompt produtivo', () {
      expect(
        screen,
        contains(
          "import 'ai/widgets/"
          "study_continuation_button.dart';",
        ),
      );

      expect(
        screen,
        contains('StudyContinuationButton('),
      );

      expect(
        screen,
        contains(
          'label: studyButtonLabel.trim()',
        ),
      );

      expect(
        screen,
        contains('fromButton: true'),
      );
    });

    test('prompt produtivo fica oculto e label mantém proveniência', () {
      expect(screen,
          contains('final String studyButtonLabel = studyContinuation.label;'));
      expect(screen, contains('final prompt = nextActionPrompt.trim();'));
      expect(screen, contains('userDisplayText: studyButtonLabel.trim()'));
      expect(screen, isNot(contains('question: nextActionPrompt.trim()')));
    });

    test('botão é bloqueado em streaming e safe-card', () {
      expect(
        screen,
        contains('!isSafeCard'),
      );

      expect(
        screen,
        contains('!isActiveStreamingBubble'),
      );

      expect(
        screen,
        contains('_longResponse'),
      );
    });

    test('continuação não é duplicada no botão azul', () {
      expect(
        screen,
        contains(
          'suppressAiAction: _longResponse',
        ),
      );

      expect(
        actionRow,
        contains('final bool suppressAiAction;'),
      );

      expect(
        actionRow,
        contains('!suppressAiAction'),
      );
    });

    test('ferramenta externa e azul permanecem', () {
      expect(
        actionRow,
        contains('final link = cachedLink;'),
      );

      expect(
        actionRow,
        contains('final calcBtn = link != null'),
      );

      expect(
        actionRow,
        contains('Color(0xFF0E8000)'),
      );
    });

    test('novo botão não usa azul institucional', () {
      expect(
        widget,
        isNot(contains('0xFF10B981')),
      );

      expect(
        widget,
        contains('Icons.arrow_forward_rounded'),
      );

      expect(
        widget,
        contains('Timer? _unlockTimer;'),
      );

      expect(
        widget,
        contains('_unlockTimer?.cancel();'),
      );
    });

    test('streaming e scroll permanecem', () {
      final bubble = File(
        'lib/screens/ai/widgets/ai_bubble.dart',
      ).readAsStringSync();

      expect(
        bubble,
        contains(
          'AI-RECONSTRUCTION-R18.6Z-R2-R2-R1',
        ),
      );

      expect(
        screen,
        isNot(
          contains('_userScrolledUp = !nearBottom'),
        ),
      );
    });
  });
}
