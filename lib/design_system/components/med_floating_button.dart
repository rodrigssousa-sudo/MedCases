import 'package:flutter/material.dart';

import '../foundation/med_typography.dart';
import '../tokens/med_animation.dart';
import '../tokens/med_colors.dart';
import '../tokens/med_elevation.dart';
import '../tokens/med_icons.dart';
import '../tokens/med_radius.dart';
import '../tokens/med_spacing.dart';

/// Variações oficiais do [MedFloatingButton].
enum MedFloatingButtonVariant {
  primary,
  secondary,
  destructive,
}

/// Botão flutuante reutilizável oficial do MedCases Next.
class MedFloatingButton extends StatelessWidget {
  const MedFloatingButton({
    required this.icon,
    required this.tooltip,
    super.key,
    this.label,
    this.onPressed,
    this.variant = MedFloatingButtonVariant.primary,
    this.isLoading = false,
    this.semanticLabel,
  });

  final IconData icon;
  final String tooltip;
  final String? label;
  final VoidCallback? onPressed;
  final MedFloatingButtonVariant variant;
  final bool isLoading;
  final String? semanticLabel;

  bool get _isEnabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final _MedFloatingPalette palette = _resolvePalette(context);

    final Widget content = AnimatedSwitcher(
      duration: MedAnimation.fade,
      child: isLoading
          ? SizedBox(
              key: const ValueKey<String>('loading'),
              width: MedIcons.medium,
              height: MedIcons.medium,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.foreground,
              ),
            )
          : Row(
              key: const ValueKey<String>('content'),
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  size: MedIcons.large,
                  color: palette.foreground,
                ),
                if (label != null) ...<Widget>[
                  const SizedBox(width: MedSpacing.sm),
                  Text(
                    label!,
                    style: MedTypography.button.copyWith(
                      color: palette.foreground,
                    ),
                  ),
                ],
              ],
            ),
    );

    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: semanticLabel ?? label ?? tooltip,
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: MedAnimation.fade,
          curve: MedAnimation.standard,
          constraints: const BoxConstraints(
            minWidth: 56,
            minHeight: 56,
          ),
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: label == null ? MedRadius.circle(56) : MedRadius.pill,
            boxShadow: MedElevation.large,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isEnabled ? onPressed : null,
              borderRadius:
                  label == null ? MedRadius.circle(56) : MedRadius.pill,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: label == null ? MedSpacing.lg : MedSpacing.xl,
                  vertical: MedSpacing.lg,
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  _MedFloatingPalette _resolvePalette(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_isEnabled) {
      return _MedFloatingPalette(
        background: isDark
            ? MedColors.darkSurfaceSecondary
            : MedColors.surfaceSecondary,
        foreground: isDark ? MedColors.darkTextMuted : MedColors.disabled,
      );
    }

    switch (variant) {
      case MedFloatingButtonVariant.primary:
        return _MedFloatingPalette(
          background: isDark ? MedColors.darkTextPrimary : MedColors.primary,
          foreground: isDark ? MedColors.darkBackground : MedColors.surface,
        );
      case MedFloatingButtonVariant.secondary:
        return _MedFloatingPalette(
          background: isDark
              ? MedColors.darkSurfaceElevated
              : MedColors.surfaceElevated,
          foreground:
              isDark ? MedColors.darkTextPrimary : MedColors.textPrimary,
        );
      case MedFloatingButtonVariant.destructive:
        return const _MedFloatingPalette(
          background: MedColors.error,
          foreground: MedColors.surface,
        );
    }
  }
}

class _MedFloatingPalette {
  const _MedFloatingPalette({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}
