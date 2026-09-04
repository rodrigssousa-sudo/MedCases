import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String screen;
  late String bubble;
  late String resolver;

  setUpAll(() {
    screen = File(
      'lib/screens/ai_screen.dart',
    ).readAsStringSync();

    bubble = File(
      'lib/screens/ai/widgets/ai_bubble.dart',
    ).readAsStringSync();

    resolver = File(
      'lib/services/study_continuation_resolver.dart',
    ).readAsStringSync();
  });

  group(
    'R18.6AC-R1B-H2B2 — gate visual final',
    () {
      test('AiBubble possui callback visual separado', () {
        expect(
          bubble,
          contains(
            'final void Function(int generation)? '
            'onVisualComplete;',
          ),
        );

        expect(
          bubble,
          contains(
            'void _notifyVisualCompleteOnce()',
          ),
        );

        expect(
          bubble,
          contains(
            '_visualCompleteGeneration',
          ),
        );

        expect(
          bubble,
          contains(
            '_visualCompleteTextHash',
          ),
        );
      });

      test('callback cobre todos os fechamentos', () {
        expect(
          bubble,
          contains(
            'if (completedTerminalDrain)',
          ),
        );

        expect(
          RegExp(
            r'_notifyVisualCompleteOnce\(\);',
          ).allMatches(bubble).length,
          greaterThanOrEqualTo(3),
        );

        expect(
          bubble,
          contains(
            '_visualCompleteGeneration = null;',
          ),
        );

        expect(
          bubble,
          contains(
            '_visualCompleteTextHash = null;',
          ),
        );
      });

      test('callback visual não substitui scroll', () {
        expect(
          bubble,
          contains(
            'widget.onBlockRevealed?.call(',
          ),
        );

        expect(
          screen,
          contains(
            'onBlockRevealed: _onBlockRevealed,',
          ),
        );

        expect(
          screen,
          contains(
            'onVisualComplete: i == _lastAiIndex',
          ),
        );
      });

      test('AiScreen autoriza por geração e messageId', () {
        expect(
          screen,
          contains(
            'String? '
            '_studyContinuationVisualReadyIdentity;',
          ),
        );

        expect(
          screen,
          contains(
            "final identity = "
            "'\$generation:\$messageId';",
          ),
        );

        expect(
          screen,
          contains(
            'final studyContinuationVisualIdentity =',
          ),
        );

        expect(
          screen,
          contains(
            'if (showStudyContinuation)',
          ),
        );
      });

      test('streaming não pode liberar o botão', () {
        expect(
          screen,
          contains(
            'hasStudyContinuation &&',
          ),
        );

        expect(
          screen,
          contains(
            '!isActiveStreamingBubble &&',
          ),
        );

        expect(
          screen,
          contains(
            'generation != _scrollGeneration',
          ),
        );

        expect(
          screen,
          contains(
            'lastAiMessage.id != messageId',
          ),
        );
      });

      test('H2B1 permanece retida', () {
        expect(
          resolver,
          contains(
            '_isDuplicateOfUserQuestion(',
          ),
        );

        expect(
          resolver,
          contains(
            'candidateKey.contains(originalKey)',
          ),
        );

        expect(
          resolver,
          contains(
            "r'^[^a-z0-9à-ÿ]+'",
          ),
        );

        expect(
          resolver,
          contains(
            'chatHistory.any(',
          ),
        );
      });

      test('H1 permanece retida', () {
        expect(
          screen,
          contains(
            'preserveConfirmedMode = false',
          ),
        );

        expect(
          screen,
          contains(
            '_selectedHistorySessionId',
          ),
        );

        expect(
          RegExp(
            r'_selectedHistorySessionId\s*!=\s*'
            r'summary\.sessionId',
          ).allMatches(screen).length,
          2,
        );
      });

      test('streaming drain e scroll permanecem', () {
        final drain = File(
          'lib/screens/ai/widgets/'
          'streaming_text_drain.dart',
        ).readAsStringSync();

        expect(
          bubble,
          contains(
            'Duration(milliseconds: 32)',
          ),
        );

        expect(
          bubble,
          contains(
            '_maxVisualGraphemesPerTick = 8',
          ),
        );

        expect(
          drain,
          contains('revealTowards'),
        );

        expect(
          screen,
          isNot(
            contains(
              '_userScrolledUp = !nearBottom',
            ),
          ),
        );
      });
    },
  );
}
