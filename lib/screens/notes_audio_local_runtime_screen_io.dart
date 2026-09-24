import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../services/audio/clinical_long_form_audio_contract.dart';
import '../services/audio/clinical_long_form_recording_manifest.dart';
import '../services/audio/clinical_long_form_durable_store.dart';
import '../services/audio/clinical_long_form_recording_session.dart';
import '../services/audio/clinical_long_form_session_directory_layout.dart';
import '../services/audio/record_long_form_audio_provider.dart';
import '../services/clinical_recorder_service.dart';

import '../models/study_long_form_audio_handoff.dart';

import '../services/entitlement_service.dart';
import 'upgrade_screen.dart';
import '../widgets/medcases_audio_recorder_view.dart';

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
          MedCasesAudioRecorderView(
            isEs: isEs,
            state: _busy
                ? AudioRecorderPresentation.processing
                : _error != null
                    ? AudioRecorderPresentation.error
                    : _paused
                        ? AudioRecorderPresentation.paused
                        : _recording
                            ? AudioRecorderPresentation.recording
                            : AudioRecorderPresentation.idle,
            duration: Duration(seconds: _elapsedSeconds),
            waveform: StreamBuilder<double>(
              stream: _recorder.soundLevelStream,
              builder: (context, snapshot) => MedCasesAudioWaveform(
                level:
                    _recording && !_paused && !_busy ? snapshot.data ?? 0 : 0,
              ),
            ),
            showStart: !_recording,
            showPause: _recording,
            pauseIsResume: _paused,
            onStart: _busy ? null : _start,
            onPause: _busy ? null : _pause,
            onResume: _busy ? null : _resume,
            onFinish: !_busy && (_recording || _transcript.trim().isNotEmpty)
                ? _stop
                : null,
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
  @override
  void initState() {
    super.initState();
    _r25aEntitlement.addListener(_r25aEntitlementChanged);
    _r25aEntitlement.refreshAuthoritativeTier();
  }

  // MEDCASES_R25A_ENTITLEMENT_LONGFORM_AUDIO_GATE_V1
  final EntitlementService _r25aEntitlement = EntitlementService.instance;

  void _r25aEntitlementChanged() {
    if (mounted) setState(() {});
  }

  RecordLongFormAudioProvider? _visualAudioProvider;
  ClinicalLongFormRecordingSession? _session;
  ClinicalLongFormSessionDirectoryLayout? _layout;
  ClinicalLongFormDurableStore? _durableStore;
  ClinicalLongFormRecordingManifest? _stoppedManifest;
  Timer? _ticker;

  bool _busy = false;
  bool _rotationInFlight = false;
  bool _stopRequested = false;
  int _segmentIndex = 0;
  String? _error;

  bool get _recording =>
      _session?.state == ClinicalLongFormRecordingState.recording;

  bool get _paused => _session?.state == ClinicalLongFormRecordingState.paused;

  @override
  void dispose() {
    _r25aEntitlement.removeListener(_r25aEntitlementChanged);

    _ticker?.cancel();
    _stopRequested = true;
    unawaited(_disposeRuntime());
    super.dispose();
  }

  Future<void> _disposeRuntime() async {
    final session = _session;

    while (_busy || _rotationInFlight) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    _busy = true;
    try {
      if (session != null && _stoppedManifest == null) {
        final now = DateTime.now().toUtc();

        if (session.state != ClinicalLongFormRecordingState.stopped) {
          await session.stop(now);
        }

        try {
          await _persistManifest(session.snapshot(now));
        } catch (_) {}
      }

      try {
        await session?.dispose();
      } catch (_) {}
    } finally {
      _busy = false;
    }
  }

  Future<void> _start() async {
    if (_busy || _session != null) return;

    setState(() {
      _busy = true;
      _stopRequested = false;
      _error = null;
      _segmentIndex = 0;
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

      final support = await getApplicationSupportDirectory();
      final root = Directory(
        '${support.path}${Platform.pathSeparator}'
        'medcases_study_recorded_audio_state',
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

      final startedAtUtc = DateTime.now().toUtc();
      await session.start(
        firstSegmentPath: layout.segmentFile(0).path,
        nowUtc: startedAtUtc,
      );

      final durableStore = FileClinicalLongFormDurableStore(
        rootDirectory: root,
      );
      await durableStore.saveManifest(session.snapshot(startedAtUtc));

      _layout = layout;
      _durableStore = durableStore;
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
      _busy = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _tick() async {
    final session = _session;
    final layout = _layout;

    if (!mounted || session == null || layout == null) return;

    final now = DateTime.now().toUtc();

    if (_stopRequested && !_busy && _stoppedManifest == null) {
      await _stop();
      return;
    }

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

    if (_busy ||
        _rotationInFlight ||
        !_recording ||
        session == null ||
        layout == null) {
      return;
    }

    _rotationInFlight = true;
    if (mounted) {
      setState(() {});
    }

    try {
      final nextIndex = _segmentIndex + 1;

      await session.rotate(
        nextSegmentPath: layout.segmentFile(nextIndex).path,
        nowUtc: nowUtc,
        shouldStopAfterCurrentSegment: () => _stopRequested,
      );

      if (session.state == ClinicalLongFormRecordingState.recording) {
        _segmentIndex = nextIndex;
      } else {
        _ticker?.cancel();
      }

      try {
        await _persistSessionSnapshot(DateTime.now().toUtc());
      } catch (error) {
        _error = 'recording_manifest_checkpoint_failed:$error';
      }
    } catch (error) {
      _error = '$error';
    } finally {
      _rotationInFlight = false;
      if (mounted) {
        setState(() {});
      }
    }

    if (_stopRequested && _stoppedManifest == null) {
      await _stop();
    }
  }

  Future<void> _pause() async {
    final session = _session;

    if (_busy || _rotationInFlight || !_recording || session == null) return;

    _busy = true;
    if (mounted) {
      setState(() {});
    }

    try {
      final now = DateTime.now().toUtc();
      await session.pause(now);

      try {
        await _persistSessionSnapshot(now);
      } catch (error) {
        _error = 'recording_manifest_checkpoint_failed:$error';
      }
    } catch (error) {
      _error = '$error';
    } finally {
      _busy = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _resume() async {
    final session = _session;

    if (_busy || _rotationInFlight || !_paused || session == null) return;

    _busy = true;
    if (mounted) {
      setState(() {});
    }

    try {
      final now = DateTime.now().toUtc();
      await session.resume(now);

      try {
        await _persistSessionSnapshot(now);
      } catch (error) {
        _error = 'recording_manifest_checkpoint_failed:$error';
      }
    } catch (error) {
      _error = '$error';
    } finally {
      _busy = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _persistManifest(
    ClinicalLongFormRecordingManifest manifest,
  ) async {
    final store = _durableStore;
    if (store == null) return;
    await store.saveManifest(manifest);
  }

  Future<void> _persistSessionSnapshot(DateTime nowUtc) async {
    final session = _session;
    if (session == null ||
        session.state == ClinicalLongFormRecordingState.idle) {
      return;
    }

    await _persistManifest(session.snapshot(nowUtc));
  }

  Future<void> _stop() async {
    final session = _session;

    if (session == null || _stoppedManifest != null) return;

    if (_busy || _rotationInFlight) {
      _stopRequested = true;
      if (mounted) {
        setState(() {});
      }
      return;
    }

    _busy = true;
    _stopRequested = false;
    if (mounted) {
      setState(() {});
    }

    try {
      final now = DateTime.now().toUtc();

      if (session.state != ClinicalLongFormRecordingState.stopped) {
        await session.stop(now);
      }

      _ticker?.cancel();
      final manifest = session.snapshot(now);

      Object? persistenceError;
      try {
        await _persistManifest(manifest);
      } catch (error) {
        persistenceError = error;
      }

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

      if (persistenceError != null) {
        _error = 'recording_manifest_persistence_failed:$persistenceError';
      }
    } catch (error) {
      _error = '$error';
    } finally {
      _busy = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_r25aEntitlement.isResolvedForCurrentUser) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_r25aEntitlement.can(MedCasesCapability.audioLongForm)) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.workspace_premium_outlined, size: 40),
                  const SizedBox(height: 14),
                  const Text(
                    'Gravação longa / Grabación larga',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Disponível no MedCases Premium / '
                    'Disponible en MedCases Premium.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => showUpgradeScreen(
                      context,
                      lang: Localizations.localeOf(context).languageCode == 'pt'
                          ? 'pt'
                          : 'es',
                    ),
                    child: const Text('MedCases Premium'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final palette = _AudioRuntimePalette.of(context);
    final isEs = widget.isEs;
    final now = DateTime.now().toUtc();
    final activeDuration =
        _session == null ? Duration.zero : _session!.activeDurationAt(now);

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
          icon: Icon(Icons.chevron_left_rounded, size: 23, color: palette.text),
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
        child: SingleChildScrollView(
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
              const SizedBox(height: 24),
              MedCasesAudioRecorderView(
                isEs: isEs,
                state: _busy
                    ? AudioRecorderPresentation.processing
                    : _error != null
                        ? AudioRecorderPresentation.error
                        : _stoppedManifest != null
                            ? AudioRecorderPresentation.completed
                            : _paused
                                ? AudioRecorderPresentation.paused
                                : _recording
                                    ? AudioRecorderPresentation.recording
                                    : AudioRecorderPresentation.idle,
                duration: activeDuration,
                waveform: _RecorderLevelMeter(
                  levelReader: () async {
                    final provider = _visualAudioProvider;
                    if (provider == null || !_recording || _paused) {
                      return -160.0;
                    }
                    return provider.currentAmplitudeDbfs();
                  },
                  active: _recording,
                  paused: _paused,
                ),
                error: _error,
                showStart: _session == null,
                showPause: _session != null,
                pauseIsResume: _paused,
                showFinish: _session != null,
                onStart: _busy ? null : _start,
                onPause: _busy || _stoppedManifest != null ? null : _pause,
                onResume: _busy || _stoppedManifest != null ? null : _resume,
                onFinish: !_busy && _session != null && _stoppedManifest == null
                    ? _stop
                    : null,
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

class _RecorderLevelMeter extends StatefulWidget {
  const _RecorderLevelMeter({
    this.levelReader,
    required this.active,
    required this.paused,
  });
  final Future<double> Function()? levelReader;
  final bool active;
  final bool paused;
  @override
  State<_RecorderLevelMeter> createState() => _RecorderLevelMeterState();
}

class _RecorderLevelMeterState extends State<_RecorderLevelMeter> {
  Timer? _meterTimer;
  double _smoothedLevel = 0.0;
  bool get _isActive => widget.active;
  bool get _isPaused => widget.paused;
  @override
  void initState() {
    super.initState();
    _syncMeter();
  }

  @override
  void didUpdateWidget(covariant _RecorderLevelMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isActive != oldWidget.active || _isPaused != oldWidget.paused) {
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
        setState(
          () => _smoothedLevel = (_smoothedLevel * 0.72) + (level * 0.28),
        );
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _meterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MedCasesAudioWaveform(
        level: _isActive && !_isPaused ? _smoothedLevel : 0,
      );
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
