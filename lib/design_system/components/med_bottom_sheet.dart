import 'package:flutter/material.dart';

import '../foundation/med_typography.dart';
import '../tokens/med_colors.dart';
import '../tokens/med_elevation.dart';
import '../tokens/med_icons.dart';
import '../tokens/med_radius.dart';
import '../tokens/med_spacing.dart';
import 'med_icon_button.dart';

/// Bottom sheet reutilizável oficial do MedCases Next.
class MedBottomSheet extends StatelessWidget {
  const MedBottomSheet({
    required this.child,
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.actions = const <Widget>[],
    this.footer,
    this.showHandle = true,
    this.showCloseButton = true,
    this.onClose,
    this.padding = const EdgeInsets.fromLTRB(
      MedSpacing.lg,
      MedSpacing.md,
      MedSpacing.lg,
      MedSpacing.xl,
    ),
    this.semanticLabel,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? footer;
  final bool showHandle;
  final bool showCloseButton;
  final VoidCallback? onClose;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surface =
        isDark ? MedColors.darkSurfaceElevated : MedColors.surfaceElevated;
    final Color border = isDark ? MedColors.darkBorder : MedColors.border;
    final Color titleColor =
        isDark ? MedColors.darkTextPrimary : MedColors.textPrimary;
    final Color subtitleColor =
        isDark ? MedColors.darkTextSecondary : MedColors.textSecondary;
    final Color handleColor =
        isDark ? MedColors.darkBorderStrong : MedColors.borderStrong;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      scopesRoute: true,
      namesRoute: true,
      label: semanticLabel ?? title,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(MedRadius.xLargeValue),
            ),
            border: Border(
              top: BorderSide(color: border),
            ),
            boxShadow: MedElevation.overlay,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (showHandle)
                Padding(
                  padding: const EdgeInsets.only(
                    top: MedSpacing.sm,
                    bottom: MedSpacing.sm,
                  ),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: handleColor,
                      borderRadius: MedRadius.pill,
                    ),
                  ),
                ),
              if (_hasHeader)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    MedSpacing.lg,
                    showHandle ? MedSpacing.sm : MedSpacing.lg,
                    MedSpacing.md,
                    MedSpacing.md,
                  ),
                  child: Row(
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
                                style: MedTypography.titleMedium.copyWith(
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
                      if (actions.isNotEmpty) ...<Widget>[
                        const SizedBox(width: MedSpacing.sm),
                        Wrap(
                          spacing: MedSpacing.sm,
                          children: actions,
                        ),
                      ],
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
                ),
              Flexible(
                child: SingleChildScrollView(
                  padding: padding,
                  child: child,
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

  bool get _hasHeader {
    return title != null ||
        subtitle != null ||
        leading != null ||
        actions.isNotEmpty ||
        showCloseButton;
  }

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    String? subtitle,
    Widget? leading,
    List<Widget> actions = const <Widget>[],
    Widget? footer,
    bool isDismissible = true,
    bool enableDrag = true,
    bool useSafeArea = true,
    bool showHandle = true,
    bool showCloseButton = true,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(
      MedSpacing.lg,
      MedSpacing.md,
      MedSpacing.lg,
      MedSpacing.xl,
    ),
    String? semanticLabel,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: useSafeArea,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: MedBottomSheet(
            title: title,
            subtitle: subtitle,
            leading: leading,
            actions: actions,
            footer: footer,
            showHandle: showHandle,
            showCloseButton: showCloseButton,
            onClose: () => Navigator.of(sheetContext).pop(),
            padding: padding,
            semanticLabel: semanticLabel,
            child: child,
          ),
        );
      },
    );
  }
}
