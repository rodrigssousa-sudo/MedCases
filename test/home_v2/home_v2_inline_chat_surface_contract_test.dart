import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const chatPath = 'lib/home_v2/components/chat/inline_chat_view.dart';
  const commonPath = 'lib/home_v2/components/common/home_v2_press_surface.dart';

  late String chat;
  late String common;

  setUpAll(() {
    chat = File(chatPath).readAsStringSync();
    common = File(commonPath).readAsStringSync();
  });

  group('Home V2 — superfície compartilhada da IA', () {
    test('IA usa o componente visual comum', () {
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
    });

    test('usa raio 6 e borda 0.6', () {
      expect(
        common,
        contains('static const double radius = 6'),
      );

      expect(
        common,
        contains(
          'static const double borderWidth = 0.6',
        ),
      );
    });

    test('borda é discreta e reage ao toque', () {
      expect(
        common,
        contains(
          'static const int idleBorderAlpha = 20',
        ),
      );

      expect(common, contains('onPointerDown:'));
      expect(common, contains('onPointerUp:'));
    });

    test('não adiciona sombra externa', () {
      expect(common, isNot(contains('boxShadow:')));
      expect(chat, isNot(contains('boxShadow:')));
    });

    test('composer preserva superfície e controles', () {
      expect(chat, contains('class _InlineComposer'));
      expect(chat, contains('minHeight: 50'));
      expect(
        chat,
        contains('BorderRadius.circular(24)'),
      );
      expect(chat, contains('width: 32'));
      expect(chat, contains('height: 32'));
    });
  });
}
