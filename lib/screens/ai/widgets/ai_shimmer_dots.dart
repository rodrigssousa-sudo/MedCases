import 'dart:math' as math;

import 'package:flutter/material.dart';

class AiShimmerDots extends StatefulWidget {
  final bool dark;

  const AiShimmerDots({
    super.key,
    required this.dark,
  });

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
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    final baseColor =
        widget.dark ? const Color(0xFF00E5FF) : const Color(0xFF008CA4);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offset = index * 0.4;
        final progress = (_controller.value * 2 * math.pi) - offset;
        final opacity = ((math.sin(progress) + 1.0) / 2.0).clamp(0.2, 1.0);

        return Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            _buildDot(1),
            _buildDot(2),
          ],
        ),
      ),
    );
  }
}
