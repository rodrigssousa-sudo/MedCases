import 'package:flutter/material.dart';

import '../../theme/home_v2_palette.dart';

class HomeV2SurfaceTokens {
  const HomeV2SurfaceTokens._();

  static const double radius = 6;
  static const double borderWidth = 0.6;
  static const int idleBorderAlpha = 20;

  static const Color darkPageBackground = Color(0xFF1A1D23);
  static const Color lightPageBackground = Color(0xFFE0E6E9);

  static Color pageBackground(bool dark) {
    return dark ? darkPageBackground : lightPageBackground;
  }
}

/// Acabamento exclusivamente visual compartilhado pela Home V2.
///
/// Não possui navegação, timer, persistência ou lógica clínica.
class HomeV2PressSurface extends StatefulWidget {
  const HomeV2PressSurface({
    required this.palette,
    required this.child,
    super.key,
    this.backgroundColor,
  });

  final HomeV2Palette palette;
  final Widget child;
  final Color? backgroundColor;

  @override
  State<HomeV2PressSurface> createState() {
    return _HomeV2PressSurfaceState();
  }
}

class _HomeV2PressSurfaceState extends State<HomeV2PressSurface> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) {
      return;
    }

    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _pressed
        ? widget.palette.border
        : widget.palette.border.withAlpha(
            HomeV2SurfaceTokens.idleBorderAlpha,
          );

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? widget.palette.surface,
          borderRadius: BorderRadius.circular(
            HomeV2SurfaceTokens.radius,
          ),
          border: Border.all(
            color: borderColor,
            width: HomeV2SurfaceTokens.borderWidth,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            HomeV2SurfaceTokens.radius,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
