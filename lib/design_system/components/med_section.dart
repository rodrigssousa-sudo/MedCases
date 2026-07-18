import 'package:flutter/material.dart';

import '../foundation/med_typography.dart';
import '../tokens/med_colors.dart';
import '../tokens/med_spacing.dart';

/// Seção estrutural reutilizável oficial do MedCases Next.
class MedSection extends StatelessWidget {
  const MedSection({
    required this.child,
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.padding = EdgeInsets.zero,
    this.contentSpacing = MedSpacing.md,
    this.semanticLabel,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final double contentSpacing;
  final String? semanticLabel;

  bool get _hasHeader =>
      title != null || subtitle != null || leading != null || trailing != null;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor =
        isDark ? MedColors.darkTextPrimary : MedColors.textPrimary;
    final Color subtitleColor =
        isDark ? MedColors.darkTextSecondary : MedColors.textSecondary;

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_hasHeader) ...<Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (leading != null) ...<Widget>[
                leading!,
                const SizedBox(width: MedSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (title != null)
                      Text(
                        title!,
                        style: MedTypography.sectionTitle.copyWith(
                          color: titleColor,
                        ),
                      ),
                    if (title != null && subtitle != null)
                      const SizedBox(height: MedSpacing.xs),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: MedTypography.bodySmall.copyWith(
                          color: subtitleColor,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: MedSpacing.md),
                trailing!,
              ],
            ],
          ),
          SizedBox(height: contentSpacing),
        ],
        child,
      ],
    );

    return Semantics(
      container: true,
      label: semanticLabel ?? title,
      child: Padding(
        padding: padding,
        child: content,
      ),
    );
  }
}
