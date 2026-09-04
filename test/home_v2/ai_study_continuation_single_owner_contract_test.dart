import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String screen;
  late String policy;
  late String actionRow;
  late String resolver;

  setUpAll(() {
    screen = File(
      'lib/screens/ai_screen.dart',
    ).readAsStringSync();

    policy = File(
      'lib/screens/ai/widgets/message_render_policy.dart',
    ).readAsStringSync();

    actionRow = File(
      'lib/screens/ai/widgets/action_buttons_row.dart',
    ).readAsStringSync();

    resolver = File(
      'lib/services/study_continuation_resolver.dart',
    ).readAsStringSync();
  });

  group('R18.6AA-R1F-R3 — proprietário único', () {
    test('AiScreen usa somente o resolver público', () {
      expect(
        screen,
        contains('StudyContinuationResolver.resolve('),
      );

      expect(
        screen,
        isNot(
          contains(
            'MessageRenderPolicy.parseStudyAction(',
          ),
        ),
      );

      expect(
        screen,
        isNot(contains('hasStudyTags')),
      );

      expect(
        screen,
        isNot(contains('nextActionLabel')),
      );
    });

    test('precedência está centralizada', () {
      expect(
        resolver,
        contains('StudyContinuationSource.remoteTag'),
      );

      expect(
        resolver,
        contains('NextActionEngine.build('),
      );

      expect(
        resolver,
        contains('StudyContinuationSource.localEngine'),
      );

      expect(
        resolver,
        contains(
          'StudyContinuationSource.genericFallback',
        ),
      );
    });

    test('botão azul nunca é fallback do Estudo', () {
      expect(
        screen,
        contains('suppressAiAction: _longResponse'),
      );

      expect(
        screen,
        contains("studyNextPrompt: ''"),
      );

      expect(
        screen,
        contains("studyNextLabel: ''"),
      );

      expect(
        actionRow,
        contains('final action = suppressAiAction'),
      );
    });

    test('texto pedagógico antigo é removido', () {
      expect(
        policy,
        contains('_removeLegacyStudyContinuation'),
      );

      expect(
        policy,
        contains('me gustaría'),
      );

      expect(
        policy,
        contains('gostaria de'),
      );
    });

    test('logs usam o resolvedor novo', () {
      expect(
        screen,
        contains(
          r'continuation=${studyContinuation.source.name}',
        ),
      );

      expect(
        screen,
        contains(
          r'source=${studyContinuation.source.name}',
        ),
      );
    });

    test('ferramenta externa permanece independente', () {
      expect(
        actionRow,
        contains('final link = cachedLink;'),
      );

      expect(
        actionRow,
        contains('final calcBtn = link != null'),
      );
    });

    test('streaming e scroll não foram alterados', () {
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
