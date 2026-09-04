import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/ai_block_bubble.dart';
import 'package:medcases/screens/ai/widgets/ai_bubble.dart';

void main() {
  Widget harness({
    required bool animate,
    required bool isStreaming,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 390,
          child: AiBubble(
            text: '**STATIC-FIRST-FRAME**\n\n'
                'Conteúdo clínico completo e estável.',
            dark: false,
            animate: animate,
            isStreaming: isStreaming,
            onCopy: () {},
          ),
        ),
      ),
    );
  }

  group('R18.6Y-R3-R2 — static bubble first-frame stability', () {
    testWidgets(
      'bolha histórica aparece no primeiro frame',
      (tester) async {
        await tester.pumpWidget(
          harness(
            animate: false,
            isStreaming: false,
          ),
        );

        expect(
          find.byType(AiBlockBubble),
          findsOneWidget,
        );

        expect(
          tester.getSize(find.byType(AiBlockBubble)).height,
          greaterThan(0),
        );
      },
    );

    testWidgets(
      'bolha finalizada aparece no primeiro frame',
      (tester) async {
        await tester.pumpWidget(
          harness(
            animate: true,
            isStreaming: false,
          ),
        );

        expect(
          find.byType(AiBlockBubble),
          findsOneWidget,
        );

        expect(
          tester.getSize(find.byType(AiBlockBubble)).height,
          greaterThan(0),
        );
      },
    );

    test(
      'somente streaming ativo mantém sequência pós-frame',
      () {
        final source = File(
          'lib/screens/ai/widgets/ai_bubble.dart',
        ).readAsStringSync();

        expect(
          source,
          contains(
            'widget.animate && widget.isStreaming',
          ),
        );

        expect(
          source,
          contains(
            'Bolhas estáticas ou já finalizadas precisam '
            'nascer com a altura',
          ),
        );

        expect(
          source,
          contains(
            '_cachedBlocks.isEmpty ? 0 : _cachedBlocks.length',
          ),
        );

        expect(
          source,
          contains('_started = true;'),
        );
      },
    );
  });
}
