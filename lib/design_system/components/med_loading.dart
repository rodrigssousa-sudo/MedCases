import 'package:flutter/material.dart';

import '../foundation/med_typography.dart';
import '../tokens/med_animation.dart';
import '../tokens/med_colors.dart';
import '../tokens/med_spacing.dart';

/// Variações oficiais do [MedLoading].
enum MedLoadingVariant {
  circular,
  linear,
}

/// Tamanhos oficiais do [MedLoading].
enum MedLoadingSize {
  small,
  medium,
  large,
}

/// Indicador de carregamento reutilizável oficial do MedCases Next.
class MedLoading extends StatelessWidget {
  const MedLoading({
    super.key,
    this.label,
    this.variant = MedLoadingVariant.circular,
    this.size = MedLoadingSize.medium,
    this.value,
    this.semanticLabel,
  }) : assert(
          value == null || (value >= 0 && value <= 1),
          'value deve estar entre 0 e 1.',
        );

  final String? label;
  final MedLoadingVariant variant;
  final MedLoadingSize size;
  final double? value;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color indicatorColor =
        isDark ? MedColors.darkTextPrimary : MedColors.primary;
    final Color trackColor =
        isDark ? MedColors.darkSurfaceSecondary : MedColors.surfaceSecondary;
    final Color labelColor =
        isDark ? MedColors.darkTextSecondary : MedColors.textSecondary;

    final Widget indicator = switch (variant) {
      MedLoadingVariant.circular => SizedBox(
          width: _diameter,
          height: _diameter,
          child: CircularProgressIndicator(
            value: value,
            strokeWidth: _strokeWidth,
            color: indicatorColor,
            backgroundColor: trackColor,
          ),
        ),
      MedLoadingVariant.linear => SizedBox(
          width: _linearWidth,
          child: LinearProgressIndicator(
            value: value,
            minHeight: _strokeWidth,
            color: indicatorColor,
            backgroundColor: trackColor,
            borderRadius: BorderRadius.circular(_strokeWidth),
          ),
        ),
    };

    return Semantics(
      container: true,
      label: semanticLabel ?? label ?? 'Carregando',
      value: value == null ? null : '${(value! * 100).round()}%',
      child: AnimatedSwitcher(
        duration: MedAnimation.fade,
        child: Column(
          key: ValueKey<String>(
            '${variant.name}-${size.name}-${value ?? 'indeterminate'}',
          ),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            indicator,
            if (label != null) ...<Widget>[
              const SizedBox(height: MedSpacing.md),
              Text(
                label!,
                textAlign: TextAlign.center,
                style: MedTypography.bodySmall.copyWith(
                  color: labelColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double get _diameter {
    switch (size) {
      case MedLoadingSize.small:
        return 20;
      case MedLoadingSize.medium:
        return 32;
      case MedLoadingSize.large:
        return 48;
    }
  }

  double get _strokeWidth {
    switch (size) {
      case MedLoadingSize.small:
        return 2;
      case MedLoadingSize.medium:
        return 3;
      case MedLoadingSize.large:
        return 4;
    }
  }

  double get _linearWidth {
    switch (size) {
      case MedLoadingSize.small:
        return 120;
      case MedLoadingSize.medium:
        return 200;
      case MedLoadingSize.large:
        return 280;
    }
  }
}
