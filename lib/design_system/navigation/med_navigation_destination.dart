import 'package:flutter/widgets.dart';

/// Destino de navegação imutável oficial do MedCases Next.
class MedNavigationDestination {
  const MedNavigationDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badgeLabel,
    this.semanticLabel,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String? badgeLabel;
  final String? semanticLabel;
}
