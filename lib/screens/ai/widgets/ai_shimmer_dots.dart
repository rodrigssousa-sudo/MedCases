import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../home_v2/theme/home_v2_palette.dart';

/// Indicador de espera único da IA.
///
/// Mantém o nome público legado para preservar os call sites, mas apresenta
/// somente três pontos verdes discretos. A animação fica isolada no próprio
/// widget e não altera estado, streaming ou conteúdo da resposta.
class AiShimmerDots extends StatefulWidget {
  const AiShimmerDots({
    super.key,
    required this.dark,
  });

  final bool dark;

  @override
  State<AiShimmerDots> createState() => _AiShimmerDotsState();
}

class _AiShimmerDotsState extends State<AiShimmerDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = HomeV2Palette.resolve(widget.dark);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List<Widget>.generate(
              3,
              (index) {
                final phase =
                    (_controller.value * 2 * math.pi) - (index * 0.72);
                final opacity =
                    0.32 + (((math.sin(phase) + 1) / 2) * 0.68);

                return Padding(
                  padding: EdgeInsets.only(
                    right: index == 2 ? 0 : 4,
                  ),
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0).toDouble(),
                    child: Container(
                      key: ValueKey<String>('ai-loading-dot-$index'),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: palette.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
              growable: false,
            ),
          );
        },
      ),
    );
  }
}
