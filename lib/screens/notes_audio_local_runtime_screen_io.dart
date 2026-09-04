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

import '../models/study_long_form_audio_handoff.dart';

import 'dart:math' as math;
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
                  onPressed: !_recording
                      ? _start
                      : (_paused ? _resume : _pause),
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
    this.onCompleted,
  });

  final bool isEs;
  final ValueChanged<StudyLongFormAudioHandoff>? onCompleted;

  @override
  State<NotesAudioLongFormLocalRuntimeScreen> createState() =>
      _NotesAudioLongFormLocalRuntimeScreenState();
}

class _NotesAudioLongFormLocalRuntimeScreenState
    extends State<NotesAudioLongFormLocalRuntimeScreen> {
  RecordLongFormAudioProvider? _visualAudioProvider;
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
      _visualAudioProvider = provider;

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
      final manifest = session.snapshot(now);
      _stoppedManifest = manifest;

      final segments = manifest.segments
          .where((segment) => segment.completed)
          .map(
            (segment) => StudyLongFormAudioSegment(
              index: segment.index,
              path: segment.path,
              activeDurationMs: segment.activeDuration.inMilliseconds,
            ),
          )
          .toList(growable: false);

      if (segments.isNotEmpty) {
        widget.onCompleted?.call(
          StudyLongFormAudioHandoff(
            sessionId: manifest.sessionId,
            locale: manifest.locale,
            totalActiveDurationMs: manifest.totalActiveDuration.inMilliseconds,
            segments: segments,
          ),
        );
      }
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
    final activeDuration = _session == null
        ? Duration.zero
        : _session!.activeDurationAt(now);

    final status = _stoppedManifest != null
        ? 'Finalizado'
        : (_paused
            ? 'Pausado'
            : (_recording
                ? (isEs ? 'Grabando' : 'Gravando')
                : (isEs ? 'Listo' : 'Pronto')));

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
          onPressed: _busy ? null : () => Navigator.maybePop(context),
          icon: Icon(
            Icons.chevron_left_rounded,
            size: 23,
            color: palette.text,
          ),
        ),
        title: Text(
          isEs ? 'Grabar clase' : 'Gravar aula',
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
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            18 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            children: [
              Text(
                isEs
                    ? 'Captura una clase larga y conviértela después en material de estudio.'
                    : 'Capture uma aula longa e transforme depois em material de estudo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.secondary,
                  fontSize: 11.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              _PremiumRecorderOrb(
              levelReader: () async {
                final provider = _visualAudioProvider;
                if (provider == null || !_recording || _paused) {
                  return -160.0;
                }
                return provider.currentAmplitudeDbfs();
              },
                active: _recording,
                paused: _paused,
                palette: palette,
              ),
              const SizedBox(height: 24),
              Text(
                _formatDuration(activeDuration.inSeconds),
                style: TextStyle(
                  color: palette.text,
                  fontSize: 42,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.6,
                  height: 1,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                status,
                style: TextStyle(
                  color: _recording ? palette.accent : palette.secondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_error != null) ...[
                _RuntimeError(palette: palette, text: _error!),
                const SizedBox(height: 10),
              ],
              if (_session == null)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _start,
                    icon: const Icon(
                      Icons.fiber_manual_record_rounded,
                      size: 17,
                    ),
                    label: Text(
                      isEs ? 'Iniciar grabación' : 'Iniciar gravação',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      backgroundColor: palette.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: _busy || _stoppedManifest != null
                              ? null
                              : (_paused ? _resume : _pause),
                          icon: Icon(
                            _paused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _paused
                                ? (isEs ? 'Reanudar' : 'Retomar')
                                : 'Pausar',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: FilledButton.icon(
                          onPressed: !_busy &&
                                  _session != null &&
                                  _stoppedManifest == null
                              ? _stop
                              : null,
                          icon: const Icon(
                            Icons.stop_rounded,
                            size: 18,
                          ),
                          label: const Text(
                            'Finalizar',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            elevation: 0,
                            backgroundColor: const Color(0xFF111827),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: palette.secondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isEs
                          ? 'El audio permanece local durante la captura y revisión.'
                          : 'O áudio permanece local durante a captura e revisão.',
                      style: TextStyle(
                        color: palette.secondary,
                        fontSize: 9.8,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _PremiumRecorderOrb extends StatefulWidget {
  final Future<double> Function()? levelReader;
  const _PremiumRecorderOrb({
    this.levelReader,
    required this.active,
    required this.paused,
    required this.palette,
  });

  final bool active;
  final bool paused;
  final _AudioRuntimePalette palette;

  @override
  State<_PremiumRecorderOrb> createState() => _PremiumRecorderOrbState();
}

class _PremiumRecorderOrbState extends State<_PremiumRecorderOrb> with TickerProviderStateMixin {
  late final AnimationController _orbitController;
  late final AnimationController _breathController;
  late final AnimationController _waveController;
  Timer? _meterTimer;
  double _smoothedLevel = 0.0;

  bool get _isActive => widget.active;
  bool get _isPaused => widget.paused;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
    _breathController = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..repeat(reverse: true);
    _waveController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..repeat();
    _syncMeter();
  }

  @override
  void didUpdateWidget(covariant _PremiumRecorderOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isActive != (oldWidget.active) || _isPaused != (oldWidget.paused)) {
      _syncMeter();
    }
  }

  void _syncMeter() {
    _meterTimer?.cancel();
    _meterTimer = null;
    if (!_isActive || _isPaused || widget.levelReader == null) {
      _smoothedLevel *= 0.35;
      return;
    }
    _meterTimer = Timer.periodic(const Duration(milliseconds: 180), (_) async {
      final reader = widget.levelReader;
      if (reader == null || !_isActive || _isPaused) return;
      try {
        final db = await reader();
        if (!mounted) return;
        final level = ((db + 58.0) / 58.0).clamp(0.0, 1.0);
        setState(() => _smoothedLevel = (_smoothedLevel * 0.72) + (level * 0.28));
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _meterTimer?.cancel();
    _orbitController.dispose();
    _breathController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final diameter = (width * 0.76).clamp(272.0, 324.0);
    final canvasSize = diameter + 72.0;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: canvasSize,
        child: AnimatedBuilder(
          animation: Listenable.merge([_orbitController, _breathController, _waveController]),
          builder: (context, _) {
            final active = _isActive && !_isPaused;
            final breath = 0.5 - 0.5 * math.cos(_breathController.value * math.pi);
            final floor = active ? 0.08 + breath * 0.06 : 0.025;
            final reactive = active ? math.max(floor, _smoothedLevel) : 0.025;
            return CustomPaint(
              painter: _AudioReactiveOrbPainter(
                orbitT: _orbitController.value,
                waveT: _waveController.value,
                breath: breath,
                activity: reactive,
                active: active,
                paused: _isPaused,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class _AudioReactiveOrbPainter extends CustomPainter {
  final double orbitT;
  final double waveT;
  final double breath;
  final double activity;
  final bool active;
  final bool paused;
  const _AudioReactiveOrbPainter({required this.orbitT, required this.waveT, required this.breath, required this.activity, required this.active, required this.paused});

  @override
  void paint(Canvas canvas, Size size) {
    final center=size.center(Offset.zero);
    final shortest=math.min(size.width,size.height);
    final orbRadius=shortest*0.355;
    final ringBase=orbRadius*1.17;
    final phase=waveT*math.pi*2.0;
    final orbit=orbitT*math.pi*2.0;
    final live=active?activity.clamp(0.0,1.0):0.03;
    final pulse=1.0+(active?(0.010+live*0.018):0.004)*breath;
    canvas.save();
    canvas.translate(center.dx,center.dy);
    _paintAmbientGlow(canvas,orbRadius,live);
    _paintOrbitRings(canvas,ringBase,orbit,live);
    _paintOrb(canvas,orbRadius*pulse,live);
    _paintStars(canvas,orbRadius,orbit,live);
    _paintWave(canvas,orbRadius*0.88,phase,live);
    canvas.restore();
  }

  void _paintAmbientGlow(Canvas canvas,double r,double live) {
    final p=Paint()..shader=RadialGradient(colors:[const Color(0xFF55F6EA).withValues(alpha: 0.10+live*0.08),const Color(0xFF6196FF).withValues(alpha: 0.07+live*0.07),const Color(0xFFA855F7).withValues(alpha: 0.04+live*0.06),Colors.transparent],stops:const[0.0,0.42,0.72,1.0]).createShader(Rect.fromCircle(center:Offset.zero,radius:r*1.62));
    canvas.drawCircle(Offset.zero,r*1.62,p);
  }

  void _paintOrbitRings(Canvas canvas,double r,double orbit,double live) {
    const colors=[Color(0xFF38E8E1),Color(0xFF60A5FA),Color(0xFFA78BFA),Color(0xFF7DD3FC)];
    for(var i=0;i<5;i++){
      final rr=r+i*9.5;
      canvas.drawCircle(Offset.zero,rr,Paint()..style=PaintingStyle.stroke..strokeWidth=i==1?1.15:0.75..color=colors[i%colors.length].withValues(alpha: 0.11+(4-i)*0.018+live*0.045));
      final seg=Paint()..style=PaintingStyle.stroke..strokeCap=StrokeCap.round..strokeWidth=i==0?1.65:1.0..color=colors[i%colors.length].withValues(alpha: 0.34+live*0.22);
      final shift=orbit*(i.isEven?1.0:-0.72)+i*0.91;
      for(var j=0;j<3;j++){
        canvas.drawArc(Rect.fromCircle(center:Offset.zero,radius:rr),shift+j*2.08,0.18+j*0.055,false,seg);
      }
    }
    for(var i=0;i<7;i++){
      final rr=r+(i%4)*9.5; final a=orbit*(0.55+i*0.08)+i*0.93; final pt=Offset(math.cos(a)*rr,math.sin(a)*rr); final col=colors[i%colors.length];
      canvas.drawCircle(pt,i%3==0?2.4:1.35,Paint()..color=col.withValues(alpha: 0.70));
      canvas.drawCircle(pt,5.0,Paint()..color=col.withValues(alpha: 0.14)..maskFilter=const MaskFilter.blur(BlurStyle.normal,5));
    }
  }

  void _paintOrb(Canvas canvas,double r,double live) {
    canvas.drawCircle(Offset.zero,r+4,Paint()..color=const Color(0xFF38E8E1).withValues(alpha: 0.10+live*0.08)..maskFilter=MaskFilter.blur(BlurStyle.normal,22+live*16));
    final fill=Paint()..shader=RadialGradient(center:const Alignment(-0.30,-0.38),radius:1.12,colors:[const Color(0xFF183D52).withValues(alpha: 0.96),const Color(0xFF10283C).withValues(alpha: 0.98),const Color(0xFF101C35),const Color(0xFF151936)],stops:const[0.0,0.40,0.72,1.0]).createShader(Rect.fromCircle(center:Offset.zero,radius:r));
    canvas.drawCircle(Offset.zero,r,fill);
    final rim=Paint()..style=PaintingStyle.stroke..strokeWidth=3.0..shader=SweepGradient(colors:const[Color(0xFF54F5E6),Color(0xFF55C8FF),Color(0xFF7A9BFF),Color(0xFFC260FF),Color(0xFF8B5CF6),Color(0xFF54F5E6)]).createShader(Rect.fromCircle(center:Offset.zero,radius:r));
    canvas.drawCircle(Offset.zero,r-1.5,rim);
    canvas.drawCircle(Offset.zero,r-5.5,Paint()..style=PaintingStyle.stroke..strokeWidth=0.7..color=Colors.white.withValues(alpha: 0.20));
    final sheen=Paint()..shader=RadialGradient(center:const Alignment(-0.48,-0.55),radius:0.72,colors:[Colors.white.withValues(alpha: 0.13+live*0.04),const Color(0xFF4BE8E0).withValues(alpha: 0.055),Colors.transparent]).createShader(Rect.fromCircle(center:Offset.zero,radius:r));
    canvas.drawCircle(Offset.zero,r-7,sheen);
  }

  void _paintWave(Canvas canvas,double r,double phase,double live) {
    canvas.save(); canvas.clipPath(Path()..addOval(Rect.fromCircle(center:Offset.zero,radius:r)));
    final amp=r*(0.08+live*0.18); final width=r*1.78;
    for(var layer=0;layer<7;layer++){
      final path=Path(); final off=(layer-3)*2.4; final lp=phase*(0.55+layer*0.035)+layer*0.44; final la=amp*(1.0-(layer-3).abs()*0.085);
      for(var step=0;step<=120;step++){
        final t=step/120.0; final x=-width/2+width*t; final env=math.pow(math.sin(math.pi*t),1.28).toDouble();
        final y=math.sin(t*math.pi*4.0+lp)*la*env+math.sin(t*math.pi*7.0-phase*0.31+layer*0.21)*la*0.18*env+off;
        if(step==0){
          path.moveTo(x,y);
        } else {
          path.lineTo(x,y);
        }
      }
      final col=Color.lerp(const Color(0xFF4DEDE1),const Color(0xFFA855F7),layer/6.0)!;
      canvas.drawPath(path,Paint()..style=PaintingStyle.stroke..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round..strokeWidth=layer==3?1.55:0.72..color=col.withValues(alpha: (layer==3?0.92:0.34)+live*0.06));
    }
    canvas.restore();
  }

  void _paintStars(Canvas canvas,double r,double orbit,double live) {
    const stars=[Offset(-0.37,-0.40),Offset(0.31,-0.52),Offset(-0.55,0.13),Offset(0.56,0.20),Offset(-0.15,0.48),Offset(0.19,0.35)];
    for(var i=0;i<stars.length;i++){
      final tw=0.55+0.45*math.sin(orbit*2.0+i*1.1).abs(); final col=(i.isEven?const Color(0xFF67E8F9):const Color(0xFFC4B5FD)).withValues(alpha: 0.42+tw*0.42+live*0.08);
      canvas.drawCircle(Offset(stars[i].dx*r,stars[i].dy*r),0.9+tw*0.8,Paint()..color=col);
    }
  }

  @override
  bool shouldRepaint(covariant _AudioReactiveOrbPainter oldDelegate)=>oldDelegate.orbitT!=orbitT||oldDelegate.waveT!=waveT||oldDelegate.breath!=breath||oldDelegate.activity!=activity||oldDelegate.active!=active||oldDelegate.paused!=paused;
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
          icon: Icon(Icons.chevron_left_rounded, size: 23, color: palette.text),
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
          Icon(Icons.graphic_eq_rounded, size: 18, color: palette.accent),
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
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
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
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote({required this.palette, required this.text});

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
  const _RuntimeError({required this.palette, required this.text});

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
