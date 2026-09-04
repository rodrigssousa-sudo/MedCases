import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  group('Home V2 — três ajustes V1-R1-R6', () {
    late String sharedPalette;
    late String iconPalette;
    late String chat;
    late String modules;

    setUpAll(() {
      sharedPalette = source('lib/home_v2/theme/home_v2_palette.dart');
      iconPalette = source('lib/home_v2/theme/home_v2_icon_palette.dart');
      chat = source('lib/home_v2/components/chat/inline_chat_view.dart');
      modules = source('lib/home_v2/components/home_v2_modules_view.dart');
    });

    test('cores vivas respeitam a cor semântica já existente', () {
      expect(chat, contains('const Color(0xFF00E59B)'));
      expect(chat, contains('Color _homeAccent(HomeV2Palette palette)'));
      expect(chat, contains('color: _homeAccent(palette)'));

      expect(sharedPalette, contains('accent: Color(0xFF00C781)'));
      expect(sharedPalette, isNot(contains('0xFF00E59B')));

      for (final color in const <String>[
        '0xFF2DD4BF',
        '0xFF60A5FA',
        '0xFFFBBF24',
        '0xFF34D399',
        '0xFFA78BFA',
        '0xFFFB7185',
        '0xFF38BDF8',
        '0xFFFB923C',
      ]) {
        expect(iconPalette, contains(color), reason: color);
      }
    });

    test('elementos neutros e tema light permanecem iguais', () {
      expect(iconPalette, contains('0xFFB2C0D0'));

      for (final color in const <String>[
        '0xFF087F7B',
        '0xFF3478C7',
        '0xFFC58A1A',
        '0xFF465568',
        '0xFF0F766E',
        '0xFF16845B',
        '0xFF7659B8',
        '0xFFC64A4A',
        '0xFF087A55',
        '0xFFC64A52',
        '0xFF267EAE',
        '0xFFC97828',
      ]) {
        expect(iconPalette, contains(color), reason: color);
      }
    });

    test('card da IA fica aproximadamente cinco por cento menor', () {
      for (final token in const <String>[
        'padding: const EdgeInsets.fromLTRB(14, 8, 14, 12)',
        'const SizedBox(height: 16)',
        'minHeight: 142',
        'const SizedBox(height: 12)',
      ]) {
        expect(chat, contains(token), reason: token);
      }

      expect(chat, isNot(contains('minHeight: 150')));
    });

    test('composer fica centralizado e preserva sua máquina funcional', () {
      expect(
        chat,
        contains('crossAxisAlignment: CrossAxisAlignment.center'),
      );
      expect(chat, isNot(contains('CrossAxisAlignment.end')));
      expect(chat, contains('vertical: 9'));

      for (final token in const <String>[
        'controller: controller',
        'focusNode: focusNode',
        'onSend: onSend',
        'onVoice: onVoice',
        'sttListening: sttListening',
        'onTap: thinking ? null : onVoice',
        'onTap: thinking ? null : onSend',
        'Icons.mic_none_rounded',
        'Icons.stop_rounded',
        'Icons.arrow_upward_rounded',
        'minHeight: 50',
        'maxLines: 6',
      ]) {
        expect(chat, contains(token), reason: token);
      }

      final composer = chat.substring(chat.indexOf('class _InlineComposer'));
      final slots = RegExp(
        r'width:\s*32,\s*height:\s*32,[\s\S]*?child:\s*Icon\(',
      ).allMatches(composer);
      expect(slots.length, greaterThanOrEqualTo(2));
    });

    test('remove subtítulo e preserva o módulo produtivo', () {
      expect(modules, contains("'FÁRMACOS & CALCULADORAS'"));
      expect(
        modules,
        isNot(contains("'Acesso rápido e disponível offline'")),
      );
      expect(
        modules,
        isNot(contains("'Acceso rápido y disponible offline'")),
      );

      for (final token in const <String>[
        'HomeV2IconPalette.farmacos(dark)',
        'Icons.chevron_right_rounded',
        'onTap: onTap',
        'SvgPicture.asset(',
      ]) {
        expect(modules, contains(token), reason: token);
      }
    });
  });
}
