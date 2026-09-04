import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/home_v2/theme/home_v2_palette.dart';
import 'package:medcases/screens/ai/widgets/ai_shimmer_dots.dart';

String region(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker, start);
  expect(start, greaterThanOrEqualTo(0), reason: startMarker);
  expect(end, greaterThan(start), reason: endMarker);
  return source.substring(start, end);
}

void main() {
  late String waiting;
  late String home;
  late String ai;
  late String aiThinkingBlock;
  late String homeThinkingBlock;

  setUpAll(() {
    waiting = File(
      'lib/screens/ai/widgets/ai_shimmer_dots.dart',
    ).readAsStringSync();
    home = File(
      'lib/home_v2/components/chat/inline_chat_view.dart',
    ).readAsStringSync();
    ai = File('lib/screens/ai_screen.dart').readAsStringSync();

    aiThinkingBlock = region(
      ai,
      'if (_thinking && i == _messages.length)',
      'final msg = _messages[i];',
    );
    homeThinkingBlock = region(
      home,
      'class _InlineThinking extends StatelessWidget',
      'Color _homeComposerUnifiedFill(',
    );
  });

  group('AI tab waiting dots with Home preserved', () {
    test('IA completa usa três pontos verdes delicados', () {
      expect(
        waiting,
        contains('class AiShimmerDots extends StatefulWidget'),
      );
      expect(waiting, contains('List<Widget>.generate('));
      expect(
        waiting,
        contains(r"ValueKey<String>('ai-loading-dot-$index')"),
      );
      expect(waiting, contains('width: 5'));
      expect(waiting, contains('height: 5'));
      expect(waiting, contains('color: palette.accent'));
      expect(waiting, isNot(contains('LinearProgressIndicator(')));
      expect(
        aiThinkingBlock,
        contains('AiShimmerDots(dark: dark)'),
      );
    });

    test('Home mantém sua estrutura original independente', () {
      for (final token in const [
        "isEs ? 'GENERANDO RESPUESTA' : 'GERANDO RESPOSTA'",
        'LinearProgressIndicator(',
        'width: 52',
        'minHeight: 2',
      ]) {
        expect(
          homeThinkingBlock,
          contains(token),
          reason: token,
        );
      }

      expect(
        home,
        isNot(
          contains(
            "import '../../../screens/ai/widgets/"
            "ai_shimmer_dots.dart';",
          ),
        ),
      );
    });

    testWidgets('dots continuam usando accent oficial', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiShimmerDots(dark: true),
          ),
        ),
      );

      final palette = HomeV2Palette.resolve(true);

      for (var index = 0; index < 3; index++) {
        final finder = find.byKey(
          ValueKey<String>('ai-loading-dot-$index'),
        );

        expect(finder, findsOneWidget);

        final dot = tester.widget<Container>(finder);
        final decoration = dot.decoration! as BoxDecoration;

        expect(tester.getSize(finder), const Size(5, 5));
        expect(decoration.color, palette.accent);
      }

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
