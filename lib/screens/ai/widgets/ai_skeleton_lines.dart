import 'package:flutter/material.dart';

// AiSkeletonLines — BUILD 462-STREAMING-CORE
//
// Skeleton screen exibido durante a fase "AiStarted": quando a conexão com o
// backend foi estabelecida mas o primeiro AiTextDelta ainda não chegou.
//
// Implementação: 3 linhas de larguras diferentes animadas com shimmer pulsante
// via AnimationController. Segue a paleta dark/light do app.
// ─────────────────────────────────────────────────────────────────────────────
class AiSkeletonLines extends StatefulWidget {
  final bool dark;
  const AiSkeletonLines({super.key, required this.dark});

  @override
  State<AiSkeletonLines> createState() => _AiSkeletonLinesState();
}

class _AiSkeletonLinesState extends State<AiSkeletonLines>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.25, end: 0.65).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor =
        widget.dark ? const Color(0xFF2A3040) : const Color(0xFFE2E8F0);

    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _skeletonBar(baseColor, double.infinity),
              const SizedBox(height: 8),
              _skeletonBar(baseColor, double.infinity),
              const SizedBox(height: 8),
              _skeletonBar(baseColor, 180),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skeletonBar(Color color, double width) => Container(
        height: 13,
        width: width,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
      );
}
