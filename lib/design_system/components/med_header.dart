import 'package:flutter/material.dart';

import '../foundation/med_typography.dart';
import '../tokens/med_colors.dart';
import '../tokens/med_spacing.dart';

/// Tamanhos oficiais do [MedHeader].
enum MedHeaderSize {
  medium,
  large,
  display,
}

/// Cabeçalho reutilizável oficial do MedCases Next.
class MedHeader extends StatelessWidget {
  const MedHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.eyebrow,
    this.leading,
    this.actions = const <Widget>[],
    this.size = MedHeaderSize.large,
    this.padding = EdgeInsets.zero,
    this.semanticLabel,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget? leading;
  final List<Widget> actions;
  final MedHeaderSize size;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor =
        isDark ? MedColors.darkTextPrimary : MedColors.textPrimary;
    final Color secondaryColor =
        isDark ? MedColors.darkTextSecondary : MedColors.textSecondary;
    final TextStyle titleStyle = _resolveTitleStyle().copyWith(
      color: primaryColor,
    );

    return Semantics(
      container: true,
      header: true,
      label: semanticLabel ?? title,
      child: Padding(
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (leading != null) ...<Widget>[
              leading!,
              const SizedBox(width: MedSpacing.lg),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (eyebrow != null) ...<Widget>[
                    Text(
                      eyebrow!,
                      style: MedTypography.overline.copyWith(
                        color: secondaryColor,
                      ),
                    ),
                    const SizedBox(height: MedSpacing.xs),
                  ],
                  Text(
                    title,
                    style: titleStyle,
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: MedSpacing.sm),
                    Text(
                      subtitle!,
                      style: MedTypography.bodyMedium.copyWith(
                        color: secondaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (actions.isNotEmpty) ...<Widget>[
              const SizedBox(width: MedSpacing.lg),
              Wrap(
                spacing: MedSpacing.sm,
                runSpacing: MedSpacing.sm,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }

  TextStyle _resolveTitleStyle() {
    switch (size) {
      case MedHeaderSize.medium:
        return MedTypography.titleMedium;
      case MedHeaderSize.large:
        return MedTypography.titleXL;
      case MedHeaderSize.display:
        return MedTypography.displayMedium;
    }
  }
}
