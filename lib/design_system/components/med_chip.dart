import 'package:flutter/material.dart';

import '../foundation/med_typography.dart';
import '../tokens/med_animation.dart';
import '../tokens/med_colors.dart';
import '../tokens/med_icons.dart';
import '../tokens/med_radius.dart';
import '../tokens/med_spacing.dart';

/// Variações oficiais do [MedChip].
enum MedChipVariant {
  standard,
  outlined,
  selected,
  removable,
}

/// Chip reutilizável oficial do MedCases Next.
class MedChip extends StatelessWidget {
  const MedChip({
    required this.label,
    super.key,
    this.variant = MedChipVariant.standard,
    this.leadingIcon,
    this.selected = false,
    this.enabled = true,
    this.onPressed,
    this.onRemoved,
    this.semanticLabel,
  });

  final String label;
  final MedChipVariant variant;
  final IconData? leadingIcon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onPressed;
  final VoidCallback? onRemoved;
  final String? semanticLabel;

  bool get _isInteractive => enabled && onPressed != null;
  bool get _isRemovable =>
      enabled && variant == MedChipVariant.removable && onRemoved != null;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _MedChipPalette palette = _resolvePalette(isDark);

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (leadingIcon != null) ...<Widget>[
          Icon(
            leadingIcon,
            size: MedIcons.small,
            color: palette.foreground,
          ),
          const SizedBox(width: MedSpacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MedTypography.label.copyWith(
              color: palette.foreground,
            ),
          ),
        ),
        if (_isRemovable) ...<Widget>[
          const SizedBox(width: MedSpacing.sm),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRemoved,
            child: Icon(
              MedIcons.close,
              size: MedIcons.small,
              color: palette.foreground,
            ),
          ),
        ],
      ],
    );

    final Widget chip = AnimatedContainer(
      duration: MedAnimation.fade,
      curve: MedAnimation.standard,
      constraints: const BoxConstraints(
        minHeight: 36,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: MedRadius.pill,
        border: Border.all(
          color: palette.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isInteractive ? onPressed : null,
          borderRadius: MedRadius.pill,
          child: const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MedSpacing.md,
              vertical: MedSpacing.sm,
            ),
            child: SizedBox.shrink(),
          ),
        ),
      ),
    );

    return Semantics(
      button: _isInteractive,
      enabled: enabled,
      selected: selected || variant == MedChipVariant.selected,
      label: semanticLabel ?? label,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          chip,
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MedSpacing.md,
                vertical: MedSpacing.sm,
              ),
              child: content,
            ),
          ),
        ],
      ),
    );
  }

  _MedChipPalette _resolvePalette(bool isDark) {
    if (!enabled) {
      return _MedChipPalette(
        background: isDark ? MedColors.darkSurface : MedColors.surfaceSecondary,
        foreground: isDark ? MedColors.darkTextMuted : MedColors.disabled,
        border: isDark ? MedColors.darkBorder : MedColors.border,
      );
    }

    if (selected || variant == MedChipVariant.selected) {
      return _MedChipPalette(
        background: isDark ? MedColors.darkTextPrimary : MedColors.primary,
        foreground: isDark ? MedColors.darkBackground : MedColors.surface,
        border: isDark ? MedColors.darkTextPrimary : MedColors.primary,
      );
    }

    switch (variant) {
      case MedChipVariant.standard:
      case MedChipVariant.removable:
        return _MedChipPalette(
          background: isDark
              ? MedColors.darkSurfaceSecondary
              : MedColors.surfaceSecondary,
          foreground:
              isDark ? MedColors.darkTextSecondary : MedColors.textSecondary,
          border: Colors.transparent,
        );
      case MedChipVariant.outlined:
        return _MedChipPalette(
          background: Colors.transparent,
          foreground:
              isDark ? MedColors.darkTextSecondary : MedColors.textSecondary,
          border: isDark ? MedColors.darkBorderStrong : MedColors.borderStrong,
        );
      case MedChipVariant.selected:
        return _MedChipPalette(
          background: isDark ? MedColors.darkTextPrimary : MedColors.primary,
          foreground: isDark ? MedColors.darkBackground : MedColors.surface,
          border: isDark ? MedColors.darkTextPrimary : MedColors.primary,
        );
    }
  }
}

class _MedChipPalette {
  const _MedChipPalette({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}
