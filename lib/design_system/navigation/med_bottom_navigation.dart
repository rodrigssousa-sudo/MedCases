import 'package:flutter/material.dart';

import '../tokens/med_colors.dart';
import '../tokens/med_elevation.dart';
import '../tokens/med_spacing.dart';
import '../components/med_navigation_tile.dart';
import 'med_navigation_destination.dart';

/// Navegação inferior oficial do MedCases Next.
class MedBottomNavigation extends StatelessWidget {
  const MedBottomNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
    this.semanticLabel = 'Navegação principal',
  }) : assert(destinations.length >= 2);

  final List<MedNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          border: Border(
            top: BorderSide(color: border),
          ),
          boxShadow: MedElevation.small,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MedSpacing.sm,
              vertical: MedSpacing.xs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List<Widget>.generate(
                destinations.length,
                (index) {
                  final destination = destinations[index];

                  return Expanded(
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
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
