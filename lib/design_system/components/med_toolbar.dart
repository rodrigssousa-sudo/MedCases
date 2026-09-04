import 'package:flutter/material.dart';

import '../foundation/med_typography.dart';
import '../tokens/med_colors.dart';
import '../tokens/med_elevation.dart';
import '../tokens/med_spacing.dart';

/// Variações oficiais do [MedToolbar].
enum MedToolbarVariant {
  transparent,
  surface,
  elevated,
}

/// Barra de ferramentas reutilizável oficial do MedCases Next.
class MedToolbar extends StatelessWidget implements PreferredSizeWidget {
  const MedToolbar({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.actions = const <Widget>[],
    this.bottom,
    this.variant = MedToolbarVariant.surface,
    this.centerTitle = false,
    this.height = 64,
    this.padding = const EdgeInsets.symmetric(
      horizontal: MedSpacing.lg,
    ),
    this.semanticLabel,
  });

  final String? title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;
  final MedToolbarVariant variant;
  final bool centerTitle;
  final double height;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  Size get preferredSize => Size.fromHeight(
        height + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _MedToolbarPalette palette = _resolvePalette(isDark);

    final Widget titleBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: <Widget>[
        if (title != null)
          Text(
            title!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: centerTitle ? TextAlign.center : TextAlign.start,
            style: MedTypography.cardTitle.copyWith(
              color: palette.primary,
            ),
          ),
        if (title != null && subtitle != null)
          const SizedBox(height: MedSpacing.xs),
        if (subtitle != null)
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: centerTitle ? TextAlign.center : TextAlign.start,
            style: MedTypography.caption.copyWith(
              color: palette.secondary,
            ),
          ),
      ],
    );

    return Semantics(
      container: true,
      header: true,
      label: semanticLabel ?? title,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.background,
          boxShadow: palette.shadows,
          border: Border(
            bottom: BorderSide(
              color: palette.border,
              width: palette.border == Colors.transparent ? 0 : 1,
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: height,
                child: Padding(
                  padding: padding,
                  child: Row(
                    children: <Widget>[
                      if (leading != null) ...<Widget>[
                        leading!,
                        const SizedBox(width: MedSpacing.md),
                      ],
                      Expanded(
                        child: centerTitle
                            ? Center(child: titleBlock)
                            : titleBlock,
                      ),
                      if (actions.isNotEmpty) ...<Widget>[
                        const SizedBox(width: MedSpacing.md),
                        Wrap(
                          spacing: MedSpacing.sm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: actions,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (bottom != null) bottom!,
            ],
          ),
        ),
      ),
    );
  }

  _MedToolbarPalette _resolvePalette(bool isDark) {
    switch (variant) {
      case MedToolbarVariant.transparent:
        return _MedToolbarPalette(
          background: Colors.transparent,
          primary: isDark ? MedColors.darkTextPrimary : MedColors.textPrimary,
          secondary:
              isDark ? MedColors.darkTextSecondary : MedColors.textSecondary,
          border: Colors.transparent,
          shadows: MedElevation.none,
        );
      case MedToolbarVariant.surface:
        return _MedToolbarPalette(
          background: isDark ? MedColors.darkSurface : MedColors.surface,
          primary: isDark ? MedColors.darkTextPrimary : MedColors.textPrimary,
          secondary:
              isDark ? MedColors.darkTextSecondary : MedColors.textSecondary,
          border: isDark ? MedColors.darkDivider : MedColors.divider,
          shadows: MedElevation.none,
        );
      case MedToolbarVariant.elevated:
        return _MedToolbarPalette(
          background: isDark
              ? MedColors.darkSurfaceElevated
              : MedColors.surfaceElevated,
          primary: isDark ? MedColors.darkTextPrimary : MedColors.textPrimary,
          secondary:
              isDark ? MedColors.darkTextSecondary : MedColors.textSecondary,
          border: Colors.transparent,
          shadows: MedElevation.small,
        );
    }
  }
}

class _MedToolbarPalette {
  const _MedToolbarPalette({
    required this.background,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.shadows,
  });

  final Color background;
  final Color primary;
  final Color secondary;
  final Color border;
  final List<BoxShadow> shadows;
}
