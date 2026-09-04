import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _between(
  String source,
  String start,
  String end,
) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(
    end,
    startIndex + start.length,
  );

  expect(
    startIndex,
    greaterThanOrEqualTo(0),
    reason: 'start marker ausente: $start',
  );

  expect(
    endIndex,
    greaterThan(startIndex),
    reason: 'end marker ausente: $end',
  );

  return source.substring(
    startIndex,
    endIndex,
  );
}

void main() {
  late String bubbleSource;
  late String screenSource;

  setUpAll(() {
    bubbleSource = File(
      'lib/screens/ai/widgets/ai_bubble.dart',
    ).readAsStringSync();

    screenSource = File(
      'lib/screens/ai_screen.dart',
    ).readAsStringSync();
  });

  group('AI-STREAM-VISUAL-I.1-R4', () {
    test(
      'usa somente o snapshot acumulado mais recente',
      () {
        expect(
          bubbleSource,
          contains(
            'AI-STREAM-VISUAL-I.1-R4: '
            'latest snapshot coalescer',
          ),
        );

        expect(
          bubbleSource,
          contains(
            "String _pendingSnapshot = '';",
          ),
        );

        expect(
          bubbleSource,
          contains(
            'Duration(milliseconds: 32)',
          ),
        );

        expect(
          bubbleSource,
          isNot(
            contains(
              'Duration(milliseconds: 64)',
            ),
          ),
        );

        expect(
          bubbleSource,
          isNot(
            contains('_networkBuffer'),
          ),
        );

        expect(
          bubbleSource,
          contains(
            'StreamingTextDrain.revealTowards(',
          ),
        );
      },
    );

    test(
      'streaming e final usam a mesma árvore Markdown',
      () {
        expect(
          bubbleSource,
          contains(
            'AI-STREAM-VISUAL-I.1-R4 — renderer único',
          ),
        );

        expect(
          bubbleSource,
          isNot(
            contains(
              'if (widget.isStreaming && '
              '!_streamingComplete)',
            ),
          ),
        );

        expect(
          bubbleSource,
          isNot(
            contains('_streamingComplete'),
          ),
        );
      },
    );

    test(
      'didUpdateWidget fecha sem setState redundante',
      () {
        final method = _between(
          bubbleSource,
          '  void didUpdateWidget(AiBubble old) {',
          '  /// Build 188: renomeado de _computeBlocks',
        );

        expect(
          method,
          contains(
            'if (streamingJustEnded)',
          ),
        );

        expect(
          method,
          contains(
            '_pendingSnapshot = finalText;',
          ),
        );

        expect(
          method,
          contains(
            '_terminalDrainPending = true;',
          ),
        );

        expect(
          method,
          contains(
            '_startRenderTimer();',
          ),
        );

        expect(
          method,
          isNot(
            contains('setState('),
          ),
        );
      },
    );

    test(
      'bolha transmitida não recebe fade final',
      () {
        expect(
          screenSource,
          contains(
            'streamingMsgIdx >= 0 '
            '? null : newBubbleMsgId',
          ),
        );

        expect(
          screenSource,
          isNot(
            contains(
              '_fadingInMsgId = newBubbleMsgId;',
            ),
          ),
        );
      },
    );

    test(
      'scroll possui janela própria de coalescência',
      () {
        expect(
          bubbleSource,
          contains(
            'nowMs - _lastStreamingScrollMs < 160',
          ),
        );

        expect(
          bubbleSource,
          contains(
            '_streamingScrollScheduled',
          ),
        );
      },
    );
  });
}
