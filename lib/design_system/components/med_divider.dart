import 'package:flutter/material.dart';

import '../tokens/med_colors.dart';
import '../tokens/med_spacing.dart';

/// Orientações oficiais do [MedDivider].
enum MedDividerOrientation {
  horizontal,
  vertical,
}

/// Divisor reutilizável oficial do MedCases Next.
class MedDivider extends StatelessWidget {
  const MedDivider({
    super.key,
    this.orientation = MedDividerOrientation.horizontal,
    this.indent = MedSpacing.none,
    this.endIndent = MedSpacing.none,
    this.thickness = 1,
  });

  final MedDividerOrientation orientation;
  final double indent;
  final double endIndent;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color color = isDark ? MedColors.darkDivider : MedColors.divider;

    switch (orientation) {
      case MedDividerOrientation.horizontal:
        return Divider(
          color: color,
          thickness: thickness,
          height: thickness,
          indent: indent,
          endIndent: endIndent,
        );
      case MedDividerOrientation.vertical:
        return VerticalDivider(
          color: color,
          thickness: thickness,
          width: thickness,
          indent: indent,
          endIndent: endIndent,
        );
    }
  }
}
