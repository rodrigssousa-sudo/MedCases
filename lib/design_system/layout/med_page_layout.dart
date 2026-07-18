import 'package:flutter/material.dart';

import '../tokens/med_colors.dart';
import '../tokens/med_spacing.dart';
import 'med_content_layout.dart';
import 'med_safe_area.dart';

/// Layout-base oficial de página do MedCases Next.
class MedPageLayout extends StatelessWidget {
  const MedPageLayout({
    required this.child,
    super.key,
    this.header,
    this.footer,
    this.floatingActionButton,
    this.backgroundColor,
    this.useSafeArea = true,
    this.resizeToAvoidBottomInset = true,
    this.extendBodyBehindHeader = false,
    this.centerContent = true,
    this.contentMaxWidth,
    this.contentPadding,
  });

  final Widget child;
  final PreferredSizeWidget? header;
  final Widget? footer;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool useSafeArea;
  final bool resizeToAvoidBottomInset;
  final bool extendBodyBehindHeader;
  final bool centerContent;
  final double? contentMaxWidth;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color resolvedBackground = backgroundColor ??
        (isDark ? MedColors.darkBackground : MedColors.background);

    Widget content = centerContent
        ? MedContentLayout(
            maxWidth: contentMaxWidth,
            padding: contentPadding,
            child: child,
          )
        : Padding(
            padding: contentPadding ?? EdgeInsets.zero,
            child: child,
          );

    if (useSafeArea) {
      content = MedSafeArea(
        top: header == null || extendBodyBehindHeader,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: resolvedBackground,
      appBar: header,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBodyBehindAppBar: extendBodyBehindHeader,
      floatingActionButton: floatingActionButton,
      body: Column(
        children: <Widget>[
          Expanded(child: content),
          if (footer != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: MedSpacing.lg,
                  right: MedSpacing.lg,
                  bottom: MedSpacing.lg,
                ),
                child: footer,
              ),
            ),
        ],
      ),
    );
  }
}
