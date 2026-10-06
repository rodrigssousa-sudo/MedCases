import 'package:flutter/material.dart';

enum AudioRecorderPresentation {
  idle,
  recording,
  paused,
  processing,
  error,
  completed,
}

/// Presentation only: owners supply state, enabled callbacks and capabilities.
class MedCasesAudioRecorderView extends StatelessWidget {
  const MedCasesAudioRecorderView({
    super.key,
    required this.isEs,
    required this.state,
    required this.duration,
    this.waveform,
    this.showStart = false,
    this.showPause = false,
    this.pauseIsResume,
    this.showFinish = true,
    this.onStart,
    this.onPause,
    this.onResume,
    this.onFinish,
    this.onCancel,
    this.finishLabel,
    this.error,
  });

  final bool isEs;
  final AudioRecorderPresentation state;
  final Duration duration;
  final Widget? waveform;
  final bool showStart, showPause, showFinish;
  final bool? pauseIsResume;
  final VoidCallback? onStart, onPause, onResume, onFinish, onCancel;
  final String? finishLabel, error;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final paused = pauseIsResume ?? state == AudioRecorderPresentation.paused;
    const green = Color(0xFF10B981);
    final secondary = dark ? const Color(0xFFC6CED9) : const Color(0xFF52606D);
    final label = switch (state) {
      AudioRecorderPresentation.idle => isEs ? 'Listo' : 'Pronto',
      AudioRecorderPresentation.recording => isEs ? 'Grabando' : 'Gravando',
      AudioRecorderPresentation.paused => 'Pausado',
      AudioRecorderPresentation.processing =>
        isEs ? 'Procesando' : 'Processando',
      AudioRecorderPresentation.error =>
        isEs ? 'Error de grabación' : 'Erro de gravação',
      AudioRecorderPresentation.completed => 'Finalizado',
    };
    final seconds = duration.inSeconds;
    final time =
        '${seconds >= 3600 ? '${(seconds ~/ 3600).toString().padLeft(2, '0')}:' : ''}${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF252930) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                green.withValues(alpha: 0.16),
                green.withValues(alpha: 0.04)
              ]),
              border: Border.all(color: green.withValues(alpha: 0.18)),
            ),
            child: Icon(Icons.mic_rounded,
                size: 30,
                color: state == AudioRecorderPresentation.recording
                    ? green
                    : secondary),
          ),
          Text(
            time,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: dark ? const Color(0xFFF8FAFC) : const Color(0xFF111318),
              fontSize: 30,
              fontWeight: FontWeight.w400,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          waveform ?? const MedCasesAudioWaveform(),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: state == AudioRecorderPresentation.recording
                  ? green
                  : secondary,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              if (showStart)
                FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.mic_none_rounded, size: 18),
                  label: Text(isEs ? 'Iniciar grabación' : 'Iniciar gravação'),
                ),
              if (showPause)
                OutlinedButton.icon(
                  onPressed: paused ? onResume : onPause,
                  icon: Icon(
                    paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    size: 18,
                  ),
                  label: Text(
                    paused ? (isEs ? 'Reanudar' : 'Retomar') : 'Pausar',
                  ),
                ),
              if (showFinish)
                FilledButton.icon(
                  onPressed: onFinish,
                  icon: const Icon(Icons.stop_rounded, size: 18),
                  style: FilledButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                  ),
                  label: Text(finishLabel ?? 'Finalizar'),
                ),
            ],
          ),
          if (onCancel != null)
            TextButton(
              onPressed: onCancel,
              child: Text(
                isEs ? 'Cancelar grabación' : 'Cancelar gravação',
                style: TextStyle(color: secondary, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// A quiet level meter. No generated activity when no microphone level exists.
class MedCasesAudioWaveform extends StatelessWidget {
  const MedCasesAudioWaveform({super.key, this.level = 0});
  final double level;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          height: 28,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              19,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 3,
                height: 3 +
                    25 * level.clamp(0.0, 1.0) * (0.35 + ((i * 7) % 11) / 17),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF10B981,
                  ).withValues(alpha: level > 0 ? 0.8 : 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      );
}
