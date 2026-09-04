// ============================================================================
// MEDCASES PRO
// HOME V2
// THINKING INDICATOR
// ============================================================================

import 'package:flutter/material.dart';

import 'chat_theme.dart';

class ThinkingIndicator extends StatefulWidget {

  const ThinkingIndicator({
    super.key,
  });

  @override
  State<ThinkingIndicator> createState() =>
      _ThinkingIndicatorState();

}

class _ThinkingIndicatorState
    extends State<ThinkingIndicator>
    with SingleTickerProviderStateMixin {

  late final AnimationController _controller;

  @override
  void initState() {

    super.initState();

    _controller = AnimationController(

      vsync: this,

      duration: const Duration(
        milliseconds: 900,
      ),

    )..repeat();

  }

  @override
  void dispose() {

    _controller.dispose();

    super.dispose();

  }

  Widget _dot(int index){

    return AnimatedBuilder(

      animation: _controller,

      builder: (_,__) {

        final value =
            (_controller.value + (index*0.18)) % 1.0;

        final opacity =
            value < .5
                ? .35 + value
                : 1.35 - value;

        return Opacity(

          opacity: opacity.clamp(.25,1),

          child: Container(

            width: 8,

            height: 8,

            margin: const EdgeInsets.symmetric(horizontal:3),

            decoration: const BoxDecoration(

              shape: BoxShape.circle,

              color: ChatTheme.primary,

            ),

          ),

        );

      },

    );

  }

  @override
  Widget build(BuildContext context){

    return Row(

      mainAxisSize: MainAxisSize.min,

      children: [

        _dot(0),

        _dot(1),

        _dot(2),

      ],

    );

  }

}
