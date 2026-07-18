import 'package:flutter/material.dart';

import '../foundation/med_typography.dart';
import '../tokens/med_colors.dart';
import '../tokens/med_icons.dart';
import '../tokens/med_radius.dart';
import '../tokens/med_spacing.dart';
import 'med_button.dart';
import 'med_icon_button.dart';

/// Variações semânticas oficiais do [MedDialog].
enum MedDialogVariant {
  neutral,
  information,
  success,
  warning,
  destructive,
}

/// Diálogo reutilizável oficial do MedCases Next.
class MedDialog extends StatelessWidget {
  const MedDialog({
    required this.title,
    required this.content,
    super.key,
    this.variant = MedDialogVariant.neutral,
    this.icon,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.showCloseButton = true,
    this.onClose,
    this.semanticLabel,
  });

  final String title;
  final Widget content;
  final MedDialogVariant variant;
  final IconData? icon;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool showCloseButton;
  final VoidCallback? onClose;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surface =
        isDark ? MedColors.darkSurfaceElevated : MedColors.surfaceElevated;
    final Color titleColor =
        isDark ? MedColors.darkTextPrimary : MedColors.textPrimary;
    final Color accent = _resolveAccentColor();

    return Semantics(
      container: true,
      explicitChildNodes: true,
      scopesRoute: true,
      namesRoute: true,
      label: semanticLabel ?? title,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(MedSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 280,
            maxWidth: 520,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: MedRadius.xLarge,
              border: Border.all(
                color: isDark ? MedColors.darkBorder : MedColors.border,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(MedSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (icon != null || variant != MedDialogVariant.neutral)
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: MedRadius.circle(40),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            icon ?? _resolveDefaultIcon(),
                            size: 22,
                            color: accent,
                          ),
                        ),
                      if (icon != null || variant != MedDialogVariant.neutral)
                        const SizedBox(width: MedSpacing.md),
                      Expanded(
                        child: Text(
                          title,
                          style: MedTypography.titleMedium.copyWith(
                            color: titleColor,
                          ),
                        ),
                      ),
                      if (showCloseButton) ...<Widget>[
                        const SizedBox(width: MedSpacing.sm),
                        MedIconButton(
                          icon: MedIcons.close,
                          tooltip: 'Fechar',
                          size: MedIconButtonSize.small,
                          onPressed:
                              onClose ?? () => Navigator.of(context).pop(),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: MedSpacing.lg),
                  DefaultTextStyle(
                    style: MedTypography.bodyMedium.copyWith(
                      color: isDark
                          ? MedColors.darkTextSecondary
                          : MedColors.textSecondary,
                    ),
                    child: content,
                  ),
                  if (_hasActions) ...<Widget>[
                    const SizedBox(height: MedSpacing.xl),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: MedSpacing.sm,
                      runSpacing: MedSpacing.sm,
                      children: <Widget>[
                        if (secondaryActionLabel != null &&
                            onSecondaryAction != null)
                          MedButton(
                            label: secondaryActionLabel!,
                            variant: MedButtonVariant.ghost,
                            onPressed: onSecondaryAction,
                          ),
                        if (primaryActionLabel != null &&
                            onPrimaryAction != null)
                          MedButton(
                            label: primaryActionLabel!,
                            variant: variant == MedDialogVariant.destructive
                                ? MedButtonVariant.destructive
                                : MedButtonVariant.primary,
                            onPressed: onPrimaryAction,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasActions {
    return (primaryActionLabel != null && onPrimaryAction != null) ||
        (secondaryActionLabel != null && onSecondaryAction != null);
  }

  Color _resolveAccentColor() {
    switch (variant) {
      case MedDialogVariant.neutral:
        return MedColors.primary;
      case MedDialogVariant.information:
        return MedColors.information;
      case MedDialogVariant.success:
        return MedColors.success;
      case MedDialogVariant.warning:
        return MedColors.warning;
      case MedDialogVariant.destructive:
        return MedColors.error;
    }
  }

  IconData _resolveDefaultIcon() {
    switch (variant) {
      case MedDialogVariant.neutral:
        return MedIcons.information;
      case MedDialogVariant.information:
        return MedIcons.information;
      case MedDialogVariant.success:
        return MedIcons.success;
      case MedDialogVariant.warning:
        return MedIcons.warning;
      case MedDialogVariant.destructive:
        return MedIcons.error;
    }
  }

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    MedDialogVariant variant = MedDialogVariant.neutral,
    IconData? icon,
    String? primaryActionLabel,
    VoidCallback? onPrimaryAction,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryAction,
    bool barrierDismissible = true,
    bool showCloseButton = true,
    String? semanticLabel,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) {
        return MedDialog(
          title: title,
          content: content,
          variant: variant,
          icon: icon,
          primaryActionLabel: primaryActionLabel,
          onPrimaryAction: onPrimaryAction,
          secondaryActionLabel: secondaryActionLabel,
          onSecondaryAction: onSecondaryAction,
          showCloseButton: showCloseButton,
          semanticLabel: semanticLabel,
          onClose: () => Navigator.of(dialogContext).pop(),
        );
      },
    );
  }
}
