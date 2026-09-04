import 'package:flutter/widgets.dart';

import '../tokens/med_breakpoints.dart';
import '../tokens/med_spacing.dart';
import 'med_responsive_builder.dart';

/// Larguras máximas oficiais de conteúdo do MedCases Next.
abstract final class MedContentWidth {
  static const double compact = 640;
  static const double standard = 960;
  static const double expanded = 1200;
  static const double wide = 1440;
}

/// Área centralizada de conteúdo do MedCases Next.
class MedContentLayout extends StatelessWidget {
  const MedContentLayout({
    required this.child,
    super.key,
    this.maxWidth,
    this.alignment = Alignment.topCenter,
    this.padding,
  });

  final Widget child;
  final double? maxWidth;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return MedResponsiveBuilder(
      builder: (context, windowClass, constraints) {
        final EdgeInsetsGeometry resolvedPadding =
            padding ?? _resolvePadding(windowClass);
        final double resolvedMaxWidth =
            maxWidth ?? _resolveMaxWidth(windowClass);

        return Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: resolvedMaxWidth,
            ),
            child: Padding(
              padding: resolvedPadding,
              child: child,
            ),
          ),
        );
      },
    );
  }

  EdgeInsetsGeometry _resolvePadding(MedWindowClass windowClass) {
    switch (windowClass) {
      case MedWindowClass.mobile:
        return MedSpacing.pageMobile;
      case MedWindowClass.tablet:
        return MedSpacing.pageTablet;
      case MedWindowClass.desktop:
      case MedWindowClass.wideDesktop:
        return MedSpacing.pageDesktop;
    }
  }

  double _resolveMaxWidth(MedWindowClass windowClass) {
    switch (windowClass) {
      case MedWindowClass.mobile:
        return double.infinity;
      case MedWindowClass.tablet:
        return MedContentWidth.compact;
      case MedWindowClass.desktop:
        return MedContentWidth.standard;
      case MedWindowClass.wideDesktop:
        return MedContentWidth.expanded;
    }
  }
}
