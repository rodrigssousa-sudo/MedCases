import 'package:flutter/material.dart';

import '../foundation/med_typography.dart';
import '../tokens/med_colors.dart';
import '../tokens/med_radius.dart';

/// Temas neutros oficiais da fundação MedCases Next.
///
/// Nenhum tema é conectado ao aplicativo legado nesta fase.
abstract final class MedTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: MedColors.primary,
      brightness: Brightness.light,
      primary: MedColors.primary,
      secondary: MedColors.secondary,
      surface: MedColors.surface,
      error: MedColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: MedTypography.fontFamily,
      fontFamilyFallback: MedTypography.fontFamilyFallback,
      scaffoldBackgroundColor: MedColors.background,
      colorScheme: colorScheme,
      textTheme: _applyTextColors(
        MedTypography.textTheme,
        primary: MedColors.textPrimary,
        secondary: MedColors.textSecondary,
      ),
      dividerColor: MedColors.divider,
      disabledColor: MedColors.disabled,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      dividerTheme: const DividerThemeData(
        color: MedColors.divider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: MedColors.surfaceSecondary,
        hintStyle: TextStyle(
          color: MedColors.placeholder,
          fontFamily: MedTypography.fontFamily,
        ),
        border: OutlineInputBorder(
          borderRadius: MedRadius.medium,
          borderSide: BorderSide(color: MedColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: MedRadius.medium,
          borderSide: BorderSide(color: MedColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: MedRadius.medium,
          borderSide: BorderSide(
            color: MedColors.borderStrong,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: MedRadius.medium,
          borderSide: BorderSide(color: MedColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: MedRadius.medium,
          borderSide: BorderSide(
            color: MedColors.error,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: MedColors.primary,
      brightness: Brightness.dark,
      primary: MedColors.darkTextPrimary,
      secondary: MedColors.darkTextSecondary,
      surface: MedColors.darkSurface,
      error: MedColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: MedTypography.fontFamily,
      fontFamilyFallback: MedTypography.fontFamilyFallback,
      scaffoldBackgroundColor: MedColors.darkBackground,
      colorScheme: colorScheme,
      textTheme: _applyTextColors(
        MedTypography.textTheme,
        primary: MedColors.darkTextPrimary,
        secondary: MedColors.darkTextSecondary,
      ),
      dividerColor: MedColors.darkDivider,
      disabledColor: MedColors.darkTextMuted,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      dividerTheme: const DividerThemeData(
        color: MedColors.darkDivider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: MedColors.darkSurfaceSecondary,
        hintStyle: TextStyle(
          color: MedColors.darkTextMuted,
          fontFamily: MedTypography.fontFamily,
        ),
        border: OutlineInputBorder(
          borderRadius: MedRadius.medium,
          borderSide: BorderSide(color: MedColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: MedRadius.medium,
          borderSide: BorderSide(color: MedColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: MedRadius.medium,
          borderSide: BorderSide(
            color: MedColors.darkBorderStrong,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: MedRadius.medium,
          borderSide: BorderSide(color: MedColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: MedRadius.medium,
          borderSide: BorderSide(
            color: MedColors.error,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  static TextTheme _applyTextColors(
    TextTheme source, {
    required Color primary,
    required Color secondary,
  }) {
    return source.copyWith(
      displayLarge: source.displayLarge?.copyWith(color: primary),
      displayMedium: source.displayMedium?.copyWith(color: primary),
      displaySmall: source.displaySmall?.copyWith(color: primary),
      headlineLarge: source.headlineLarge?.copyWith(color: primary),
      headlineMedium: source.headlineMedium?.copyWith(color: primary),
      headlineSmall: source.headlineSmall?.copyWith(color: primary),
      titleLarge: source.titleLarge?.copyWith(color: primary),
      titleMedium: source.titleMedium?.copyWith(color: primary),
      titleSmall: source.titleSmall?.copyWith(color: primary),
      bodyLarge: source.bodyLarge?.copyWith(color: primary),
      bodyMedium: source.bodyMedium?.copyWith(color: primary),
      bodySmall: source.bodySmall?.copyWith(color: secondary),
      labelLarge: source.labelLarge?.copyWith(color: primary),
      labelMedium: source.labelMedium?.copyWith(color: secondary),
      labelSmall: source.labelSmall?.copyWith(color: secondary),
    );
  }
}
