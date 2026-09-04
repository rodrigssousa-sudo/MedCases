import 'package:flutter/widgets.dart';

import '../tokens/med_breakpoints.dart';
import '../tokens/med_spacing.dart';
import 'med_responsive_builder.dart';

/// Configuração responsiva oficial do [MedGrid].
class MedGridColumns {
  const MedGridColumns({
    this.mobile = 1,
    this.tablet = 2,
    this.desktop = 3,
    this.wideDesktop = 4,
  })  : assert(mobile > 0),
        assert(tablet > 0),
        assert(desktop > 0),
        assert(wideDesktop > 0);

  final int mobile;
  final int tablet;
  final int desktop;
  final int wideDesktop;

  int resolve(MedWindowClass windowClass) {
    switch (windowClass) {
      case MedWindowClass.mobile:
        return mobile;
      case MedWindowClass.tablet:
        return tablet;
      case MedWindowClass.desktop:
        return desktop;
      case MedWindowClass.wideDesktop:
        return wideDesktop;
    }
  }
}

/// Grid responsivo reutilizável oficial do MedCases Next.
class MedGrid extends StatelessWidget {
  const MedGrid({
    required this.children,
    super.key,
    this.columns = const MedGridColumns(),
    this.horizontalSpacing = MedSpacing.lg,
    this.verticalSpacing = MedSpacing.lg,
    this.childAspectRatio = 1,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;
  final MedGridColumns columns;
  final double horizontalSpacing;
  final double verticalSpacing;
  final double childAspectRatio;
  final bool shrinkWrap;
  final ScrollPhysics physics;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return MedResponsiveBuilder(
      builder: (context, windowClass, constraints) {
        return GridView.builder(
          padding: padding,
          shrinkWrap: shrinkWrap,
          physics: physics,
          itemCount: children.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns.resolve(windowClass),
            crossAxisSpacing: horizontalSpacing,
            mainAxisSpacing: verticalSpacing,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}
