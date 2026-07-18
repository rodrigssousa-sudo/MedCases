import 'package:flutter/material.dart';

import '../foundation/med_typography.dart';
import '../tokens/med_colors.dart';
import '../tokens/med_elevation.dart';
import '../tokens/med_icons.dart';
import '../tokens/med_radius.dart';
import '../tokens/med_spacing.dart';
import 'med_icon_button.dart';

/// Modal estrutural reutilizável oficial do MedCases Next.
class MedModal extends StatelessWidget {
  const MedModal({
    required this.child,
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.actions = const <Widget>[],
    this.footer,
    this.showCloseButton = true,
    this.onClose,
    this.maxWidth = 720,
    this.maxHeightFactor = 0.9,
    this.padding = const EdgeInsets.all(MedSpacing.xl),
    this.semanticLabel,
  }) : assert(
          maxHeightFactor > 0 && maxHeightFactor <= 1,
          'maxHeightFactor deve estar entre 0 e 1.',
        );

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? footer;
  final bool showCloseButton;
  final VoidCallback? onClose;
  final double maxWidth;
  final double maxHeightFactor;
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
    final double maxHeight =
        MediaQuery.sizeOf(context).height * maxHeightFactor;

    return Semantics(
      container: true,
      scopesRoute: true,
      namesRoute: true,
      label: semanticLabel ?? title,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(MedSpacing.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: 320,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: MedRadius.xLarge,
              border: Border.all(color: border),
              boxShadow: MedElevation.overlay,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_hasHeader)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      MedSpacing.xl,
                      MedSpacing.xl,
                      MedSpacing.lg,
                      MedSpacing.lg,
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
                                  style: MedTypography.titleLarge.copyWith(
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
                          const SizedBox(width: MedSpacing.md),
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
    bool barrierDismissible = true,
    bool showCloseButton = true,
    double maxWidth = 720,
    double maxHeightFactor = 0.9,
    EdgeInsetsGeometry padding = const EdgeInsets.all(MedSpacing.xl),
    String? semanticLabel,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (modalContext) {
        return MedModal(
          title: title,
          subtitle: subtitle,
          leading: leading,
          actions: actions,
          footer: footer,
          showCloseButton: showCloseButton,
          onClose: () => Navigator.of(modalContext).pop(),
          maxWidth: maxWidth,
          maxHeightFactor: maxHeightFactor,
          padding: padding,
          semanticLabel: semanticLabel,
          child: child,
        );
      },
    );
  }
}
