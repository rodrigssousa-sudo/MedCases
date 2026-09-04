import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Home V2 — IA consome a paleta compartilhada', () {
    test(
      'abandona a paleta grafite/dourada e resolve Dark/Light pelo parâmetro dark',
      () {
        final root = Directory.current;

        final chatFile = File(
          '${root.path}/lib/home_v2/components/chat/inline_chat_view.dart',
        );
        final paletteFile = File(
          '${root.path}/lib/home_v2/theme/home_v2_palette.dart',
        );

        expect(
          chatFile.existsSync(),
          isTrue,
          reason: 'A view visual canônica da IA deve existir.',
        );

        expect(
          paletteFile.existsSync(),
          isTrue,
          reason: 'A paleta compartilhada oficial deve existir.',
        );

        final chatSource = chatFile.readAsStringSync();
        final paletteSource = paletteFile.readAsStringSync();

        expect(
          chatSource,
          contains('../../theme/home_v2_palette.dart'),
          reason: 'A IA deve importar a paleta compartilhada oficial.',
        );

        expect(
          chatSource,
          contains('final palette = HomeV2Palette.resolve(dark);'),
          reason: 'A IA deve resolver Dark/Light pelo parâmetro dark real.',
        );

        expect(
          chatSource,
          isNot(contains('class _InlineChatV2Palette')),
          reason: 'A paleta privada intermediária da IA deve ser removida.',
        );

        for (final forbiddenToken in const [
          '0xFFD4AF37',
          '0xFF1A1C21',
          '0xFF25272D',
          '0xFF3A3D45',
          '0xFFF4F4F5',
        ]) {
          expect(
            chatSource,
            isNot(contains(forbiddenToken)),
            reason: 'Token intermediário proibido na IA: $forbiddenToken',
          );
        }

        expect(
          chatSource,
          isNot(contains('preview/home_v2_preview_screen.dart')),
          reason: 'A produção não pode depender da tela temporária de preview.',
        );

        expect(
          paletteSource,
          contains('class HomeV2Palette'),
          reason: 'A classe compartilhada oficial deve permanecer pública.',
        );

        expect(
          paletteSource,
          contains('HomeV2Palette resolve(bool dark)'),
          reason:
              'A resolução compartilhada Dark/Light deve permanecer válida.',
        );

        for (final preservedContract in const [
          'class HomeInlineChatV2View extends StatelessWidget',
          'required this.dark',
          'required this.messages',
          'required this.streaming',
          'required this.thinking',
          'required this.onSend',
          'required this.onHistory',
          'required this.onNewChat',
          'required this.onToggleExpanded',
        ]) {
          expect(
            chatSource,
            contains(preservedContract),
            reason: 'Contrato funcional da IA ausente: $preservedContract',
          );
        }
      },
    );
  });
}
