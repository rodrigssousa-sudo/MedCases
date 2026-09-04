import 'package:flutter/material.dart';

import '../tokens/med_colors.dart';
import '../tokens/med_icons.dart';
import '../tokens/med_radius.dart';
import '../tokens/med_spacing.dart';
import 'med_list_tile.dart';

/// Item de menu oficial do MedCases Next.
class MedMenuTile extends StatelessWidget {
  const MedMenuTile({
    required this.title,
    required this.icon,
    super.key,
    this.subtitle,
    this.trailing,
    this.badge,
    this.onTap,
    this.enabled = true,
    this.selected = false,
    this.semanticLabel,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget? trailing;
  final Widget? badge;
  final VoidCallback? onTap;
  final bool enabled;
  final bool selected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color iconColor = enabled
        ? selected
            ? isDark
                ? MedColors.darkTextPrimary
                : MedColors.textPrimary
            : isDark
                ? MedColors.darkTextSecondary
                : MedColors.textSecondary
        : isDark
            ? MedColors.darkTextMuted
            : MedColors.disabled;

    final Widget resolvedTrailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (badge != null) badge!,
        if (badge != null && trailing != null)
          const SizedBox(width: MedSpacing.sm),
        if (trailing != null)
          trailing!
        else
          Icon(
            MedIcons.forward,
            size: MedIcons.medium,
            color: iconColor,
          ),
      ],
    );

    return MedListTile(
      title: title,
      subtitle: subtitle,
      enabled: enabled,
      selected: selected,
      variant:
          selected ? MedListTileVariant.filled : MedListTileVariant.standard,
      semanticLabel: semanticLabel,
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: selected
              ? isDark
                  ? MedColors.darkSurfaceElevated
                  : MedColors.surface
              : Colors.transparent,
          borderRadius: MedRadius.medium,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: MedIcons.large,
          color: iconColor,
        ),
      ),
      trailing: resolvedTrailing,
    );
  }
}
