import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const aiScreenPath = 'lib/screens/ai_screen.dart';

  late String source;

  setUpAll(() {
    source = File(aiScreenPath).readAsStringSync();
  });

  String section(String startToken, String endToken) {
    final start = source.indexOf(startToken);

    expect(
      start,
      greaterThanOrEqualTo(0),
      reason: 'Bloco inicial não localizado: $startToken',
    );

    final end = source.indexOf(
      endToken,
      start + startToken.length,
    );

    expect(
      end,
      greaterThan(start),
      reason: 'Bloco final não localizado: $endToken',
    );

    return source.substring(start, end);
  }

  group('R18.6Y-R2-R2 — scroll intent contract', () {
    test('onScroll preserva nearBottom para a barra inferior', () {
      final onScroll = section(
        'void _onScroll()',
        '@override\n  void didChangeDependencies()',
      );

      expect(
        onScroll,
        contains(
          'final nearBottom = '
          'pos.pixels >= pos.maxScrollExtent - 100;',
        ),
      );

      expect(
        onScroll,
        contains('(isScrollingUp || nearBottom)'),
      );
    });

    test('geometria não sobrescreve intenção manual', () {
      final onScroll = section(
        'void _onScroll()',
        '@override\n  void didChangeDependencies()',
      );

      expect(
        onScroll,
        isNot(contains('_userScrolledUp = !nearBottom')),
      );

      expect(
        onScroll,
        isNot(contains('final wasUp = _userScrolledUp')),
      );

      expect(
        onScroll,
        contains(
          'nearBottom permanece exclusivamente '
          'como leitura geométrica',
        ),
      );
    });

    test('somente gesto físico suspende o auto-follow', () {
      final notificationBlock = section(
        'chatList = NotificationListener<ScrollNotification>',
        '// No desktop: envolve o chat',
      );

      expect(
        notificationBlock,
        contains('notification is ScrollStartNotification'),
      );

      expect(
        notificationBlock,
        contains('notification.dragDetails != null'),
      );

      expect(
        notificationBlock,
        contains('_userScrolledUp = true;'),
      );

      expect(
        notificationBlock,
        contains('O gesto físico é o único evento'),
      );

      expect(
        notificationBlock,
        contains('addPostFrameCallback'),
      );
    });

    test('retorno manual ao fundo reativa o auto-follow', () {
      final notificationBlock = section(
        'chatList = NotificationListener<ScrollNotification>',
        '// No desktop: envolve o chat',
      );

      expect(
        notificationBlock,
        contains('notification is ScrollEndNotification'),
      );

      expect(
        notificationBlock,
        contains('if (nearBottom && _userScrolledUp)'),
      );

      expect(
        notificationBlock,
        contains('_userScrolledUp = false;'),
      );
    });

    test('finalização mantém a identidade da bolha ativa', () {
      final onDone = section(
        'onDone: (finalText)',
        'onStructuredDone:',
      );

      expect(
        onDone,
        contains('_ChatMsg.withId('),
      );

      expect(
        onDone,
        contains('id: _messages[streamingMsgIdx].id'),
      );

      expect(
        onDone,
        contains('_lastAiIndex = streamingMsgIdx'),
      );
    });

    test('ListView e AiBubble continuam com chaves estáveis', () {
      expect(
        source,
        contains("key: ValueKey('msg_\${msg.id}')"),
      );

      expect(
        source,
        contains("key: ValueKey('ai_\${msg.id}')"),
      );

      expect(
        source,
        isNot(contains('UniqueKey(')),
      );
    });

    test('continua existindo um único ScrollController principal', () {
      expect(
        RegExp(r'final _scrollCtrl = ScrollController\(\);')
            .allMatches(source)
            .length,
        1,
      );

      expect(
        RegExp(r'void _scrollDown\(').allMatches(source).length,
        1,
      );
    });
  });
}
