import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const chatPath = 'lib/home_v2/components/chat/inline_chat_view.dart';
  const homePath = 'lib/screens/home_screen.dart';
  const bubblePath = 'lib/screens/ai/widgets/ai_bubble.dart';
  const drainPath = 'lib/screens/ai/widgets/streaming_text_drain.dart';

  late String chat;
  late String home;
  late String bubble;

  setUpAll(() {
    chat = File(chatPath).readAsStringSync();
    home = File(homePath).readAsStringSync();
    bubble = File(bubblePath).readAsStringSync();
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

  group('Home V2 — acabamento final da IA', () {
    test('usa header pill e clareia a superfície ativa', () {
      expect(
        chat,
        contains('BorderRadius.circular(999)'),
      );

      expect(
        chat,
        contains('return HomeV2PressSurface('),
      );

      expect(
        chat,
        matches(
          RegExp(
            r'backgroundColor:\s*'
            r'hasConversation\s*'
            r'\?\s*palette\.surfaceActive\s*'
            r':\s*palette\.surface',
          ),
        ),
      );

      final header = classBlock(
        chat,
        'class _InlineChatHeader extends StatelessWidget',
        'class _HeaderAction extends StatelessWidget',
      );

      expect(header, isNot(contains('Divider(')));
    });

    test('mantém o dreno canônico por grafemas', () {
      expect(
        File(drainPath).existsSync(),
        isTrue,
      );

      expect(
        bubble,
        contains("streaming_text_drain.dart"),
      );

      expect(
        bubble,
        contains('StreamingTextDrain'),
      );

      expect(
        home,
        contains(
          'StreamingTextDrain.take(_streamingPending)',
        ),
      );

      expect(
        home,
        contains(
          'const Duration(milliseconds: 24)',
        ),
      );
    });

    test('aguarda onDone e revela apenas a versão final', () {
      expect(
        home,
        contains('onChunk: (_) {'),
      );

      expect(
        home,
        isNot(
          contains('_queueInlineStreamingSnapshot('),
        ),
      );

      expect(
        home,
        contains('_queueInlineStreamingFinal(cleanFin);'),
      );

      expect(
        home,
        contains("String _streamingRaw = '';"),
      );

      expect(
        home,
        contains(
          '_streamingRaw += drained.visible;',
        ),
      );

      expect(
        home,
        contains(
          ': _homeCleanPartialMd(_streamingRaw);',
        ),
      );
    });

    test('não reinicia o texto por divergência de prefixo', () {
      expect(
        home,
        isNot(
          contains(
            'if (snapshot.startsWith(_streaming))',
          ),
        ),
      );

      expect(
        home,
        isNot(
          contains(
            '_streaming = \'\';\n'
            '      _streamingPending = snapshot;',
          ),
        ),
      );
    });

    test('usa um único MarkdownBody sem troca de renderer', () {
      final answer = classBlock(
        chat,
        'class _InlineAnswer extends StatelessWidget',
        'class _InlineAnswerAction extends StatelessWidget',
      );

      expect(
        answer.split('MarkdownBody(').length - 1,
        1,
      );

      expect(
        answer,
        isNot(contains('SelectableText(')),
      );

      expect(
        answer,
        isNot(contains('_streamingProjection')),
      );

      expect(
        answer,
        contains('strong: TextStyle('),
      );

      expect(answer, contains('h1: TextStyle('));
      expect(answer, contains('h2: TextStyle('));
      expect(answer, contains('h3: TextStyle('));
    });

    test('resposta possui respiro lateral adicional de 5 px', () {
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

    test('preserva os marcadores de títulos Markdown', () {
      expect(
        home,
        isNot(
          contains(
            ".replaceAll("
            "RegExp(r'^#{1,3}\\\\s*', multiLine: true), '')",
          ),
        ),
      );
    });
  });
}
