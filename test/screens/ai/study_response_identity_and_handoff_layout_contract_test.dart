import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String region(String source, String startMarker, String endMarker) {
  final start = source.indexOf(startMarker);
  final end = source.indexOf(endMarker, start);

  expect(start, greaterThanOrEqualTo(0), reason: startMarker);
  expect(end, greaterThan(start), reason: endMarker);

  return source.substring(start, end);
}

void main() {
  late String aiScreen;
  late String aiBlock;

  setUpAll(() {
    aiScreen = File('lib/screens/ai_screen.dart').readAsStringSync();
    aiBlock = File(
      'lib/screens/ai/widgets/ai_block_bubble.dart',
    ).readAsStringSync();
  });

  group('Study response identity and handoff layout', () {
    test('completion identity has a single owner in AiScreen', () {
      final header = region(
        aiScreen,
        'class _AiResponseIdentityHeader extends StatelessWidget',
        'class _AiHomeGreeting extends StatelessWidget',
      );

      expect(header, contains("'RESPOSTA CONCLUÍDA'"));
      expect(header, contains("'RESPUESTA COMPLETADA'"));

      expect(aiBlock, isNot(contains("'RESPOSTA CONCLUÍDA'")));
      expect(aiBlock, isNot(contains("'RESPUESTA COMPLETADA'")));
    });

    test('Study Markdown starts directly with clinical content', () {
      expect(aiBlock, contains('MarkdownBody('));
      expect(aiBlock, contains('data: mdText'));
      expect(
        aiBlock,
        isNot(
          contains(
            "lang == 'es' ? 'RESPUESTA COMPLETADA' : 'RESPOSTA CONCLUÍDA'",
          ),
        ),
      );
    });

    test('handoff greeting keeps animation without RenderAnimatedSize', () {
      final start = aiScreen.indexOf(
        'class _AiHomeGreeting extends StatelessWidget',
      );

      expect(start, greaterThanOrEqualTo(0));

      final greeting = aiScreen.substring(start);

      expect(greeting, contains('AnimatedAlign('));
      expect(greeting, contains('AnimatedSwitcher('));
      expect(greeting, isNot(contains('AnimatedSize(')));
    });
  });
}
