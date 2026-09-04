import 'package:flutter/material.dart';

import '../foundation/med_typography.dart';
import '../tokens/med_colors.dart';
import '../tokens/med_radius.dart';
import '../tokens/med_spacing.dart';

/// Variações semânticas oficiais do [MedBadge].
enum MedBadgeVariant {
  neutral,
  primary,
  success,
  warning,
  error,
  information,
  premium,
  ai,
}

/// Tamanhos oficiais do [MedBadge].
enum MedBadgeSize {
  small,
  medium,
}

/// Badge reutilizável oficial do MedCases Next.
class MedBadge extends StatelessWidget {
  const MedBadge({
    required this.label,
    super.key,
    this.variant = MedBadgeVariant.neutral,
    this.size = MedBadgeSize.medium,
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final MedBadgeVariant variant;
  final MedBadgeSize size;
  final IconData? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _MedBadgePalette palette = _resolvePalette(isDark);
    final _MedBadgeMetrics metrics = _resolveMetrics();

    return Semantics(
      container: true,
      label: semanticLabel ?? label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: MedRadius.pill,
          border: Border.all(
            color: palette.border,
          ),
        ),
        child: Padding(
          padding: metrics.padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: metrics.iconSize,
                  color: palette.foreground,
                ),
                SizedBox(width: metrics.gap),
              ],
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MedTypography.badge.copyWith(
                  color: palette.foreground,
                  fontSize: metrics.fontSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _MedBadgeMetrics _resolveMetrics() {
    switch (size) {
      case MedBadgeSize.small:
        return const _MedBadgeMetrics(
          padding: EdgeInsets.symmetric(
            horizontal: MedSpacing.sm,
            vertical: MedSpacing.xs,
          ),
          iconSize: 12,
          fontSize: 10,
          gap: MedSpacing.xs,
        );
      case MedBadgeSize.medium:
        return const _MedBadgeMetrics(
          padding: EdgeInsets.symmetric(
            horizontal: MedSpacing.md,
            vertical: MedSpacing.xs,
          ),
          iconSize: 14,
          fontSize: 11,
          gap: MedSpacing.xs,
        );
    }
  }

  _MedBadgePalette _resolvePalette(bool isDark) {
    switch (variant) {
      case MedBadgeVariant.neutral:
        return _MedBadgePalette(
          background: isDark
              ? MedColors.darkSurfaceSecondary
              : MedColors.surfaceSecondary,
          foreground:
              isDark ? MedColors.darkTextSecondary : MedColors.textSecondary,
          border: isDark ? MedColors.darkBorder : MedColors.border,
        );
      case MedBadgeVariant.primary:
        return const _MedBadgePalette(
          background: MedColors.primary,
          foreground: MedColors.surface,
          border: MedColors.primary,
        );
      case MedBadgeVariant.success:
        return const _MedBadgePalette(
          background: Color(0x1F397A55),
          foreground: MedColors.success,
          border: Color(0x66397A55),
        );
      case MedBadgeVariant.warning:
        return const _MedBadgePalette(
          background: Color(0x1F946C23),
          foreground: MedColors.warning,
          border: Color(0x66946C23),
        );
      case MedBadgeVariant.error:
        return const _MedBadgePalette(
          background: Color(0x1F9D4141),
          foreground: MedColors.error,
          border: Color(0x669D4141),
        );
      case MedBadgeVariant.information:
        return const _MedBadgePalette(
          background: Color(0x1F426B91),
          foreground: MedColors.information,
          border: Color(0x66426B91),
        );
      case MedBadgeVariant.premium:
        return const _MedBadgePalette(
          background: Color(0x1F6C6251),
          foreground: MedColors.premium,
          border: Color(0x666C6251),
        );
      case MedBadgeVariant.ai:
        return const _MedBadgePalette(
          background: Color(0x1F596878),
          foreground: MedColors.aiAccent,
          border: Color(0x66596878),
        );
    }
  }
}

class _MedBadgeMetrics {
  const _MedBadgeMetrics({
    required this.padding,
    required this.iconSize,
    required this.fontSize,
    required this.gap,
  });

  final EdgeInsets padding;
  final double iconSize;
  final double fontSize;
  final double gap;
}

class _MedBadgePalette {
  const _MedBadgePalette({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}
