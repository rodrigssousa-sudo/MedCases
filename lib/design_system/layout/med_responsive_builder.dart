import 'package:flutter/widgets.dart';

import '../tokens/med_breakpoints.dart';

/// Assinatura oficial para construção responsiva do MedCases Next.
typedef MedResponsiveWidgetBuilder = Widget Function(
  BuildContext context,
  MedWindowClass windowClass,
  BoxConstraints constraints,
);

/// Construtor responsivo centralizado do MedCases Next.
///
/// Resolve a classe de janela exclusivamente através de [MedBreakpoints].
class MedResponsiveBuilder extends StatelessWidget {
  const MedResponsiveBuilder({
    required this.builder,
    super.key,
  });

  final MedResponsiveWidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        return builder(
          context,
          MedBreakpoints.resolve(width),
          constraints,
        );
      },
    );
  }
}
