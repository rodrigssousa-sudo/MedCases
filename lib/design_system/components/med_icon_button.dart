import 'package:flutter/material.dart';

import '../tokens/med_animation.dart';
import '../tokens/med_colors.dart';
import '../tokens/med_icons.dart';
import '../tokens/med_radius.dart';

/// Variações oficiais do [MedIconButton].
enum MedIconButtonVariant {
  standard,
  filled,
  outlined,
  destructive,
}

/// Tamanhos oficiais do [MedIconButton].
enum MedIconButtonSize {
  small,
  medium,
  large,
}

/// Botão de ícone reutilizável oficial do MedCases Next.
class MedIconButton extends StatelessWidget {
  const MedIconButton({
    required this.icon,
    required this.tooltip,
    super.key,
    this.onPressed,
    this.variant = MedIconButtonVariant.standard,
    this.size = MedIconButtonSize.medium,
    this.isLoading = false,
    this.semanticLabel,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final MedIconButtonVariant variant;
  final MedIconButtonSize size;
  final bool isLoading;
  final String? semanticLabel;

  bool get _isEnabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final _MedIconButtonMetrics metrics = _metrics;
    final _MedIconButtonPalette palette = _resolvePalette(context);

    final Widget content = AnimatedSwitcher(
      duration: MedAnimation.fade,
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
          : Icon(
              icon,
              key: const ValueKey<String>('icon'),
              size: metrics.iconSize,
              color: palette.foreground,
            ),
    );

    final Widget button = AnimatedContainer(
      duration: MedAnimation.fade,
      curve: MedAnimation.standard,
      width: metrics.containerSize,
      height: metrics.containerSize,
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
          child: Center(child: content),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: semanticLabel ?? tooltip,
      child: Tooltip(
        message: tooltip,
        child: button,
      ),
    );
  }

  _MedIconButtonMetrics get _metrics {
    switch (size) {
      case MedIconButtonSize.small:
        return const _MedIconButtonMetrics(
          containerSize: 36,
          iconSize: MedIcons.small,
        );
      case MedIconButtonSize.medium:
        return const _MedIconButtonMetrics(
          containerSize: 44,
          iconSize: MedIcons.medium,
        );
      case MedIconButtonSize.large:
        return const _MedIconButtonMetrics(
          containerSize: 52,
          iconSize: MedIcons.large,
        );
    }
  }

  _MedIconButtonPalette _resolvePalette(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_isEnabled) {
      return _MedIconButtonPalette(
        background: Colors.transparent,
        foreground: isDark ? MedColors.darkTextMuted : MedColors.disabled,
        border: Colors.transparent,
      );
    }

    switch (variant) {
      case MedIconButtonVariant.standard:
        return _MedIconButtonPalette(
          background: Colors.transparent,
          foreground:
              isDark ? MedColors.darkTextSecondary : MedColors.textSecondary,
          border: Colors.transparent,
        );
      case MedIconButtonVariant.filled:
        return _MedIconButtonPalette(
          background: isDark
              ? MedColors.darkSurfaceSecondary
              : MedColors.surfaceSecondary,
          foreground:
              isDark ? MedColors.darkTextPrimary : MedColors.textPrimary,
          border: Colors.transparent,
        );
      case MedIconButtonVariant.outlined:
        return _MedIconButtonPalette(
          background: Colors.transparent,
          foreground:
              isDark ? MedColors.darkTextPrimary : MedColors.textPrimary,
          border: isDark ? MedColors.darkBorderStrong : MedColors.borderStrong,
        );
      case MedIconButtonVariant.destructive:
        return const _MedIconButtonPalette(
          background: MedColors.error,
          foreground: MedColors.surface,
          border: Colors.transparent,
        );
    }
  }
}

class _MedIconButtonMetrics {
  const _MedIconButtonMetrics({
    required this.containerSize,
    required this.iconSize,
  });

  final double containerSize;
  final double iconSize;
}

class _MedIconButtonPalette {
  const _MedIconButtonPalette({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}
