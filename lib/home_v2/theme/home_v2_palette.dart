import 'package:flutter/material.dart';

/// Paleta visual oficial e compartilhada da Home V2.
///
/// Contém somente tokens de apresentação. Não possui navegação, persistência,
/// estado funcional, lógica clínica ou dependência da tela temporária de
/// preview.
@immutable
class HomeV2Palette {
  const HomeV2Palette._({
    required this.background,
    required this.surface,
    required this.surfaceSoft,
    required this.surfaceStrong,
    required this.surfaceActive,
    required this.shortcutSurface,
    required this.border,
    required this.divider,
    required this.dividerStrong,
    required this.borderActive,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentSoft,
    required this.pressedOverlayColor,
  });

  final Color background;
  final Color surface;
  final Color surfaceSoft;
  final Color surfaceStrong;
  final Color surfaceActive;
  final Color shortcutSurface;

  final Color border;
  final Color divider;
  final Color dividerStrong;
  final Color borderActive;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color accent;
  final Color accentSoft;
  final Color pressedOverlayColor;

  static const HomeV2Palette dark = HomeV2Palette._(
    background: Color(0xFF1A1D23),
    surface: Color(0xFF252930),
    surfaceSoft: Color(0xFF1A1D23),
    surfaceStrong: Color(0xFF2D3340),
    surfaceActive: Color(0xFF2D3340),
    shortcutSurface: Color(0xFF2D3340),
    border: Color(0xFF374151),
    divider: Color(0xFF2D3340),
    dividerStrong: Color(0xFF374151),
    borderActive: Color(0xFF6B7280),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFFFFFFF),
    textMuted: Color(0xFFFFFFFF),
    accent: Color(0xFF0D6B57),
    accentSoft: Color(0x1F0D6B57),
    pressedOverlayColor: Color(0x40374151),
  );

  static const HomeV2Palette light = HomeV2Palette._(
    background: Color(0xFFECF1F3),
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFF6F8FA),
    surfaceStrong: Color(0xFFF8FAFC),
    surfaceActive: Color(0xFFF6F8FA),
    shortcutSurface: Color(0xFFF8FAFC),
    border: Color(0xFFE7EBEF),
    divider: Color(0xFFE1E7ED),
    dividerStrong: Color(0xFFD8E0E7),
    borderActive: Color(0xFFB8C3CD),
    textPrimary: Color(0xFF05070A),
    textSecondary: Color(0xFF59636E),
    textMuted: Color(0xFF8A939D),
    accent: Color(0xFF0D6B57),
    accentSoft: Color(0x140D6B57),
    pressedOverlayColor: Color(0x1459636E),
  );

  static HomeV2Palette resolve(bool dark) {
    return dark ? HomeV2Palette.dark : HomeV2Palette.light;
  }

  WidgetStateProperty<Color?> get pressedOverlay {
    return WidgetStateProperty.resolveWith<Color?>(
      (states) {
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return pressedOverlayColor;
        }

        return null;
      },
    );
  }
}
