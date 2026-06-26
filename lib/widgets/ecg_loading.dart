// ═══════════════════════════════════════════════════════════════════════════
// EcgLoadingIndicator — BUILD 276
// Premium animated ECG trace widget for MedCases IA loading state.
//
// Design spec:
//   • Simulates a real ICU cardiac monitor trace: P-wave → QRS → T-wave.
//   • Trace colour: #EF4444 (neon red) with a fading cyan leading glow.
//   • Animation: the scan-line sweeps left→right continuously (loop).
//   • Trailing tail fades to transparent — classic ICU oscilloscope look.
//   • Works on both dark (#1A1D23) and light (white) chat backgrounds.
//   • Entirely self-contained: zero external dependencies beyond Flutter core.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── Public widget ─────────────────────────────────────────────────────────
class EcgLoadingIndicator extends StatefulWidget {
  /// Width of the ECG canvas. Defaults to full available width.
  final double? width;

  /// Height of the ECG canvas.
  final double height;

  /// Trace colour. Defaults to neon red #EF4444.
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
    this.traceColor = const Color(0xFFEF4444),
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
  // Each segment is a (normalised_x, normalised_y) pair where:
  //   x ∈ [0, 1]  spans the full canvas width.
  //   y ∈ [0, 1]  where 0.5 = baseline, 0 = top, 1 = bottom.
  //
  // Waveform: flat → P-wave bump → flat → QRS spike → S-dip → T-wave → flat
  static const List<Offset> _waveform = [
    // Flat baseline left
    Offset(0.00, 0.50),
    Offset(0.08, 0.50),
    // P-wave (gentle bump)
    Offset(0.11, 0.50),
    Offset(0.13, 0.38),
    Offset(0.15, 0.50),
    // PR segment flat
    Offset(0.19, 0.50),
    // Q dip
    Offset(0.21, 0.56),
    // R spike (tall — QRS complex)
    Offset(0.23, 0.04),
    // S dip
    Offset(0.25, 0.62),
    // ST segment
    Offset(0.29, 0.50),
    // T-wave (smooth positive bump)
    Offset(0.33, 0.50),
    Offset(0.37, 0.32),
    Offset(0.41, 0.50),
    // Flat baseline right (rest of canvas)
    Offset(0.55, 0.50),
    // Second beat starts at offset 0.55 (repeat of same waveform)
    Offset(0.63, 0.50),
    Offset(0.65, 0.38),
    Offset(0.67, 0.50),
    Offset(0.71, 0.50),
    Offset(0.73, 0.56),
    Offset(0.75, 0.04),
    Offset(0.77, 0.62),
    Offset(0.81, 0.50),
    Offset(0.85, 0.50),
    Offset(0.89, 0.32),
    Offset(0.93, 0.50),
    Offset(1.00, 0.50),
  ];

  /// Interpolate the waveform Y-value at a given normalised X position.
  double _waveY(double nx) {
    if (nx <= _waveform.first.dx) return _waveform.first.dy;
    if (nx >= _waveform.last.dx)  return _waveform.last.dy;
    for (int i = 0; i < _waveform.length - 1; i++) {
      final a = _waveform[i];
      final b = _waveform[i + 1];
      if (nx >= a.dx && nx <= b.dx) {
        final t = (nx - a.dx) / (b.dx - a.dx);
        // Smooth step interpolation for organic feel
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

    // ── Build the full waveform path (pre-compute for tail rendering) ──────
    const int steps = 300;
    final List<Offset> pts = List.generate(steps + 1, (i) {
      final nx = i / steps;
      return Offset(nx * w, _waveY(nx) * h);
    });

    // ── Scan-line head position ────────────────────────────────────────────
    // progress=0 → head at left edge; progress=1 → head at right edge.
    final headX = progress * w;

    // ── Tail gradient paint ────────────────────────────────────────────────
    // Points behind the head fade from full opacity to transparent.
    // Tail length: 45% of canvas width for elegant oscilloscope look.
    const double tailFraction = 0.45;
    final tailStartX = headX - tailFraction * w;

    // We draw the tail as a series of short line segments, each with
    // an alpha proportional to its proximity to the head.
    final traceBase = traceColor;

    for (int i = 0; i < pts.length - 1; i++) {
      final px = pts[i].dx;
      if (px > headX) break;          // ahead of scan-line: skip
      if (px < tailStartX) continue;  // before tail start: skip

      // Normalised distance from tail start → head (0=tail end, 1=head)
      final ratio = tailStartX < headX
          ? (px - tailStartX) / (headX - tailStartX)
          : 1.0;

      // Opacity curve: sqrt for a natural fade
      final alpha = (math.sqrt(ratio) * 255).round().clamp(0, 255);

      final segPaint = Paint()
        ..color = traceBase.withAlpha(alpha)
        ..strokeWidth = 2.0
        ..strokeCap  = StrokeCap.round
        ..style      = PaintingStyle.stroke;

      canvas.drawLine(pts[i], pts[i + 1], segPaint);
    }

    // ── Leading glow at head ───────────────────────────────────────────────
    if (showHeadDot && headX >= 0 && headX <= w) {
      // Compute Y at head
      final headY = _waveY(progress) * h;

      // Outer soft glow (large, very transparent)
      final glowPaint = Paint()
        ..color = traceBase.withAlpha(45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(headX, headY), 7, glowPaint);

      // Inner bright dot
      final dotPaint = Paint()
        ..color = traceBase
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(headX, headY), 2.8, dotPaint);

      // Bright white core flicker (creates neon pulse illusion)
      final corePaint = Paint()
        ..color = Colors.white.withAlpha(180)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(headX, headY), 1.2, corePaint);
    }

    // ── Eraser: blank region ahead of scan-line ────────────────────────────
    // Keeps the "old trace" area clean so the sweep looks like a real monitor.
    if (backgroundColor != null && headX < w) {
      final eraser = Paint()..color = backgroundColor!;
      canvas.drawRect(
        Rect.fromLTRB(headX + 1, 0, w, h),
        eraser,
      );
    }
  }

  @override
  bool shouldRepaint(_EcgPainter old) =>
      old.progress != progress || old.traceColor != traceColor;
}

// ── Convenience wrapper with label ────────────────────────────────────────
/// Full loading block: ECG trace + optional "Analisando…" label below.
class EcgLoadingBlock extends StatelessWidget {
  final bool   dark;
  final String lang;
  final Color  traceColor;

  const EcgLoadingBlock({
    super.key,
    this.dark  = true,
    this.lang  = 'pt',
    this.traceColor = const Color(0xFFEF4444),
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = dark
        ? Colors.white.withAlpha(120)
        : Colors.black.withAlpha(100);
    final bgColor = dark
        ? const Color(0xFF1A1D23)
        : Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EcgLoadingIndicator(
          height:          56,
          traceColor:      traceColor,
          backgroundColor: bgColor,
          cycleDuration:   const Duration(milliseconds: 1600),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing dot
            _PulsingDot(color: traceColor),
            const SizedBox(width: 6),
            Text(
              lang == 'es' ? 'Analizando caso clínico…' : 'Analisando caso clínico…',
              style: TextStyle(
                fontSize:   12,
                fontWeight: FontWeight.w600,
                color:      labelColor,
                letterSpacing: 0.3,
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
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
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
        shape: BoxShape.circle,
        color: widget.color,
        boxShadow: [
          BoxShadow(color: widget.color.withAlpha(120), blurRadius: 4, spreadRadius: 1),
        ],
      ),
    ),
  );
}
