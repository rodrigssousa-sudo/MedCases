import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const homePath = 'lib/screens/home_screen.dart';
  const homeV2Path = 'lib/home_v2/home_screen_v2.dart';
  const chatPath = 'lib/home_v2/components/chat/inline_chat_view.dart';

  late String home;
  late String homeV2;
  late String chat;

  setUpAll(() {
    home = File(homePath).readAsStringSync();
    homeV2 = File(homeV2Path).readAsStringSync();
    chat = File(chatPath).readAsStringSync();
  });

  String classBlock(
    String source,
    String startMarker,
    String endMarker,
  ) {
    final start = source.indexOf(startMarker);
    final end = source.indexOf(endMarker, start);

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    return source.substring(start, end);
  }

  group('Home V2 — handoff final estável', () {
    test('pinta o Markdown definitivo antes da consolidação', () {
      expect(
        home,
        contains(
          'final completesDrain = drained.remainder.isEmpty;',
        ),
      );

      expect(
        home,
        contains(
          'completesDrain && _streamingFinalText != null',
        ),
      );

      expect(
        home,
        contains('? _streamingFinalText!'),
      );

      expect(
        home,
        contains(
          'await WidgetsBinding.instance.endOfFrame;',
        ),
      );
    });

    test('não introduz espera artificial para o handoff', () {
      final start = home.indexOf(
        'void _ensureInlineStreamingDrain()',
      );

      final end = home.indexOf(
        'void _scrollToBottom()',
        start,
      );

      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));

      final drain = home.substring(start, end);

      expect(
        drain,
        isNot(contains('Duration(seconds:')),
      );

      expect(
        drain,
        contains(
          'const Duration(milliseconds: 24)',
        ),
      );
    });

    test('streaming e resposta final usam a mesma chave', () {
      expect(
        chat.split('home-inline-active-ai-').length - 1,
        2,
      );

      expect(
        chat,
        contains(
          'final completedAiCount = validMessages.where(',
        ),
      );

      expect(
        chat,
        contains(
          'thinking ? completedAiCount : completedAiCount - 1',
        ),
      );

      final message = classBlock(
        chat,
        'class _InlineMessage extends StatelessWidget',
        'class _InlineQuestion extends StatelessWidget',
      );

      expect(message, contains('super.key'));
    });
  });

  group('Home V2 — proprietário único do gesto vertical', () {
    test('a resposta não cria região selecionável de Markdown', () {
      final answer = classBlock(
        chat,
        'class _InlineAnswer extends StatelessWidget',
        'class _InlineAnswerAction extends StatelessWidget',
      );

      expect(answer, contains('selectable: false'));
      expect(answer, isNot(contains('selectable: true')));
    });

    test('mantém cópia integral pela ação própria', () {
      final answer = classBlock(
        chat,
        'class _InlineAnswer extends StatelessWidget',
        'class _InlineAnswerAction extends StatelessWidget',
      );

      expect(answer, contains("label: 'Copiar'"));

      expect(
        answer,
        contains('onTap: () => onCopyAnswer(text)'),
      );
    });

    test('somente a Home V2 possui o scroll vertical', () {
      expect(
        homeV2.split('SingleChildScrollView(').length - 1,
        1,
      );

      expect(
        chat,
        isNot(contains('SingleChildScrollView(')),
      );

      expect(
        chat,
        isNot(contains('ListView(')),
      );

      expect(
        chat,
        isNot(contains('CustomScrollView(')),
      );
    });

    test('resposta usa padding horizontal de 5 px', () {
      final answer = classBlock(
        chat,
        'class _InlineAnswer extends StatelessWidget',
        'class _InlineAnswerAction extends StatelessWidget',
      );

      expect(
        answer,
        matches(
          RegExp(
            r'EdgeInsets\.fromLTRB\(\s*'
            r'5,\s*'
            r'0,\s*'
            r'5,',
          ),
        ),
      );
    });
  });
}
