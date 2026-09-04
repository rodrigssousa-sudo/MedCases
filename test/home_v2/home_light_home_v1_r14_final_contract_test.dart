import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  group(
    'Home light — Home V1-R14 final',
    () {
      late String surface;
      late String chat;
      late String palette;
      late String brand;

      setUpAll(() {
        surface = source(
          'lib/home_v2/components/common/'
          'home_v2_press_surface.dart',
        );
        chat = source(
          'lib/home_v2/components/chat/'
          'inline_chat_view.dart',
        );
        palette = source(
          'lib/home_v2/theme/home_v2_palette.dart',
        );
        brand = source('lib/main.dart');
      });

      test(
        'fundo real e divisores ficam mais densos no light',
        () {
          for (final token in const <String>[
            'lightPageBackground = '
                'Color(0xFFE0E6E9)',
            'background: Color(0xFFE0E6E9)',
            'divider: Color(0xFFE1E7ED)',
            'dividerStrong: Color(0xFFD8E0E7)',
          ]) {
            expect(
              '$surface\n$palette',
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'dark contaminado é restaurado',
        () {
          for (final token in const <String>[
            'darkPageBackground = '
                'Color(0xFF1A1D23)',
            'background: Color(0xFF1A1D23)',
            'surface: Color(0xFF252930)',
            'border: Color(0xFF374151)',
            'divider: Color(0xFF2D3340)',
          ]) {
            expect(
              '$surface\n$palette',
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'Histórico não é renderizado e sua lógica permanece',
        () {
          expect(
            chat,
            isNot(contains('onTap: onHistory')),
          );

          for (final token in const <String>[
            'final VoidCallback onHistory;',
            'required this.onHistory',
            'onHistory: onHistory',
            'onTap: onNewChat',
          ]) {
            expect(
              chat,
              contains(token),
              reason: token,
            );
          }
        },
      );

      test(
        'composer usa uma única superfície no light',
        () {
          for (final token in const <String>[
            '? palette.surfaceSoft',
            ': const Color(0xFFF8FAFC)',
            'color: '
                '_homeComposerUnifiedFill(palette)',
            'filled: true',
            'fillColor: Colors.transparent',
          ]) {
            expect(
              chat,
              contains(token),
              reason: token,
            );
          }

          expect(
            chat,
            isNot(
              contains(
                '_homeComposerUnifiedFill'
                '(palette)Soft',
              ),
            ),
          );
        },
      );

      test(
        'PRO verde permanece exclusivo da Home light',
        () {
          for (final token in const <String>[
            "text: currentTab == _kAiTab "
                "? 'IA' : 'PRO'",
            'color: currentTab == _kAiTab || dark',
            '? const Color(0xFFFFD700)',
            ': const Color(0xFF059669)',
          ]) {
            expect(
              brand,
              contains(token),
              reason: token,
            );
          }
        },
      );
    },
  );
}
