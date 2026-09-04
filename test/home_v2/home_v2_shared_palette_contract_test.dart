import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Home V2 — paleta compartilhada oficial', () {
    test(
      'possui uma única paleta pública Dark/Light oficial',
      () {
        final root = Directory.current;
        final paletteFile = File(
          '${root.path}/lib/home_v2/theme/home_v2_palette.dart',
        );

        expect(
          paletteFile.existsSync(),
          isTrue,
          reason: 'A implementação deve criar '
              'lib/home_v2/theme/home_v2_palette.dart.',
        );

        // O primeiro RED deve permanecer exclusivamente ligado à ausência
        // física do arquivo. As demais invariantes entram em ação após a criação.
        if (!paletteFile.existsSync()) {
          return;
        }

        final source = paletteFile.readAsStringSync();

        expect(
          source,
          contains('class HomeV2Palette'),
          reason: 'A paleta compartilhada deve ser pública.',
        );

        expect(
          source,
          contains('resolve(bool dark)'),
          reason: 'A paleta deve resolver o modo Dark/Light real.',
        );

        for (final token in <String>[
          // Estrutura Dark.
          '0xFF1A1D23',
          '0xFF252930',
          '0xFF1A1D23',
          '0xFF2D3340',
          '0xFF2D3340',
          '0xFF374151',
          '0xFF2D3340',
          '0xFF374151',
          '0xFF6B7280',
          '0xFFFFFFFF',
          '0xFF00C781',
          '0x1F00C781',

          // Estrutura Light.
          '0xFFF3F5F7',
          '0xFFF6F8FA',
          '0xFFF8FAFC',
          '0xFFE7EBEF',
          '0xFFEEF1F4',
          '0xFFE6EAEE',
          '0xFFB8C3CD',
          '0xFF05070A',
          '0xFF59636E',
          '0xFF8A939D',
          '0xFF008F66',
          '0xFFE5F4EE',
        ]) {
          expect(
            source,
            contains(token),
            reason: 'Token oficial ausente da paleta compartilhada: $token',
          );
        }

        for (final field in <String>[
          'background',
          'surface',
          'surfaceSoft',
          'surfaceStrong',
          'surfaceActive',
          'shortcutSurface',
          'border',
          'divider',
          'dividerStrong',
          'borderActive',
          'textPrimary',
          'textSecondary',
          'textMuted',
          'accent',
          'accentSoft',
          'pressedOverlayColor',
        ]) {
          expect(
            source,
            contains(field),
            reason: 'Propriedade estrutural ausente: $field',
          );
        }

        expect(
          source,
          isNot(contains('HOME_V2_LIGHT_PREVIEW')),
          reason: 'A produção não deve depender da flag temporária do preview.',
        );

        expect(
          source,
          isNot(contains('preview/home_v2_preview_screen.dart')),
          reason:
              'A paleta oficial não pode importar a tela temporária de preview.',
        );
      },
    );
  });
}
