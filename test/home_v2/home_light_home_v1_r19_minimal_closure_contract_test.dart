import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  group(
    'Home light — fechamento mínimo V1-R19',
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
        'fundo e divisores light permanecem aprovados',
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
        'dark permanece no baseline homologado',
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
        'Histórico não renderiza e Novo Chat permanece',
        () {
          expect(
            chat,
            isNot(contains('onTap: onHistory')),
          );
          expect(
            chat,
            isNot(contains('Icons.history_rounded')),
          );
          expect(
            chat,
            contains('onTap: onNewChat'),
          );
          expect(
            chat,
            contains('Icons.add_rounded'),
          );

          for (final token in const <String>[
            'final VoidCallback onHistory;',
            'required this.onHistory',
            'onHistory: onHistory',
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
        'composer usa exclusivamente a paleta compartilhada',
        () {
          const helper = 'Color _homeComposerUnifiedFill(\n'
              '  HomeV2Palette palette,\n'
              ') {\n'
              '  return identical(palette, HomeV2Palette.dark)\n'
              '      ? palette.surfaceSoft\n'
              '      : palette.surfaceStrong;\n'
              '}';

          expect(
            helper.allMatches(chat).length,
            1,
          );
          expect(
            chat,
            isNot(
              contains(
                ': const Color(0xFFF8FAFC);',
              ),
            ),
          );
          expect(
            chat,
            contains(
              'color: '
              '_homeComposerUnifiedFill(palette),',
            ),
          );
          expect(
            chat,
            contains('fillColor: Colors.transparent'),
          );
        },
      );

      test(
        'IA fica verde e PRO preserva o contrato Home',
        () {
          for (final token in const <String>[
            "text: currentTab == _kAiTab "
                "? 'IA' : 'PRO'",
            'color: currentTab == _kAiTab',
            '? const Color(0xFF00C781)',
            ': const Color(0xFF059669))',
            '? const Color(0xFFFFD700)',
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
