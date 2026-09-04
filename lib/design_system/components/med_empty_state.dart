import 'package:flutter/material.dart';

import '../foundation/med_typography.dart';
import '../tokens/med_colors.dart';
import '../tokens/med_icons.dart';
import '../tokens/med_radius.dart';
import '../tokens/med_spacing.dart';
import 'med_button.dart';

/// Estado vazio reutilizável oficial do MedCases Next.
class MedEmptyState extends StatelessWidget {
  const MedEmptyState({
    required this.title,
    required this.message,
    super.key,
    this.icon = MedIcons.information,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.compact = false,
    this.semanticLabel,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool compact;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor =
        isDark ? MedColors.darkTextPrimary : MedColors.textPrimary;
    final Color messageColor =
        isDark ? MedColors.darkTextSecondary : MedColors.textSecondary;
    final Color iconBackground =
        isDark ? MedColors.darkSurfaceSecondary : MedColors.surfaceSecondary;
    final Color iconColor =
        isDark ? MedColors.darkTextSecondary : MedColors.textSecondary;

    final double iconContainerSize = compact ? 48 : 64;
    final double iconSize = compact ? MedIcons.large : MedIcons.xLarge;

    return Semantics(
      container: true,
      label: semanticLabel ?? '$title. $message',
      child: Padding(
        padding: EdgeInsets.all(
          compact ? MedSpacing.lg : MedSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: iconContainerSize,
              height: iconContainerSize,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: MedRadius.circle(iconContainerSize),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: iconSize,
                color: iconColor,
              ),
            ),
            SizedBox(
              height: compact ? MedSpacing.md : MedSpacing.lg,
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: MedTypography.titleMedium.copyWith(
                color: titleColor,
              ),
            ),
            const SizedBox(height: MedSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: MedTypography.bodyMedium.copyWith(
                color: messageColor,
              ),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              SizedBox(
                height: compact ? MedSpacing.lg : MedSpacing.xl,
              ),
              MedButton(
                label: actionLabel!,
                onPressed: onAction,
                size: compact ? MedButtonSize.small : MedButtonSize.medium,
              ),
            ],
            if (secondaryActionLabel != null &&
                onSecondaryAction != null) ...<Widget>[
              const SizedBox(height: MedSpacing.sm),
              MedButton(
                label: secondaryActionLabel!,
                onPressed: onSecondaryAction,
                variant: MedButtonVariant.ghost,
                size: compact ? MedButtonSize.small : MedButtonSize.medium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
