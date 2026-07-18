import 'package:flutter/material.dart';

import '../components/med_avatar.dart';
import '../components/med_navigation_tile.dart';
import '../foundation/med_typography.dart';
import '../tokens/med_colors.dart';
import '../tokens/med_elevation.dart';
import '../tokens/med_spacing.dart';
import 'med_navigation_destination.dart';

/// Navegação lateral oficial do MedCases Next.
class MedSideNavigation extends StatelessWidget {
  const MedSideNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
    this.header,
    this.footer,
    this.expanded = true,
    this.width = 256,
    this.collapsedWidth = 88,
    this.semanticLabel = 'Navegação principal',
  }) : assert(destinations.length >= 2);

  final List<MedNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget? header;
  final Widget? footer;
  final bool expanded;
  final double width;
  final double collapsedWidth;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    assert(
      selectedIndex >= 0 && selectedIndex < destinations.length,
      'selectedIndex deve apontar para um destino existente.',
    );

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color background = isDark ? MedColors.darkSurface : MedColors.surface;
    final Color border = isDark ? MedColors.darkDivider : MedColors.divider;

    return Semantics(
      container: true,
      label: semanticLabel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: expanded ? width : collapsedWidth,
        decoration: BoxDecoration(
          color: background,
          border: Border(
            right: BorderSide(color: border),
          ),
          boxShadow: MedElevation.small,
        ),
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (header != null)
                Padding(
                  padding: const EdgeInsets.all(MedSpacing.lg),
                  child: header,
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MedSpacing.sm,
                    vertical: MedSpacing.md,
                  ),
                  itemCount: destinations.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: MedSpacing.xs),
                  itemBuilder: (context, index) {
                    final destination = destinations[index];

                    if (!expanded) {
                      return Tooltip(
                        message: destination.label,
                        child: MedNavigationTile(
                          label: destination.label,
                          icon: destination.icon,
                          selectedIcon: destination.selectedIcon,
                          selected: selectedIndex == index,
                          orientation: MedNavigationTileOrientation.vertical,
                          badgeLabel: destination.badgeLabel,
                          semanticLabel:
                              destination.semanticLabel ?? destination.label,
                          onTap: () => onDestinationSelected(index),
                        ),
                      );
                    }

                    return MedNavigationTile(
                      label: destination.label,
                      icon: destination.icon,
                      selectedIcon: destination.selectedIcon,
                      selected: selectedIndex == index,
                      orientation: MedNavigationTileOrientation.horizontal,
                      badgeLabel: destination.badgeLabel,
                      semanticLabel:
                          destination.semanticLabel ?? destination.label,
                      onTap: () => onDestinationSelected(index),
                    );
                  },
                ),
              ),
              if (footer != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: border),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(MedSpacing.lg),
                    child: footer,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho-padrão opcional para [MedSideNavigation].
class MedSideNavigationHeader extends StatelessWidget {
  const MedSideNavigationHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.avatar,
    this.expanded = true,
  });

  final String title;
  final String? subtitle;
  final Widget? avatar;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primary =
        isDark ? MedColors.darkTextPrimary : MedColors.textPrimary;
    final Color secondary =
        isDark ? MedColors.darkTextSecondary : MedColors.textSecondary;

    return Row(
      children: <Widget>[
        avatar ?? const MedAvatar(initials: 'M+'),
        if (expanded) ...<Widget>[
          const SizedBox(width: MedSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MedTypography.cardTitle.copyWith(
                    color: primary,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: MedSpacing.xs),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MedTypography.caption.copyWith(
                      color: secondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
