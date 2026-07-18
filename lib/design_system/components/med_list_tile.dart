import 'package:flutter/material.dart';

import '../foundation/med_typography.dart';
import '../tokens/med_animation.dart';
import '../tokens/med_colors.dart';
import '../tokens/med_icons.dart';
import '../tokens/med_radius.dart';
import '../tokens/med_spacing.dart';

/// Variações oficiais do [MedListTile].
enum MedListTileVariant {
  standard,
  outlined,
  filled,
}

/// Item de lista reutilizável oficial do MedCases Next.
class MedListTile extends StatelessWidget {
  const MedListTile({
    required this.title,
    super.key,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.selected = false,
    this.showChevron = false,
    this.variant = MedListTileVariant.standard,
    this.padding = const EdgeInsets.symmetric(
      horizontal: MedSpacing.lg,
      vertical: MedSpacing.md,
    ),
    this.semanticLabel,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool selected;
  final bool showChevron;
  final MedListTileVariant variant;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  bool get _isInteractive => enabled && onTap != null;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _MedListTilePalette palette = _resolvePalette(isDark);

    final Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (leading != null) ...<Widget>[
          leading!,
          const SizedBox(width: MedSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MedTypography.cardTitle.copyWith(
                  color: palette.title,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: MedSpacing.xs),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MedTypography.bodySmall.copyWith(
                    color: palette.subtitle,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: MedSpacing.md),
          trailing!,
        ] else if (showChevron) ...<Widget>[
          const SizedBox(width: MedSpacing.md),
          Icon(
            MedIcons.forward,
            size: MedIcons.medium,
            color: palette.subtitle,
          ),
        ],
      ],
    );

    return Semantics(
      button: _isInteractive,
      enabled: enabled,
      selected: selected,
      label: semanticLabel ?? title,
      child: AnimatedContainer(
        duration: MedAnimation.fade,
        curve: MedAnimation.standard,
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
            onTap: _isInteractive ? onTap : null,
            borderRadius: MedRadius.medium,
            child: Padding(
              padding: padding,
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  _MedListTilePalette _resolvePalette(bool isDark) {
    if (!enabled) {
      return _MedListTilePalette(
        background: Colors.transparent,
        title: isDark ? MedColors.darkTextMuted : MedColors.disabled,
        subtitle: isDark ? MedColors.darkTextMuted : MedColors.disabled,
        border: Colors.transparent,
      );
    }

    if (selected) {
      return _MedListTilePalette(
        background: isDark
            ? MedColors.darkSurfaceSecondary
            : MedColors.surfaceSecondary,
        title: isDark ? MedColors.darkTextPrimary : MedColors.textPrimary,
        subtitle:
            isDark ? MedColors.darkTextSecondary : MedColors.textSecondary,
        border: isDark ? MedColors.darkBorderStrong : MedColors.borderStrong,
      );
    }

    switch (variant) {
      case MedListTileVariant.standard:
        return _MedListTilePalette(
          background: Colors.transparent,
          title: isDark ? MedColors.darkTextPrimary : MedColors.textPrimary,
          subtitle:
              isDark ? MedColors.darkTextSecondary : MedColors.textSecondary,
          border: Colors.transparent,
        );
      case MedListTileVariant.outlined:
        return _MedListTilePalette(
          background: Colors.transparent,
          title: isDark ? MedColors.darkTextPrimary : MedColors.textPrimary,
          subtitle:
              isDark ? MedColors.darkTextSecondary : MedColors.textSecondary,
          border: isDark ? MedColors.darkBorder : MedColors.border,
        );
      case MedListTileVariant.filled:
        return _MedListTilePalette(
          background: isDark
              ? MedColors.darkSurfaceSecondary
              : MedColors.surfaceSecondary,
          title: isDark ? MedColors.darkTextPrimary : MedColors.textPrimary,
          subtitle:
              isDark ? MedColors.darkTextSecondary : MedColors.textSecondary,
          border: Colors.transparent,
        );
    }
  }
}

class _MedListTilePalette {
  const _MedListTilePalette({
    required this.background,
    required this.title,
    required this.subtitle,
    required this.border,
  });

  final Color background;
  final Color title;
  final Color subtitle;
  final Color border;
}
