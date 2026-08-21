// clinical_recorder_service.dart
//
// Gravador Clínico Inteligente Multimodal — MedCases Pro Build 331+
//
// Arquitetura:
//   • speech_to_text nativo (SttHelper) em sessões auto-reiniciadas de 55s
//   • Chunks acumulam texto bruto; flushed automaticamente a cada 60s
//   • Stream<String> transcriptStream emite increments em tempo real
//   • Timer de segurança: para automaticamente após _maxDurationSec (900s = 15min)
//   • dispose() cancela todos os timers e subscriptions — zero memory leak
//
// Integração:
//   • ClinicalRecorderScreen usa transcriptStream para exibir texto crescendo
//   • SoapAiProcessor.structure() converte texto bruto → SoapData
//   • OcrExamScanner usa GeminiService com inlineData base64 → texto estruturado
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'stt_helper.dart';

// ── Modos de gravação ──────────────────────────────────────────────────────────
enum RecorderMode {
  continuous, // 🎙️ Gravar consulta e transcrever tudo
  manual, // 📝 Digitar manualmente (não usa gravador)
  soapBlocks, // 🧱 Gravar por blocos SOAP focados
}

// ── Bloco SOAP nomeado (para modo soapBlocks) ──────────────────────────────────
enum SoapBlock { subjective, objective, assessment, plan, medications, exams }

extension SoapBlockLabel on SoapBlock {
  String get label {
    switch (this) {
      case SoapBlock.subjective:
        return 'Subjetivo (Queixas / Sintomas)';
      case SoapBlock.objective:
        return 'Objetivo (Sinais Vitais / Exame Físico)';
      case SoapBlock.assessment:
        return 'Avaliação (Hipóteses / Diagnóstico)';
      case SoapBlock.plan:
        return 'Plano (Condutas / Tratamento)';
      case SoapBlock.medications:
        return 'Medicações (Nomes e Dosagens)';
      case SoapBlock.exams:
        return 'Exames (Pedidos / Resultados)';
    }
  }

  String get emoji {
    switch (this) {
      case SoapBlock.subjective:
        return '🗣️';
      case SoapBlock.objective:
        return '🩺';
      case SoapBlock.assessment:
        return '🧠';
      case SoapBlock.plan:
        return '📋';
      case SoapBlock.medications:
        return '💊';
      case SoapBlock.exams:
        return '🔬';
    }
  }
}

// ── SOAP estruturado (resultado final após processamento IA) ──────────────────
class SoapData {
  final String subjective;
  final String objective;
  final String assessment;
  final String plan;
  final String medications;
  final String exams;
  final String rawTranscript;

  const SoapData({
    this.subjective = '',
    this.objective = '',
    this.assessment = '',
    this.plan = '',
    this.medications = '',
    this.exams = '',
    this.rawTranscript = '',
  });

  bool get isEmpty =>
      subjective.isEmpty &&
      objective.isEmpty &&
      assessment.isEmpty &&
      plan.isEmpty &&
      medications.isEmpty &&
      exams.isEmpty;

  SoapData copyWith({
    String? subjective,
    String? objective,
    String? assessment,
    String? plan,
    String? medications,
    String? exams,
    String? rawTranscript,
  }) =>
      SoapData(
        subjective: subjective ?? this.subjective,
        objective: objective ?? this.objective,
        assessment: assessment ?? this.assessment,
        plan: plan ?? this.plan,
        medications: medications ?? this.medications,
        exams: exams ?? this.exams,
        rawTranscript: rawTranscript ?? this.rawTranscript,
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// ClinicalRecorderService — motor de gravação contínua
// ═══════════════════════════════════════════════════════════════════════════════
class ClinicalRecorderService {
  // ── Configuração ──────────────────────────────────────────────────────────
  static const int _maxDurationSec = 900; // 15 minutos
  static const int _sessionLimitSec =
      55; // STT reinicia a cada 55s (evita timeout iOS)

  // ── Estado público (observável via getters) ────────────────────────────────
  bool _isRecording = false;
  bool _isPaused = false;
  int _elapsedSec = 0;
  String _fullTranscript = '';
  String _currentLang = 'pt_BR';

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  int get elapsedSec => _elapsedSec;
  String get fullTranscript => _fullTranscript;
  String get partialTranscript => _partialTranscript;

  // R1 final — observabilidade de áudio para a UI. Não altera reconhecimento,
  // reconciliação parcial/final, reinício, pause, stop ou locale.
  final _soundLevelCtrl = StreamController<double>.broadcast();
  Stream<double> get soundLevelStream => _soundLevelCtrl.stream;

  // ── Streams ────────────────────────────────────────────────────────────────
  // transcriptStream: cada evento é o transcript COMPLETO acumulado até agora
  final _transcriptCtrl = StreamController<String>.broadcast();
  Stream<String> get transcriptStream => _transcriptCtrl.stream;

  // stateStream: emite true quando gravando, false quando parado
  final _stateCtrl = StreamController<bool>.broadcast();
  Stream<bool> get stateStream => _stateCtrl.stream;

  // ── Timers internos ────────────────────────────────────────────────────────
  Timer? _elapsedTimer; // conta segundos
  Timer? _maxTimer; // para ao atingir 15min
  Timer? _sessionTimer; // reinicia sessão STT a cada 55s

  // BUILD 335 — wall-clock anchor para _elapsedSec
  DateTime? _elapsedAnchor; // DateTime.now() ao (re)iniciar contagem
  int _elapsedSecBase = 0; // segundos acumulados antes da pausa

  // Buffer da sessão STT atual (descartado ao reiniciar sessão)
  String _partialTranscript = '';

  // AUDIO V1-A-R1 — ownership e serialização da sessão STT.
  Timer? _restartTimer;
  int _sessionEpoch = 0;
  int _terminalEpoch = -1;
  int _lastFinalEpoch = -1;
  String _lastFinalText = '';
  bool _disposed = false;
  bool _startInFlight = false;
  bool _stopRequested = false;
  bool _pauseStopInFlight = false;
  bool _resumeInFlight = false;
  Future<void>? _pauseFuture;

  String _normalizeSegment(String value) =>
      value.trim().replaceAll(RegExp(r'[ \t]+'), ' ');

  String _joinTranscript(String base, String segment) {
    final left = base.trimRight();
    final right = _normalizeSegment(segment);
    if (right.isEmpty) return left;
    if (left.isEmpty) return right;
    return '$left $right';
  }

  String get _liveTranscript =>
      _joinTranscript(_fullTranscript, _partialTranscript);

  bool _isCurrentSession(int epoch) => !_disposed && epoch == _sessionEpoch;

  bool _acceptsResult(int epoch) =>
      _isCurrentSession(epoch) &&
      _isRecording &&
      (!_isPaused || _pauseStopInFlight);

  void _emitTranscript() {
    if (_disposed || _transcriptCtrl.isClosed) return;
    _transcriptCtrl.add(_liveTranscript);
  }

  void _commitFinal(int epoch, String text) {
    if (!_acceptsResult(epoch)) return;
    final segment = _normalizeSegment(text);
    if (segment.isEmpty) return;

    // O final substitui a hipótese parcial da mesma sessão; nunca concatena
    // os callbacks parciais acumulativos do provider.
    _partialTranscript = '';
    if (_lastFinalEpoch == epoch && _lastFinalText == segment) {
      _emitTranscript();
      return;
    }

    _lastFinalEpoch = epoch;
    _lastFinalText = segment;
    _fullTranscript = _joinTranscript(_fullTranscript, segment);
    _emitTranscript();
  }

  void _scheduleRestart(int sourceEpoch, Duration delay) {
    if (!_isCurrentSession(sourceEpoch) ||
        !_isRecording ||
        _isPaused ||
        _stopRequested) {
      return;
    }

    _restartTimer?.cancel();
    _restartTimer = Timer(delay, () {
      _restartTimer = null;
      if (!_isCurrentSession(sourceEpoch) ||
          !_isRecording ||
          _isPaused ||
          _stopRequested) {
        return;
      }
      if (_startInFlight) {
        _scheduleRestart(sourceEpoch, const Duration(milliseconds: 100));
        return;
      }
      unawaited(_startSttSession());
    });
  }

  Future<void> _rotateSession(int epoch) async {
    if (!_isCurrentSession(epoch) ||
        !_isRecording ||
        _isPaused ||
        _stopRequested) {
      return;
    }

    _sessionTimer?.cancel();
    await SttHelper.stop();

    if (_isCurrentSession(epoch) &&
        _isRecording &&
        !_isPaused &&
        !_stopRequested) {
      // Cancela qualquer restart agendado por onEnd e mantém um único owner.
      _scheduleRestart(epoch, const Duration(milliseconds: 300));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // start() — inicia gravação contínua no idioma especificado
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> start({String lang = 'pt_BR'}) async {
    if (_isRecording || _disposed) return;
    _currentLang = lang;
    _isRecording = true;
    _isPaused = false;
    _stopRequested = false;
    _pauseStopInFlight = false;
    _resumeInFlight = false;
    _pauseFuture = null;
    _elapsedSec = 0;
    _elapsedSecBase = 0; // BUILD 335: reset acumulador
    _fullTranscript = '';
    _partialTranscript = '';
    _lastFinalEpoch = -1;
    _lastFinalText = '';
    _restartTimer?.cancel();

    if (!_stateCtrl.isClosed) _stateCtrl.add(true);

    _startElapsedTimer();
    _startMaxTimer();
    await _startSttSession();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // pause() / resume()
  // ─────────────────────────────────────────────────────────────────────────
  void pause() {
    if (!_isRecording || _isPaused || _disposed) return;

    final anchor = _elapsedAnchor;
    if (anchor != null) {
      _elapsedSecBase =
          (_elapsedSecBase + DateTime.now().difference(anchor).inSeconds)
              .clamp(0, _maxDurationSec);
      _elapsedAnchor = null;
    }

    _isPaused = true;
    _pauseStopInFlight = true;
    _elapsedTimer?.cancel();
    _sessionTimer?.cancel();
    _restartTimer?.cancel();

    final epoch = _sessionEpoch;
    _pauseFuture = _stopForPause(epoch);
  }

  Future<void> _stopForPause(int epoch) async {
    try {
      // Mantém a sessão válida durante stop() para aceitar o resultado final.
      await SttHelper.stop();
    } finally {
      if (_isCurrentSession(epoch)) {
        _pauseStopInFlight = false;
        _partialTranscript = '';
        _emitTranscript();
      }
    }
  }

  void resume() {
    if (!_isRecording ||
        !_isPaused ||
        _disposed ||
        _resumeInFlight ||
        _stopRequested) {
      return;
    }
    _resumeInFlight = true;
    unawaited(_resumeAfterPause());
  }

  Future<void> _resumeAfterPause() async {
    try {
      final pauseFuture = _pauseFuture;
      if (pauseFuture != null) await pauseFuture;
      if (_disposed || !_isRecording || !_isPaused || _stopRequested) return;

      _isPaused = false;
      _startElapsedTimer();
      await _startSttSession();
    } finally {
      _resumeInFlight = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // stop() — para e retorna transcript completo
  // ─────────────────────────────────────────────────────────────────────────
  Future<String> stop() async {
    if (!_isRecording) return _fullTranscript;

    final anchor = _elapsedAnchor;
    if (anchor != null && !_isPaused) {
      _elapsedSec =
          (_elapsedSecBase + DateTime.now().difference(anchor).inSeconds)
              .clamp(0, _maxDurationSec);
    }
    _elapsedAnchor = null;

    // Não invalida a sessão antes de stop(): o provider ainda pode entregar
    // as últimas palavras como resultado final durante o await.
    _stopRequested = true;
    _elapsedTimer?.cancel();
    _maxTimer?.cancel();
    _sessionTimer?.cancel();
    _restartTimer?.cancel();

    final pauseFuture = _pauseFuture;
    if (pauseFuture != null) await pauseFuture;
    await SttHelper.stop();

    if (_disposed) return _fullTranscript;

    _sessionEpoch++;
    _isRecording = false;
    _isPaused = false;
    _pauseStopInFlight = false;
    _partialTranscript = '';

    if (!_stateCtrl.isClosed) _stateCtrl.add(false);
    _emitTranscript();
    return _fullTranscript;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // dispose() — libera todos os recursos (zero memory leak)
  // ─────────────────────────────────────────────────────────────────────────
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stopRequested = true;
    _isRecording = false;
    _isPaused = false;
    _sessionEpoch++;

    _elapsedTimer?.cancel();
    _maxTimer?.cancel();
    _sessionTimer?.cancel();
    _restartTimer?.cancel();
    unawaited(SttHelper.stop());

    if (!_transcriptCtrl.isClosed) _transcriptCtrl.close();
    if (!_stateCtrl.isClosed) _stateCtrl.close();
    if (!_soundLevelCtrl.isClosed) _soundLevelCtrl.close();
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    // BUILD 335: ancora wall-clock para calcular delta real em cada tick
    _elapsedAnchor = DateTime.now();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final anchor = _elapsedAnchor;
      if (anchor == null) return;
      _elapsedSec =
          (_elapsedSecBase + DateTime.now().difference(anchor).inSeconds)
              .clamp(0, _maxDurationSec);
    });
  }

  void _startMaxTimer() {
    _maxTimer?.cancel();
    _maxTimer = Timer(Duration(seconds: _maxDurationSec), () async {
      debugPrint(
          '[ClinicalRecorder] Limite de 15 min atingido — parando automaticamente');
      await stop();
    });
  }

  Future<void> _startSttSession() async {
    if (_disposed ||
        !_isRecording ||
        _isPaused ||
        _stopRequested ||
        _startInFlight) {
      return;
    }

    _startInFlight = true;
    _sessionTimer?.cancel();
    _restartTimer?.cancel();
    _restartTimer = null;

    final epoch = ++_sessionEpoch;
    _terminalEpoch = -1;
    _partialTranscript = '';
    _emitTranscript();

    final locale =
        _currentLang.toLowerCase().startsWith('es') ? 'es-ES' : 'pt-BR';

    try {
      await SttHelper.start(
        locale: locale,
        onPartialResult: (text) {
          if (!_acceptsResult(epoch)) return;
          final partial = _normalizeSegment(text);
          if (partial == _partialTranscript) return;
          _partialTranscript = partial;
          _emitTranscript();
        },
        onResult: (text) {
          _commitFinal(epoch, text);
        },
        onSoundLevelChange: (level) {
          if (!_isCurrentSession(epoch) || _soundLevelCtrl.isClosed) return;
          final normalized = level.clamp(0.0, 1.0).toDouble();
          _soundLevelCtrl.add(normalized);
        },
        onError: (err) {
          if (!_isCurrentSession(epoch)) return;
          // Somente código técnico; nunca registrar a transcrição clínica.
          debugPrint(
            '[ClinicalRecorder] STT error code=$err session=$epoch',
          );
        },
        onEnd: () {
          if (!_isCurrentSession(epoch)) return;
          _terminalEpoch = epoch;
          _partialTranscript = '';
          _emitTranscript();

          if (_isRecording && !_isPaused && !_stopRequested) {
            _scheduleRestart(epoch, const Duration(milliseconds: 300));
          }
        },
      );
    } catch (e, st) {
      if (_isCurrentSession(epoch)) {
        debugPrint(
          '[ClinicalRecorder] STT start exception=${e.runtimeType} '
          'session=$epoch\n$st',
        );
        _scheduleRestart(epoch, const Duration(milliseconds: 800));
      }
    } finally {
      _startInFlight = false;
    }

    if (!_isCurrentSession(epoch) ||
        !_isRecording ||
        _isPaused ||
        _stopRequested ||
        _terminalEpoch == epoch) {
      return;
    }

    _sessionTimer = Timer(
      const Duration(seconds: _sessionLimitSec),
      () => unawaited(_rotateSession(epoch)),
    );
  }

  // ── Formatação do tempo ────────────────────────────────────────────────────
  static String formatTime(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
