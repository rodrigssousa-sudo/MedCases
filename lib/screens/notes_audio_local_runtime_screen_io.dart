import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../services/audio/clinical_long_form_audio_contract.dart';
import '../services/audio/clinical_long_form_recording_manifest.dart';
import '../services/audio/clinical_long_form_recording_session.dart';
import '../services/audio/clinical_long_form_session_directory_layout.dart';
import '../services/audio/record_long_form_audio_provider.dart';
import '../services/clinical_recorder_service.dart';

final class _AudioRuntimePalette {
  const _AudioRuntimePalette({
    required this.page,
    required this.card,
    required this.divider,
    required this.text,
    required this.secondary,
    required this.accent,
  });

  final Color page;
  final Color card;
  final Color divider;
  final Color text;
  final Color secondary;
  final Color accent;

  factory _AudioRuntimePalette.of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return _AudioRuntimePalette(
      page: dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3),
      card: dark ? const Color(0xFF252930) : Colors.white,
      divider: dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC),
      text: dark ? const Color(0xFFF8FAFC) : const Color(0xFF111318),
      secondary: dark ? const Color(0xFFC6CED9) : const Color(0xFF52606D),
      accent: const Color(0xFF10B981),
    );
  }
}

class NotesAudioConsultationLocalRuntimeScreen extends StatefulWidget {
  const NotesAudioConsultationLocalRuntimeScreen({
    super.key,
    required this.isEs,
  });

  final bool isEs;

  @override
  State<NotesAudioConsultationLocalRuntimeScreen> createState() =>
      _NotesAudioConsultationLocalRuntimeScreenState();
}

class _NotesAudioConsultationLocalRuntimeScreenState
    extends State<NotesAudioConsultationLocalRuntimeScreen> {
  final ClinicalRecorderService _recorder = ClinicalRecorderService();

  StreamSubscription<String>? _transcriptSub;
  StreamSubscription<bool>? _stateSub;
  Timer? _clock;

  String _transcript = '';
  String? _error;
  bool _recording = false;
  bool _paused = false;
  bool _busy = false;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();

    _transcriptSub = _recorder.transcriptStream.listen((value) {
      if (!mounted) return;
      setState(() => _transcript = value);
    });

    _stateSub = _recorder.stateStream.listen((value) {
      if (!mounted) return;
      setState(() => _recording = value);
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _transcriptSub?.cancel();
    _stateSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_busy || _recording) return;

    setState(() {
      _busy = true;
      _error = null;
      _elapsedSeconds = 0;
      _transcript = '';
      _paused = false;
    });

    try {
      await _recorder.start(lang: widget.isEs ? 'es' : 'pt');

      _clock?.cancel();
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_recording || _paused) return;
        setState(() => _elapsedSeconds += 1);
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _pause() {
    if (_busy || !_recording || _paused) return;
    _recorder.pause();
    setState(() => _paused = true);
  }

  void _resume() {
    if (_busy || !_recording || !_paused) return;
    _recorder.resume();
    setState(() => _paused = false);
  }

  Future<void> _stop() async {
    if (_busy || (!_recording && _transcript.trim().isEmpty)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final finalTranscript = await _recorder.stop();
      _clock?.cancel();

      if (!mounted) return;

      setState(() {
        _recording = false;
        _paused = false;
        if (finalTranscript.trim().isNotEmpty) {
          _transcript = finalTranscript.trim();
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _AudioRuntimePalette.of(context);
    final isEs = widget.isEs;

    return _AudioRuntimeScaffold(
      palette: palette,
      title: 'Consulta clínica',
      subtitle: isEs
          ? 'Motor clínico existente con transcripción progresiva.'
          : 'Motor clínico existente com transcrição progressiva.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusStrip(
            palette: palette,
            label: _recording
                ? (_paused ? 'Pausado' : (isEs ? 'Grabando' : 'Gravando'))
                : (isEs ? 'Listo' : 'Pronto'),
            detail: _formatDuration(_elapsedSeconds),
          ),
          const SizedBox(height: 8),
          _RuntimeCard(
            palette: palette,
            title: isEs ? 'Transcripción' : 'Transcrição',
            child: Text(
              _transcript.trim().isEmpty
                  ? (isEs
                      ? 'La transcripción aparecerá aquí durante la captura.'
                      : 'A transcrição aparecerá aqui durante a captura.')
                  : _transcript,
              style: TextStyle(
                color: palette.secondary,
                fontSize: 12.5,
                height: 1.42,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            _RuntimeError(palette: palette, text: _error!),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SolidActionButton(
                  palette: palette,
                  label: !_recording
                      ? 'Iniciar'
                      : (_paused ? (isEs ? 'Reanudar' : 'Retomar') : 'Pausar'),
                  icon: !_recording
                      ? Icons.mic_rounded
                      : (_paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded),
                  enabled: !_busy,
                  onPressed:
                      !_recording ? _start : (_paused ? _resume : _pause),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NeutralActionButton(
                  palette: palette,
                  label: 'Finalizar',
                  icon: Icons.stop_rounded,
                  enabled:
                      !_busy && (_recording || _transcript.trim().isNotEmpty),
                  onPressed: _stop,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _SafetyNote(
            palette: palette,
            text: isEs
                ? 'Esta etapa no conecta este workspace al backend remoto de '
                    'transcripción de audio de MedCases.'
                : 'Esta etapa não conecta este workspace ao backend remoto de '
                    'transcrição de áudio do MedCases.',
          ),
        ],
      ),
    );
  }
}

class NotesAudioLongFormLocalRuntimeScreen extends StatefulWidget {
  const NotesAudioLongFormLocalRuntimeScreen({
    super.key,
    required this.isEs,
  });

  final bool isEs;

  @override
  State<NotesAudioLongFormLocalRuntimeScreen> createState() =>
      _NotesAudioLongFormLocalRuntimeScreenState();
}

class _NotesAudioLongFormLocalRuntimeScreenState
    extends State<NotesAudioLongFormLocalRuntimeScreen> {
  ClinicalLongFormRecordingSession? _session;
  ClinicalLongFormSessionDirectoryLayout? _layout;
  ClinicalLongFormRecordingManifest? _stoppedManifest;
  Timer? _ticker;

  bool _busy = false;
  int _segmentIndex = 0;
  int _rotations = 0;
  String? _error;

  bool get _recording =>
      _session?.state == ClinicalLongFormRecordingState.recording;

  bool get _paused => _session?.state == ClinicalLongFormRecordingState.paused;

  bool get _stopped =>
      _session?.state == ClinicalLongFormRecordingState.stopped;

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_disposeRuntime());
    super.dispose();
  }

  Future<void> _disposeRuntime() async {
    final session = _session;

    if (session != null && !_stopped) {
      try {
        await session.stop(DateTime.now().toUtc());
      } catch (_) {}
    }

    try {
      await session?.dispose();
    } catch (_) {}
  }

  Future<void> _start() async {
    if (_busy || _session != null) return;

    setState(() {
      _busy = true;
      _error = null;
      _segmentIndex = 0;
      _rotations = 0;
      _stoppedManifest = null;
    });

    RecordLongFormAudioProvider? provider;

    try {
      provider = RecordLongFormAudioProvider();

      final aacSupported = await provider.isAacLcSupported();
      if (!aacSupported) {
        await provider.dispose();
        provider = null;
        throw StateError('AAC-LC unsupported on this device.');
      }

      final temp = await getTemporaryDirectory();
      final root = Directory(
        '${temp.path}${Platform.pathSeparator}'
        'medcases_notes_audio_long_form',
      );

      if (!await root.exists()) {
        await root.create(recursive: true);
      }

      final sessionId =
          'notes_audio_${DateTime.now().toUtc().microsecondsSinceEpoch}';

      final layout = ClinicalLongFormSessionDirectoryLayout(
        rootDirectory: root,
        sessionId: sessionId,
      );
      await layout.ensureDirectories();

      final session = ClinicalLongFormRecordingSession(
        sessionId: sessionId,
        locale: widget.isEs ? 'es-ES' : 'pt-BR',
        capture: provider,
      );

      await session.start(
        firstSegmentPath: layout.segmentFile(0).path,
        nowUtc: DateTime.now().toUtc(),
      );

      _layout = layout;
      _session = session;
      provider = null;

      _ticker?.cancel();
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(_tick()),
      );

      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (provider != null) {
        try {
          await provider.dispose();
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _tick() async {
    final session = _session;
    final layout = _layout;

    if (!mounted || session == null || layout == null) return;

    final now = DateTime.now().toUtc();

    if (_recording && !_busy) {
      if (session.reachedMaxDuration(now)) {
        await _stop();
        return;
      }

      if (session.shouldRotate(now)) {
        await _rotate(now);
        return;
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _rotate(DateTime nowUtc) async {
    final session = _session;
    final layout = _layout;

    if (_busy || !_recording || session == null || layout == null) return;

    setState(() => _busy = true);

    try {
      final nextIndex = _segmentIndex + 1;

      await session.rotate(
        nextSegmentPath: layout.segmentFile(nextIndex).path,
        nowUtc: nowUtc,
      );

      _segmentIndex = nextIndex;
      _rotations += 1;
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _pause() async {
    final session = _session;

    if (_busy || !_recording || session == null) return;

    setState(() => _busy = true);

    try {
      await session.pause(DateTime.now().toUtc());
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resume() async {
    final session = _session;

    if (_busy || !_paused || session == null) return;

    setState(() => _busy = true);

    try {
      await session.resume(DateTime.now().toUtc());
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _stop() async {
    final session = _session;

    if (_busy || session == null || _stopped) return;

    setState(() => _busy = true);

    try {
      final now = DateTime.now().toUtc();

      await session.stop(now);
      _ticker?.cancel();
      _stoppedManifest = session.snapshot(now);
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _AudioRuntimePalette.of(context);
    final isEs = widget.isEs;
    final now = DateTime.now().toUtc();

    final activeDuration =
        _session == null ? Duration.zero : _session!.activeDurationAt(now);

    return _AudioRuntimeScaffold(
      palette: palette,
      title: isEs ? 'Clase / audio largo' : 'Aula / áudio longo',
      subtitle: isEs
          ? 'Grabación local M4A segmentada para sesiones extensas.'
          : 'Gravação local M4A segmentada para sessões extensas.',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusStrip(
            palette: palette,
            label: _stoppedManifest != null
                ? 'Finalizado'
                : (_paused
                    ? 'Pausado'
                    : (_recording
                        ? (isEs ? 'Grabando' : 'Gravando')
                        : (isEs ? 'Listo' : 'Pronto'))),
            detail: _formatDuration(activeDuration.inSeconds),
          ),
          const SizedBox(height: 8),
          _RuntimeCard(
            palette: palette,
            title: isEs ? 'Sesión local' : 'Sessão local',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEs
                      ? 'AAC-LC · M4A segmentado · pausa y reanudación'
                      : 'AAC-LC · M4A segmentado · pausa e retomada',
                  style: TextStyle(
                    color: palette.secondary,
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEs
                      ? 'Rotaciones completadas: $_rotations'
                      : 'Rotações concluídas: $_rotations',
                  style: TextStyle(
                    color: palette.secondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_stoppedManifest != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    isEs
                        ? 'Segmentos mantenidos para revisión: '
                            '${_stoppedManifest!.segments.length}'
                        : 'Segmentos mantidos para revisão: '
                            '${_stoppedManifest!.segments.length}',
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            _RuntimeError(palette: palette, text: _error!),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SolidActionButton(
                  palette: palette,
                  label: _session == null
                      ? 'Iniciar'
                      : (_paused ? (isEs ? 'Reanudar' : 'Retomar') : 'Pausar'),
                  icon: _session == null
                      ? Icons.fiber_manual_record_rounded
                      : (_paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded),
                  enabled: !_busy && _stoppedManifest == null,
                  onPressed:
                      _session == null ? _start : (_paused ? _resume : _pause),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NeutralActionButton(
                  palette: palette,
                  label: 'Finalizar',
                  icon: Icons.stop_rounded,
                  enabled:
                      !_busy && _session != null && _stoppedManifest == null,
                  onPressed: _stop,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _SafetyNote(
            palette: palette,
            text: isEs
                ? 'El M4A permanece local para revisión. Esta etapa no llama '
                    'al backend remoto de transcripción.'
                : 'O M4A permanece local para revisão. Esta etapa não chama '
                    'o backend remoto de transcrição.',
          ),
        ],
      ),
    );
  }
}

class _AudioRuntimeScaffold extends StatelessWidget {
  const _AudioRuntimeScaffold({
    required this.palette,
    required this.title,
    required this.subtitle,
    required this.body,
  });

  final _AudioRuntimePalette palette;
  final String title;
  final String subtitle;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: palette.page,
      appBar: AppBar(
        backgroundColor: palette.page,
        foregroundColor: palette.text,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 48,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(
            Icons.chevron_left_rounded,
            size: 23,
            color: palette.text,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: palette.text,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              subtitle,
              style: TextStyle(
                color: palette.secondary,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            body,
          ],
        ),
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.palette,
    required this.label,
    required this.detail,
  });

  final _AudioRuntimePalette palette;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.divider, width: 0.7),
      ),
      child: Row(
        children: [
          Icon(
            Icons.graphic_eq_rounded,
            size: 18,
            color: palette.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: palette.text,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            detail,
            style: TextStyle(
              color: palette.secondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RuntimeCard extends StatelessWidget {
  const _RuntimeCard({
    required this.palette,
    required this.title,
    required this.child,
  });

  final _AudioRuntimePalette palette;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.divider, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: palette.text,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _SolidActionButton extends StatelessWidget {
  const _SolidActionButton({
    required this.palette,
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final _AudioRuntimePalette palette;
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: palette.divider,
          disabledForegroundColor: palette.secondary,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          overlayColor: Colors.transparent,
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _NeutralActionButton extends StatelessWidget {
  const _NeutralActionButton({
    required this.palette,
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final _AudioRuntimePalette palette;
  final String label;
  final IconData icon;
  final bool enabled;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        onPressed: enabled ? () => unawaited(onPressed()) : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.text,
          disabledForegroundColor: palette.secondary,
          backgroundColor: Colors.transparent,
          side: BorderSide(color: palette.divider, width: 0.8),
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          overlayColor: Colors.transparent,
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote({
    required this.palette,
    required this.text,
  });

  final _AudioRuntimePalette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: palette.secondary,
        fontSize: 11,
        height: 1.4,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _RuntimeError extends StatelessWidget {
  const _RuntimeError({
    required this.palette,
    required this.text,
  });

  final _AudioRuntimePalette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.55),
          width: 0.7,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFFCA5A5),
          fontSize: 11.5,
          height: 1.4,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

String _formatDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainingSeconds = seconds % 60;

  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }

  return '${minutes.toString().padLeft(2, '0')}:'
      '${remainingSeconds.toString().padLeft(2, '0')}';
}
