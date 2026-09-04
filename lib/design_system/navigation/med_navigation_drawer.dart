import 'package:flutter/material.dart';

import '../components/med_icon_button.dart';
import '../components/med_navigation_tile.dart';
import '../tokens/med_colors.dart';
import '../tokens/med_icons.dart';
import '../tokens/med_spacing.dart';
import 'med_navigation_destination.dart';

/// Drawer de navegação oficial do MedCases Next.
class MedNavigationDrawer extends StatelessWidget {
  const MedNavigationDrawer({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
    this.header,
    this.footer,
    this.showCloseButton = true,
    this.semanticLabel = 'Menu de navegação',
  }) : assert(destinations.length >= 2);

  final List<MedNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget? header;
  final Widget? footer;
  final bool showCloseButton;
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
      child: Drawer(
        backgroundColor: background,
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MedSpacing.lg,
                  MedSpacing.lg,
                  MedSpacing.sm,
                  MedSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    if (header != null) Expanded(child: header!),
                    if (header == null) const Spacer(),
                    if (showCloseButton)
                      MedIconButton(
                        icon: MedIcons.close,
                        tooltip: 'Fechar menu',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                  ],
                ),
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

                    return MedNavigationTile(
                      label: destination.label,
                      icon: destination.icon,
                      selectedIcon: destination.selectedIcon,
                      selected: selectedIndex == index,
                      orientation: MedNavigationTileOrientation.horizontal,
                      badgeLabel: destination.badgeLabel,
                      semanticLabel:
                          destination.semanticLabel ?? destination.label,
                      onTap: () {
                        Navigator.of(context).pop();
                        onDestinationSelected(index);
                      },
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
