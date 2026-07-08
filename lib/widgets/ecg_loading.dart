// ═══════════════════════════════════════════════════════════════════════════
// EcgLoadingIndicator — BUILD 277
// Premium animated ECG trace widget for MedCases IA loading state.
//
// Design spec (UPDATE):
//   • Simulates a real ICU cardiac monitor trace: P-wave → QRS → T-wave.
//   • Trace colour: Crimson #AC2A2A (MedCases brand red).
//   • Animation: the scan-line sweeps left→right continuously (loop).
//   • Trailing tail fades to transparent — classic ICU oscilloscope look.
//   • Eraser track ahead of head: dark mode = #12161F, light mode = white.
//   • Works on both dark (#12161F) and light (white) chat backgrounds.
//   • Entirely self-contained: zero external dependencies beyond Flutter core.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── Brand colours ─────────────────────────────────────────────────────────
const Color kEcgRed   = Color(0xFFAC2A2A);
/// Clinical green — ICU monitor style (#00C78C). Used when the ECG trace
/// should feel "live / safe" rather than alarm-red (e.g. streaming state).
const Color kEcgGreen = Color(0xFF00C78C);

// ── Public widget ─────────────────────────────────────────────────────────
class EcgLoadingIndicator extends StatefulWidget {
  /// Width of the ECG canvas. Defaults to full available width.
  final double? width;

  /// Height of the ECG canvas.
  final double height;

  /// Trace colour. Defaults to MedCases crimson #AC2A2A.
  final Color traceColor;

  /// Background colour. Pass null to use transparent (inherits parent).
  final Color? backgroundColor;

  /// Duration of one complete sweep cycle.
  final Duration cycleDuration;

  /// Whether to show the pulsing dot at the scan-line head.
  final bool showHeadDot;

  const EcgLoadingIndicator({
    super.key,
    this.width,
    this.height = 56,
    this.traceColor = kEcgRed,
    this.backgroundColor,
    this.cycleDuration = const Duration(milliseconds: 1800),
    this.showHeadDot = true,
  });

  @override
  State<EcgLoadingIndicator> createState() => _EcgLoadingIndicatorState();
}

class _EcgLoadingIndicatorState extends State<EcgLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.cycleDuration)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _EcgPainter(
            progress:        _ctrl.value,
            traceColor:      widget.traceColor,
            backgroundColor: widget.backgroundColor,
            showHeadDot:     widget.showHeadDot,
          ),
        ),
      ),
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────
class _EcgPainter extends CustomPainter {
  final double  progress;        // 0.0 → 1.0 (animation cycle)
  final Color   traceColor;
  final Color?  backgroundColor;
  final bool    showHeadDot;

  const _EcgPainter({
    required this.progress,
    required this.traceColor,
    required this.backgroundColor,
    required this.showHeadDot,
  });

  // ── ECG waveform definition ─────────────────────────────────────────────
  // Each point is a (normalised_x, normalised_y) pair where:
  //   x ∈ [0, 1]  spans the full canvas width.
  //   y ∈ [0, 1]  where 0.5 = baseline, 0 = top, 1 = bottom.
  //
  // BUILD 277: deeper QRS spike (R peak at y=0.02), more visible P-wave
  // and T-wave humps for a crisper medical-grade oscilloscope appearance.
  static const List<Offset> _waveform = [
    // ── Beat 1 ─────────────────────────────────────────────────────────
    // Flat baseline left
    Offset(0.00, 0.50),
    Offset(0.07, 0.50),
    // P-wave (smooth positive hump)
    Offset(0.10, 0.50),
    Offset(0.12, 0.36),
    Offset(0.14, 0.50),
    // PR segment flat
    Offset(0.18, 0.50),
    // Q dip
    Offset(0.20, 0.60),
    // R spike (tall — QRS complex — BUILD 277: y=0.02 for maximum drama)
    Offset(0.22, 0.02),
    // S dip
    Offset(0.24, 0.65),
    // ST segment returning to baseline
    Offset(0.28, 0.50),
    // T-wave (rounded positive hump)
    Offset(0.32, 0.50),
    Offset(0.36, 0.30),
    Offset(0.40, 0.50),
    // Flat baseline right of beat 1
    Offset(0.52, 0.50),

    // ── Beat 2 (shifted +0.52) ─────────────────────────────────────────
    Offset(0.59, 0.50),
    Offset(0.62, 0.36),
    Offset(0.64, 0.50),
    Offset(0.68, 0.50),
    Offset(0.70, 0.60),
    Offset(0.72, 0.02),
    Offset(0.74, 0.65),
    Offset(0.78, 0.50),
    Offset(0.82, 0.50),
    Offset(0.86, 0.30),
    Offset(0.90, 0.50),
    Offset(1.00, 0.50),
  ];

  /// Smooth-step interpolated Y value at normalised X.
  double _waveY(double nx) {
    if (nx <= _waveform.first.dx) return _waveform.first.dy;
    if (nx >= _waveform.last.dx)  return _waveform.last.dy;
    for (int i = 0; i < _waveform.length - 1; i++) {
      final a = _waveform[i];
      final b = _waveform[i + 1];
      if (nx >= a.dx && nx <= b.dx) {
        final t = (nx - a.dx) / (b.dx - a.dx);
        // Cubic smooth-step: softer than linear, crisper than cosine
        final s = t * t * (3 - 2 * t);
        return a.dy + (b.dy - a.dy) * s;
      }
    }
    return 0.5;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Optional background fill ───────────────────────────────────────────
    if (backgroundColor != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()..color = backgroundColor!,
      );
    }

    // ── Pre-compute full waveform points ───────────────────────────────────
    const int steps = 400;  // BUILD 277: 300→400 for smoother QRS
    final List<Offset> pts = List.generate(steps + 1, (i) {
      final nx = i / steps;
      return Offset(nx * w, _waveY(nx) * h);
    });

    // ── Scan-line head position ────────────────────────────────────────────
    final headX = progress * w;

    // ── Tail gradient: 50% of canvas width behind head ────────────────────
    const double tailFraction = 0.50;
    final tailStartX = headX - tailFraction * w;

    for (int i = 0; i < pts.length - 1; i++) {
      final px = pts[i].dx;
      if (px > headX)    break;   // ahead of scan-line: skip
      if (px < tailStartX) continue; // before tail start: skip

      final ratio = tailStartX < headX
          ? (px - tailStartX) / (headX - tailStartX)
          : 1.0;

      // sqrt curve: slow fade at tail, bright near head
      final alpha = (math.sqrt(ratio) * 255).round().clamp(0, 255);

      final segPaint = Paint()
        ..color = traceColor.withAlpha(alpha)
        ..strokeWidth = 2.2           // BUILD 277: 2.0→2.2 for crispness
        ..strokeCap  = StrokeCap.round
        ..style      = PaintingStyle.stroke;

      canvas.drawLine(pts[i], pts[i + 1], segPaint);
    }

    // ── Eraser: blank region ahead of scan-line ────────────────────────────
    // Uses the provided backgroundColor; falls back to transparent (clip).
    // On dark mode this should be #12161F; on light mode, white.
    final eraserColor = backgroundColor;
    if (eraserColor != null && headX < w) {
      canvas.drawRect(
        Rect.fromLTRB(headX + 1, 0, w, h),
        Paint()..color = eraserColor,
      );
    }

    // ── Scan-line head glow + dot ──────────────────────────────────────────
    if (showHeadDot && headX >= 0 && headX <= w) {
      final headY = _waveY(progress) * h;

      // Outer soft bloom
      canvas.drawCircle(
        Offset(headX, headY),
        9,
        Paint()
          ..color = traceColor.withAlpha(35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );

      // Mid glow ring
      canvas.drawCircle(
        Offset(headX, headY),
        5,
        Paint()
          ..color = traceColor.withAlpha(80)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Solid dot (brand red, full opacity)
      canvas.drawCircle(
        Offset(headX, headY),
        3.0,
        Paint()
          ..color = traceColor
          ..style = PaintingStyle.fill,
      );

      // White core for neon illusion
      canvas.drawCircle(
        Offset(headX, headY),
        1.3,
        Paint()
          ..color = Colors.white.withAlpha(200)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_EcgPainter old) =>
      old.progress != progress || old.traceColor != traceColor;
}

// ── Convenience wrapper with label ────────────────────────────────────────
/// Full loading block: ECG trace + pulsing dot + "Analisando…" label.
/// BUILD 327+: default traceColor updated to clinical green kEcgGreen.
/// Pass [active]=false to freeze the animation (e.g. when stream ends).
class EcgLoadingBlock extends StatelessWidget {
  final bool   dark;
  final String lang;
  final Color  traceColor;
  /// When false the ECG trace is hidden (zero-height SizedBox) — use this
  /// to show/hide the widget without unmounting it (avoids rebuild flash).
  final bool   active;

  const EcgLoadingBlock({
    super.key,
    this.dark       = true,
    this.lang       = 'pt',
    this.traceColor = kEcgGreen,
    this.active     = true,
  });

  @override
  Widget build(BuildContext context) {
    // BUILD 327+: hide entirely when inactive (stream not running)
    if (!active) return const SizedBox.shrink();

    // BUILD 277: background palette aligned with app scaffold
    final bgColor    = dark ? const Color(0xFF12161F) : Colors.white;
    final labelColor = dark
        ? Colors.white.withAlpha(110)
        : Colors.black.withAlpha(90);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EcgLoadingIndicator(
          height:          58,
          traceColor:      traceColor,
          backgroundColor: bgColor,
          cycleDuration:   const Duration(milliseconds: 1700),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulsingDot(color: traceColor),
            const SizedBox(width: 7),
            Text(
              lang == 'es' ? 'Analizando caso clínico…' : 'Analisando caso clínico…',
              style: TextStyle(
                fontSize:      12,
                fontWeight:    FontWeight.w600,
                color:         labelColor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Tiny pulsing dot that breathes in sync with the ECG brand colour.
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 850))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: Container(
      width: 7, height: 7,
      decoration: BoxDecoration(
        shape:     BoxShape.circle,
        color:     widget.color,
        boxShadow: [
          BoxShadow(
            color:       widget.color.withAlpha(130),
            blurRadius:  5,
            spreadRadius: 1,
          ),
        ],
      ),
    ),
  );
}
