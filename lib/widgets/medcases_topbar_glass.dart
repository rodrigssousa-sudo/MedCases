import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// The existing Home glass, shared without adding a second material layer.
class MedcasesTopbarGlass extends StatelessWidget {
  const MedcasesTopbarGlass(
      {super.key, required this.dark, required this.child});
  final bool dark;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    // MEDCASES_HOME_TOPBAR_TRUE_LIQUID_GLASS_V1_B_R0
    // Shared by the commercial Home and Clinical headers.
    final glassColor = dark
        ? const Color(0xFF161B22).withValues(alpha: 0.58)
        : Colors.white.withValues(alpha: 0.56);
    final liquidTop = dark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.46);
    final liquidMid = dark
        ? Colors.white.withValues(alpha: 0.025)
        : Colors.white.withValues(alpha: 0.12);
    final borderColor = dark
        ? Colors.white.withValues(alpha: 0.13)
        : Colors.white.withValues(alpha: 0.78);
    final liquidSpecular = dark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.86);

    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.16 : 0.07),
            blurRadius: 14,
            spreadRadius: -8,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: glassColor,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  liquidTop,
                  liquidMid,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.42, 1.0],
              ),
              border: Border(
                bottom: BorderSide(color: borderColor, width: 0.7),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 0.7,
                  child: Container(
                    height: 0.7,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          liquidSpecular,
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
