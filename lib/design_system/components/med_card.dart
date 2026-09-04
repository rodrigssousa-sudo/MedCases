import 'package:flutter/material.dart';

import '../tokens/med_colors.dart';
import '../tokens/med_elevation.dart';
import '../tokens/med_radius.dart';
import '../tokens/med_spacing.dart';

/// Variações visuais oficiais do [MedCard].
enum MedCardVariant {
  standard,
  secondary,
  elevated,
  outlined,
}

/// Card reutilizável oficial do MedCases Next.
class MedCard extends StatelessWidget {
  const MedCard({
    required this.child,
    super.key,
    this.variant = MedCardVariant.standard,
    this.padding = MedSpacing.card,
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.semanticLabel,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final MedCardVariant variant;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final _MedCardVisual visual = _resolveVisual(context);

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: visual.backgroundColor,
        borderRadius: MedRadius.large,
        border: visual.border,
        boxShadow: visual.shadows,
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: MedRadius.large,
          child: content,
        ),
      );
    }

    content = Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      child: content,
    );

    return Padding(
      padding: margin,
      child: content,
    );
  }

  _MedCardVisual _resolveVisual(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    switch (variant) {
      case MedCardVariant.standard:
        return _MedCardVisual(
          backgroundColor: isDark ? MedColors.darkSurface : MedColors.surface,
          border: null,
          shadows: MedElevation.none,
        );
      case MedCardVariant.secondary:
        return _MedCardVisual(
          backgroundColor: isDark
              ? MedColors.darkSurfaceSecondary
              : MedColors.surfaceSecondary,
          border: null,
          shadows: MedElevation.none,
        );
      case MedCardVariant.elevated:
        return _MedCardVisual(
          backgroundColor: isDark
              ? MedColors.darkSurfaceElevated
              : MedColors.surfaceElevated,
          border: null,
          shadows: MedElevation.medium,
        );
      case MedCardVariant.outlined:
        return _MedCardVisual(
          backgroundColor: isDark ? MedColors.darkSurface : MedColors.surface,
          border: Border.all(
            color: isDark ? MedColors.darkBorder : MedColors.border,
          ),
          shadows: MedElevation.none,
        );
    }
  }
}

class _MedCardVisual {
  const _MedCardVisual({
    required this.backgroundColor,
    required this.border,
    required this.shadows,
  });

  final Color backgroundColor;
  final BoxBorder? border;
  final List<BoxShadow> shadows;
}
