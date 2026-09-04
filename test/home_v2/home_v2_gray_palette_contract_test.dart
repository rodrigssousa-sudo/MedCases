import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const palettePath = 'lib/home_v2/theme/home_v2_palette.dart';

  late String source;
  late String darkBlock;
  late String lightBlock;

  setUpAll(() {
    source = File(palettePath).readAsStringSync();

    final darkStart = source.indexOf(
      'static const HomeV2Palette dark',
    );

    final lightStart = source.indexOf(
      'static const HomeV2Palette light',
    );

    final resolveStart = source.indexOf(
      'static HomeV2Palette resolve',
    );

    expect(darkStart, greaterThanOrEqualTo(0));
    expect(lightStart, greaterThan(darkStart));
    expect(resolveStart, greaterThan(lightStart));

    darkBlock = source.substring(
      darkStart,
      lightStart,
    );

    lightBlock = source.substring(
      lightStart,
      resolveStart,
    );
  });

  group('Home V2 — paleta cinza oficial', () {
    test('dark usa os grafites estruturais oficiais', () {
      const requiredTokens = <String>[
        'background: Color(0xFF1A1D23)',
        'surface: Color(0xFF252930)',
        'surfaceSoft: Color(0xFF1A1D23)',
        'surfaceStrong: Color(0xFF2D3340)',
        'surfaceActive: Color(0xFF2D3340)',
        'shortcutSurface: Color(0xFF2D3340)',
        'border: Color(0xFF374151)',
        'divider: Color(0xFF2D3340)',
        'dividerStrong: Color(0xFF374151)',
        'borderActive: Color(0xFF6B7280)',
        'pressedOverlayColor: Color(0x40374151)',
      ];

      for (final token in requiredTokens) {
        expect(
          darkBlock,
          contains(token),
          reason: 'Token cinza obrigatório ausente: $token',
        );
      }
    });

    test('dark não conserva a família azul-petróleo', () {
      const forbiddenTokens = <String>[
        '0xFF070D16',
        '0xFF101C2C',
        '0xFF0B1522',
        '0xFF14243A',
        '0xFF182A40',
        '0xFF1B2B3E',
        '0xFF162538',
        '0xFF203247',
        '0xFF385778',
        '0x40243C5A',
      ];

      for (final token in forbiddenTokens) {
        expect(
          darkBlock,
          isNot(contains(token)),
          reason: 'Azul antigo ainda presente: $token',
        );
      }
    });

    test('preserva textos e verde oficial', () {
      const preservedTokens = <String>[
        'textPrimary: Color(0xFFFFFFFF)',
        'textSecondary: Color(0xFFFFFFFF)',
        'textMuted: Color(0xFFFFFFFF)',
        'accent: Color(0xFF00C781)',
        'accentSoft: Color(0x1F00C781)',
      ];

      for (final token in preservedTokens) {
        expect(darkBlock, contains(token));
      }
    });
  });

  group('Home V2 — modo light preservado', () {
    test('mantém integralmente os valores anteriores', () {
      const requiredTokens = <String>[
        'background: Color(0xFFECF1F3)',
        'surface: Color(0xFFFFFFFF)',
        'surfaceSoft: Color(0xFFF6F8FA)',
        'surfaceStrong: Color(0xFFF8FAFC)',
        'surfaceActive: Color(0xFFF6F8FA)',
        'shortcutSurface: Color(0xFFF8FAFC)',
        'border: Color(0xFFE7EBEF)',
        'divider: Color(0xFFE1E7ED)',
        'dividerStrong: Color(0xFFD8E0E7)',
        'borderActive: Color(0xFFB8C3CD)',
        'textPrimary: Color(0xFF05070A)',
        'textSecondary: Color(0xFF59636E)',
        'textMuted: Color(0xFF8A939D)',
        'accent: Color(0xFF008F66)',
        'accentSoft: Color(0xFFE5F4EE)',
        'pressedOverlayColor: Color(0x1459636E)',
      ];

      for (final token in requiredTokens) {
        expect(
          lightBlock,
          contains(token),
          reason: 'O modo light foi alterado: $token',
        );
      }
    });
  });
}
