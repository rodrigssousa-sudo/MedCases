import 'package:flutter/material.dart';

import '../foundation/med_typography.dart';
import '../tokens/med_animation.dart';
import '../tokens/med_colors.dart';
import '../tokens/med_radius.dart';
import '../tokens/med_spacing.dart';

/// Variações oficiais do [MedButton].
enum MedButtonVariant {
  primary,
  secondary,
  outlined,
  ghost,
  destructive,
}

/// Tamanhos oficiais do [MedButton].
enum MedButtonSize {
  small,
  medium,
  large,
}

/// Botão textual reutilizável oficial do MedCases Next.
class MedButton extends StatelessWidget {
  const MedButton({
    required this.label,
    super.key,
    this.onPressed,
    this.variant = MedButtonVariant.primary,
    this.size = MedButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final MedButtonVariant variant;
  final MedButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool expand;
  final String? semanticLabel;

  bool get _isEnabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final _MedButtonMetrics metrics = _metrics;
    final _MedButtonPalette palette = _resolvePalette(context);

    final Widget child = AnimatedSwitcher(
      duration: MedAnimation.fade,
      switchInCurve: MedAnimation.entrance,
      switchOutCurve: MedAnimation.exit,
      child: isLoading
          ? SizedBox(
              key: const ValueKey<String>('loading'),
              width: metrics.iconSize,
              height: metrics.iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.foreground,
              ),
            )
          : Row(
              key: const ValueKey<String>('content'),
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (leadingIcon != null) ...<Widget>[
                  Icon(
                    leadingIcon,
                    size: metrics.iconSize,
                    color: palette.foreground,
                  ),
                  const SizedBox(width: MedSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MedTypography.button.copyWith(
                      color: palette.foreground,
                    ),
                  ),
                ),
                if (trailingIcon != null) ...<Widget>[
                  const SizedBox(width: MedSpacing.sm),
                  Icon(
                    trailingIcon,
                    size: metrics.iconSize,
                    color: palette.foreground,
                  ),
                ],
              ],
            ),
    );

    final Widget button = AnimatedContainer(
      duration: MedAnimation.fade,
      curve: MedAnimation.standard,
      constraints: BoxConstraints(
        minHeight: metrics.height,
        minWidth: metrics.minimumWidth,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: MedRadius.medium,
        border: Border.all(
          color: palette.border,
          width: palette.border == Colors.transparent ? 0 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isEnabled ? onPressed : null,
          borderRadius: MedRadius.medium,
          child: Padding(
            padding: metrics.padding,
            child: child,
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: semanticLabel ?? label,
      child: expand
          ? SizedBox(
              width: double.infinity,
              child: button,
            )
          : button,
    );
  }

  _MedButtonMetrics get _metrics {
    switch (size) {
      case MedButtonSize.small:
        return const _MedButtonMetrics(
          height: 36,
          minimumWidth: 72,
          iconSize: 16,
          padding: EdgeInsets.symmetric(
            horizontal: MedSpacing.md,
            vertical: MedSpacing.sm,
          ),
        );
      case MedButtonSize.medium:
        return const _MedButtonMetrics(
          height: 44,
          minimumWidth: 88,
          iconSize: 20,
          padding: EdgeInsets.symmetric(
            horizontal: MedSpacing.lg,
            vertical: MedSpacing.md,
          ),
        );
      case MedButtonSize.large:
        return const _MedButtonMetrics(
          height: 52,
          minimumWidth: 104,
          iconSize: 24,
          padding: EdgeInsets.symmetric(
            horizontal: MedSpacing.xl,
            vertical: MedSpacing.md,
          ),
        );
    }
  }

  _MedButtonPalette _resolvePalette(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_isEnabled) {
      return _MedButtonPalette(
        background: isDark
            ? MedColors.darkSurfaceSecondary
            : MedColors.surfaceSecondary,
        foreground: isDark ? MedColors.darkTextMuted : MedColors.disabled,
        border: Colors.transparent,
      );
    }

    switch (variant) {
      case MedButtonVariant.primary:
        return _MedButtonPalette(
          background: isDark ? MedColors.darkTextPrimary : MedColors.primary,
          foreground: isDark ? MedColors.darkBackground : MedColors.surface,
          border: Colors.transparent,
        );
      case MedButtonVariant.secondary:
        return _MedButtonPalette(
          background: isDark
              ? MedColors.darkSurfaceSecondary
              : MedColors.surfaceSecondary,
          foreground:
              isDark ? MedColors.darkTextPrimary : MedColors.textPrimary,
          border: Colors.transparent,
        );
      case MedButtonVariant.outlined:
        return _MedButtonPalette(
          background: Colors.transparent,
          foreground:
              isDark ? MedColors.darkTextPrimary : MedColors.textPrimary,
          border: isDark ? MedColors.darkBorderStrong : MedColors.borderStrong,
        );
      case MedButtonVariant.ghost:
        return _MedButtonPalette(
          background: Colors.transparent,
          foreground:
              isDark ? MedColors.darkTextSecondary : MedColors.textSecondary,
          border: Colors.transparent,
        );
      case MedButtonVariant.destructive:
        return const _MedButtonPalette(
          background: MedColors.error,
          foreground: MedColors.surface,
          border: Colors.transparent,
        );
    }
  }
}

class _MedButtonMetrics {
  const _MedButtonMetrics({
    required this.height,
    required this.minimumWidth,
    required this.iconSize,
    required this.padding,
  });

  final double height;
  final double minimumWidth;
  final double iconSize;
  final EdgeInsets padding;
}

class _MedButtonPalette {
  const _MedButtonPalette({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}
