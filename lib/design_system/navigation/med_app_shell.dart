import 'package:flutter/material.dart';

import '../components/med_toolbar.dart';
import '../layout/med_responsive_builder.dart';
import '../tokens/med_breakpoints.dart';
import '../tokens/med_colors.dart';
import 'med_bottom_navigation.dart';
import 'med_navigation_destination.dart';
import 'med_navigation_drawer.dart';
import 'med_side_navigation.dart';

/// Estratégias oficiais de navegação do [MedAppShell].
enum MedAppShellNavigationMode {
  automatic,
  bottom,
  drawer,
  side,
}

/// Shell adaptativo oficial da plataforma MedCases Next.
class MedAppShell extends StatelessWidget {
  const MedAppShell({
    required this.body,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
    this.toolbar,
    this.navigationHeader,
    this.navigationFooter,
    this.floatingActionButton,
    this.mode = MedAppShellNavigationMode.automatic,
    this.sideNavigationExpanded = true,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
  }) : assert(destinations.length >= 2);

  final Widget body;
  final List<MedNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final MedToolbar? toolbar;
  final Widget? navigationHeader;
  final Widget? navigationFooter;
  final Widget? floatingActionButton;
  final MedAppShellNavigationMode mode;
  final bool sideNavigationExpanded;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return MedResponsiveBuilder(
      builder: (context, windowClass, constraints) {
        final MedAppShellNavigationMode resolvedMode =
            _resolveMode(windowClass);

        return switch (resolvedMode) {
          MedAppShellNavigationMode.bottom => _buildBottomShell(context),
          MedAppShellNavigationMode.drawer => _buildDrawerShell(context),
          MedAppShellNavigationMode.side => _buildSideShell(context),
          MedAppShellNavigationMode.automatic =>
            throw StateError('Modo automático deve ser resolvido antes.'),
        };
      },
    );
  }

  Widget _buildBottomShell(BuildContext context) {
    return Scaffold(
      backgroundColor: _resolveBackground(context),
      appBar: toolbar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      body: body,
      bottomNavigationBar: MedBottomNavigation(
        destinations: destinations,
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
      ),
    );
  }

  Widget _buildDrawerShell(BuildContext context) {
    return Scaffold(
      backgroundColor: _resolveBackground(context),
      appBar: toolbar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      drawer: MedNavigationDrawer(
        destinations: destinations,
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        header: navigationHeader,
        footer: navigationFooter,
      ),
      body: body,
    );
  }

  Widget _buildSideShell(BuildContext context) {
    return Scaffold(
      backgroundColor: _resolveBackground(context),
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      body: Row(
        children: <Widget>[
          MedSideNavigation(
            destinations: destinations,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            header: navigationHeader,
            footer: navigationFooter,
            expanded: sideNavigationExpanded,
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                if (toolbar != null) toolbar!,
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  MedAppShellNavigationMode _resolveMode(MedWindowClass windowClass) {
    if (mode != MedAppShellNavigationMode.automatic) {
      return mode;
    }

    switch (windowClass) {
      case MedWindowClass.mobile:
        return MedAppShellNavigationMode.bottom;
      case MedWindowClass.tablet:
        return MedAppShellNavigationMode.drawer;
      case MedWindowClass.desktop:
      case MedWindowClass.wideDesktop:
        return MedAppShellNavigationMode.side;
    }
  }

  Color _resolveBackground(BuildContext context) {
    if (backgroundColor != null) {
      return backgroundColor!;
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? MedColors.darkBackground : MedColors.background;
  }
}
