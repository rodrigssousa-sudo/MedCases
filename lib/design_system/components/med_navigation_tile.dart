import 'package:flutter/material.dart';

import '../foundation/med_typography.dart';
import '../tokens/med_animation.dart';
import '../tokens/med_colors.dart';
import '../tokens/med_icons.dart';
import '../tokens/med_radius.dart';
import '../tokens/med_spacing.dart';
import 'med_badge.dart';

/// Orientações oficiais do [MedNavigationTile].
enum MedNavigationTileOrientation {
  horizontal,
  vertical,
}

/// Item de navegação reutilizável oficial do MedCases Next.
class MedNavigationTile extends StatelessWidget {
  const MedNavigationTile({
    required this.label,
    required this.icon,
    super.key,
    this.selectedIcon,
    this.onTap,
    this.selected = false,
    this.enabled = true,
    this.orientation = MedNavigationTileOrientation.horizontal,
    this.badgeLabel,
    this.semanticLabel,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final VoidCallback? onTap;
  final bool selected;
  final bool enabled;
  final MedNavigationTileOrientation orientation;
  final String? badgeLabel;
  final String? semanticLabel;

  bool get _isInteractive => enabled && onTap != null;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _MedNavigationPalette palette = _resolvePalette(isDark);
    final IconData resolvedIcon = selected ? selectedIcon ?? icon : icon;

    final Widget iconWidget = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Icon(
          resolvedIcon,
          size: MedIcons.large,
          color: palette.foreground,
        ),
        if (badgeLabel != null)
          Positioned(
            top: -10,
            right: -14,
            child: MedBadge(
              label: badgeLabel!,
              size: MedBadgeSize.small,
              variant: MedBadgeVariant.error,
            ),
          ),
      ],
    );

    final Widget content = switch (orientation) {
      MedNavigationTileOrientation.horizontal => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            iconWidget,
            const SizedBox(width: MedSpacing.md),
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
          ],
        ),
      MedNavigationTileOrientation.vertical => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            iconWidget,
            const SizedBox(height: MedSpacing.sm),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: MedTypography.caption.copyWith(
                color: palette.foreground,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
    };

    return Semantics(
      button: _isInteractive,
      selected: selected,
      enabled: enabled,
      label: semanticLabel ?? label,
      child: AnimatedContainer(
        duration: MedAnimation.fade,
        curve: MedAnimation.standard,
        constraints: BoxConstraints(
          minHeight:
              orientation == MedNavigationTileOrientation.vertical ? 64 : 44,
          minWidth:
              orientation == MedNavigationTileOrientation.vertical ? 72 : 96,
        ),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: MedRadius.medium,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isInteractive ? onTap : null,
            borderRadius: MedRadius.medium,
            child: Padding(
              padding: orientation == MedNavigationTileOrientation.vertical
                  ? const EdgeInsets.symmetric(
                      horizontal: MedSpacing.sm,
                      vertical: MedSpacing.md,
                    )
                  : const EdgeInsets.symmetric(
                      horizontal: MedSpacing.md,
                      vertical: MedSpacing.sm,
                    ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  _MedNavigationPalette _resolvePalette(bool isDark) {
    if (!enabled) {
      return _MedNavigationPalette(
        background: Colors.transparent,
        foreground: isDark ? MedColors.darkTextMuted : MedColors.disabled,
      );
    }

    if (selected) {
      return _MedNavigationPalette(
        background: isDark
            ? MedColors.darkSurfaceSecondary
            : MedColors.surfaceSecondary,
        foreground: isDark ? MedColors.darkTextPrimary : MedColors.textPrimary,
      );
    }

    return _MedNavigationPalette(
      background: Colors.transparent,
      foreground:
          isDark ? MedColors.darkTextSecondary : MedColors.textSecondary,
    );
  }
}

class _MedNavigationPalette {
  const _MedNavigationPalette({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}
