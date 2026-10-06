import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../services/audio/recording_input_level.dart';

class RecordingIntelligenceHero extends StatefulWidget {
  const RecordingIntelligenceHero(
      {super.key,
      required this.level,
      required this.duration,
      required this.recording,
      required this.status,
      required this.subtitle,
      required this.isEs,
      this.processing = false});
  final ValueNotifier<RecordingInputLevel> level;
  final Duration duration;
  final bool recording, isEs, processing;
  final String status, subtitle;
  @override
  State<RecordingIntelligenceHero> createState() =>
      _RecordingIntelligenceHeroState();
}

class _RecordingIntelligenceHeroState extends State<RecordingIntelligenceHero>
    with SingleTickerProviderStateMixin {
  late final pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion();
  }

  @override
  void didUpdateWidget(covariant RecordingIntelligenceHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    _motion();
  }

  void _motion() {
    if (widget.recording && !MediaQuery.disableAnimationsOf(context)) {
      if (!pulse.isAnimating) pulse.repeat(reverse: true);
    } else {
      pulse.stop();
      pulse.value = 0;
    }
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  String tr(String pt, String es) => widget.isEs ? es : pt;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final green = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF62D6AF)
        : const Color(0xFF087B59);
    final seconds = widget.duration.inSeconds;
    final time =
        '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return DecoratedBox(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                      green.withValues(alpha: .09), colors.surface),
                  colors.surface
                ]),
            border: Border.all(
                color: colors.outlineVariant.withValues(alpha: .55))),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            child: Column(children: [
              AnimatedBuilder(
                  animation: pulse,
                  builder: (context, child) => Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: green.withValues(alpha: .10),
                          border: Border.all(
                              color: green.withValues(
                                  alpha: .16 + pulse.value * .14),
                              width: 1.5),
                          boxShadow: [
                            BoxShadow(
                                color: green.withValues(
                                    alpha: .05 + pulse.value * .06),
                                blurRadius: 18 + pulse.value * 12)
                          ]),
                      child: child),
                  child: Icon(Icons.mic_rounded, color: green, size: 32)),
              const SizedBox(height: 18),
              FittedBox(
                  child: Text(time,
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(
                              fontSize: 48,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -1.5,
                              fontFeatures: const [
                            FontFeature.tabularFigures()
                          ]))),
              const SizedBox(height: 8),
              Semantics(
                  liveRegion: true,
                  child: Text(widget.status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: green,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1))),
              const SizedBox(height: 8),
              if (widget.subtitle.isNotEmpty)
                Text(widget.subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(height: 24),
              if (widget.processing)
                LinearProgressIndicator(value: MediaQuery.disableAnimationsOf(context) ? .5 : null)
              else if (widget.recording)
                RepaintBoundary(
                    child: SizedBox(
                        height: 64,
                        width: double.infinity,
                        child: CustomPaint(
                            painter: _MeasuredWavePainter(widget.level, green,
                                colors.outlineVariant, widget.recording)))),
              const SizedBox(height: 12),
              if (widget.recording)
                ValueListenableBuilder<RecordingInputLevel>(
                    valueListenable: widget.level,
                    builder: (context, level, _) {
                      final quality = widget.recording
                          ? level.quality
                          : RecordingInputQuality.unavailable;
                      final text = switch (quality) {
                        RecordingInputQuality.tooLow => tr(
                            'Fale um pouco mais perto do dispositivo.',
                            'Habla un poco más cerca del dispositivo.'),
                        RecordingInputQuality.good =>
                          tr('Captação ideal', 'Captación ideal'),
                        RecordingInputQuality.high => tr(
                            'Áudio alto · afaste um pouco o dispositivo',
                            'Audio alto · aleja un poco el dispositivo'),
                        RecordingInputQuality.clipping => tr(
                            'Possível saturação · afaste o dispositivo',
                            'Posible saturación · aleja el dispositivo'),
                        RecordingInputQuality.unavailable =>
                          tr('Nível do microfone', 'Nivel del micrófono')
                      };
                      return SizedBox(
                          height: 42,
                          child: Center(
                              child: Text(text,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: quality ==
                                              RecordingInputQuality.clipping
                                          ? colors.error
                                          : colors.onSurfaceVariant))));
                    })
            ])));
  }
}

class _MeasuredWavePainter extends CustomPainter {
  _MeasuredWavePainter(
      this.level, this.activeColor, this.inactiveColor, this.active)
      : super(repaint: level);
  final ValueNotifier<RecordingInputLevel> level;
  final Color activeColor, inactiveColor;
  final bool active;
  @override
  void paint(Canvas canvas, Size size) {
    final samples = level.value.history;
    final paint = Paint()..color = active ? activeColor : inactiveColor;
    const count = 48;
    final step = size.width / count;
    for (var i = 0; i < count; i++) {
      final sampleIndex = i - (count - samples.length);
      final value = active && sampleIndex >= 0 ? samples[sampleIndex] : 0.0;
      final height = 3 + value * (size.height - 3);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(
                  i * step, (size.height - height) / 2, step * .48, height),
              const Radius.circular(3)),
          paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeasuredWavePainter oldDelegate) =>
      oldDelegate.active != active ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.inactiveColor != inactiveColor ||
      oldDelegate.level != level;
}
