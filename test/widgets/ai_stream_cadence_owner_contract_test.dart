import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _between(
  String source,
  String start,
  String end,
) {
  final startIndex = source.indexOf(start);
  expect(startIndex, greaterThanOrEqualTo(0));

  final endIndex = source.indexOf(
    end,
    startIndex,
  );
  expect(endIndex, greaterThan(startIndex));

  return source.substring(
    startIndex,
    endIndex,
  );
}

void main() {
  late String bubble;
  late String drain;
  late String provider;
  late String screen;

  setUpAll(() {
    bubble = File(
      'lib/screens/ai/widgets/ai_bubble.dart',
    ).readAsStringSync();

    drain = File(
      'lib/screens/ai/widgets/streaming_text_drain.dart',
    ).readAsStringSync();

    provider = File(
      'lib/providers/app_provider.dart',
    ).readAsStringSync();

    screen = File(
      'lib/screens/ai_screen.dart',
    ).readAsStringSync();
  });

  group('R18.6Z-R2-R2-R1 — proprietário visual único', () {
    test('AiBubble possui a política temporal', () {
      expect(
        bubble,
        contains(
          'AI-RECONSTRUCTION-R18.6Z-R2-R2-R1',
        ),
      );

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
        bubble,
        contains(
          'StreamingTextDrain.revealTowards(',
        ),
      );
    });

    test('Provider não recebe segundo drain visual', () {
      expect(
        provider,
        isNot(
          contains(
            'StreamingTextDrain.revealTowards(',
          ),
        ),
      );

      expect(
        provider,
        isNot(
          contains(
            '_terminalDrainPending',
          ),
        ),
      );
    });

    test('timer não pinta snapshot integral', () {
      final method = _between(
        bubble,
        '  void _startRenderTimer() {',
        '\n  void _stopRenderTimer() {',
      );

      expect(
        method,
        contains(
          'final targetText = _pendingSnapshot;',
        ),
      );

      expect(
        method,
        contains(
          'StreamingTextDrain.revealTowards(',
        ),
      );

      expect(
        method,
        isNot(
          contains(
            'final nextText = _pendingSnapshot;',
          ),
        ),
      );
    });

    test('drain possui limite configurável', () {
      expect(
        drain,
        contains(
          'int maxPerTick = 8',
        ),
      );

      expect(
        drain,
        contains(
          'adaptive > safeLimit ? safeLimit : adaptive',
        ),
      );
    });

    test('finalização continua pelo mesmo drain', () {
      final method = _between(
        bubble,
        '  void didUpdateWidget(AiBubble old) {',
        '  /// Build 188: renomeado de _computeBlocks',
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
        isNot(contains('setState(')),
      );
    });

    test('AiScreen continua proprietário do scroll', () {
      expect(
        'ScrollController('.allMatches(screen).length,
        1,
      );

      expect(
        bubble,
        isNot(contains('ScrollController(')),
      );

      expect(
        bubble,
        isNot(contains('animateTo(')),
      );

      expect(
        bubble,
        isNot(contains('jumpTo(')),
      );
    });

    test('correções homologadas permanecem', () {
      expect(
        bubble,
        contains(
          'AI-RECONSTRUCTION-R18.6Y-R3-R2',
        ),
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
  });
}
