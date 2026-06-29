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
  continuous,   // 🎙️ Gravar consulta e transcrever tudo
  manual,       // 📝 Digitar manualmente (não usa gravador)
  soapBlocks,   // 🧱 Gravar por blocos SOAP focados
}

// ── Bloco SOAP nomeado (para modo soapBlocks) ──────────────────────────────────
enum SoapBlock { subjective, objective, assessment, plan, medications, exams }

extension SoapBlockLabel on SoapBlock {
  String get label {
    switch (this) {
      case SoapBlock.subjective:   return 'Subjetivo (Queixas / Sintomas)';
      case SoapBlock.objective:    return 'Objetivo (Sinais Vitais / Exame Físico)';
      case SoapBlock.assessment:   return 'Avaliação (Hipóteses / Diagnóstico)';
      case SoapBlock.plan:         return 'Plano (Condutas / Tratamento)';
      case SoapBlock.medications:  return 'Medicações (Nomes e Dosagens)';
      case SoapBlock.exams:        return 'Exames (Pedidos / Resultados)';
    }
  }

  String get emoji {
    switch (this) {
      case SoapBlock.subjective:   return '🗣️';
      case SoapBlock.objective:    return '🩺';
      case SoapBlock.assessment:   return '🧠';
      case SoapBlock.plan:         return '📋';
      case SoapBlock.medications:  return '💊';
      case SoapBlock.exams:        return '🔬';
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
      subjective.isEmpty && objective.isEmpty && assessment.isEmpty &&
      plan.isEmpty && medications.isEmpty && exams.isEmpty;

  SoapData copyWith({
    String? subjective, String? objective, String? assessment,
    String? plan, String? medications, String? exams, String? rawTranscript,
  }) => SoapData(
    subjective:    subjective    ?? this.subjective,
    objective:     objective     ?? this.objective,
    assessment:    assessment    ?? this.assessment,
    plan:          plan          ?? this.plan,
    medications:   medications   ?? this.medications,
    exams:         exams         ?? this.exams,
    rawTranscript: rawTranscript ?? this.rawTranscript,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// ClinicalRecorderService — motor de gravação contínua
// ═══════════════════════════════════════════════════════════════════════════════
class ClinicalRecorderService {

  // ── Configuração ──────────────────────────────────────────────────────────
  static const int _maxDurationSec  = 900;  // 15 minutos
  static const int _sessionLimitSec = 55;   // STT reinicia a cada 55s (evita timeout iOS)

  // ── Estado público (observável via getters) ────────────────────────────────
  bool _isRecording   = false;
  bool _isPaused      = false;
  int  _elapsedSec    = 0;
  String _fullTranscript = '';
  String _currentLang    = 'pt_BR';

  bool   get isRecording    => _isRecording;
  bool   get isPaused       => _isPaused;
  int    get elapsedSec     => _elapsedSec;
  String get fullTranscript => _fullTranscript;

  // ── Streams ────────────────────────────────────────────────────────────────
  // transcriptStream: cada evento é o transcript COMPLETO acumulado até agora
  final _transcriptCtrl = StreamController<String>.broadcast();
  Stream<String> get transcriptStream => _transcriptCtrl.stream;

  // stateStream: emite true quando gravando, false quando parado
  final _stateCtrl = StreamController<bool>.broadcast();
  Stream<bool> get stateStream => _stateCtrl.stream;

  // ── Timers internos ────────────────────────────────────────────────────────
  Timer? _elapsedTimer;   // conta segundos
  Timer? _maxTimer;       // para ao atingir 15min
  Timer? _sessionTimer;   // reinicia sessão STT a cada 55s

  // Buffer da sessão STT atual (descartado ao reiniciar sessão)
  final StringBuffer _sessionBuffer = StringBuffer();

  // ─────────────────────────────────────────────────────────────────────────
  // start() — inicia gravação contínua no idioma especificado
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> start({String lang = 'pt_BR'}) async {
    if (_isRecording) return;
    _currentLang = lang;
    _isRecording = true;
    _isPaused    = false;
    _elapsedSec  = 0;
    _fullTranscript = '';
    _sessionBuffer.clear();
    _stateCtrl.add(true);

    _startElapsedTimer();
    _startMaxTimer();
    await _startSttSession();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // pause() / resume()
  // ─────────────────────────────────────────────────────────────────────────
  void pause() {
    if (!_isRecording || _isPaused) return;
    _isPaused = true;
    _elapsedTimer?.cancel();
    _sessionTimer?.cancel();
    SttHelper.stop();
    // Flush do buffer da sessão atual para o transcript completo
    final seg = _sessionBuffer.toString().trim();
    if (seg.isNotEmpty) {
      _fullTranscript = (_fullTranscript + ' ' + seg).trim();
      _sessionBuffer.clear();
      _transcriptCtrl.add(_fullTranscript);
    }
  }

  void resume() {
    if (!_isRecording || !_isPaused) return;
    _isPaused = false;
    _startElapsedTimer();
    _startSttSession();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // stop() — para e retorna transcript completo
  // ─────────────────────────────────────────────────────────────────────────
  Future<String> stop() async {
    if (!_isRecording) return _fullTranscript;
    _isRecording = false;
    _isPaused    = false;
    _elapsedTimer?.cancel();
    _maxTimer?.cancel();
    _sessionTimer?.cancel();
    SttHelper.stop();

    // Flush final
    final seg = _sessionBuffer.toString().trim();
    if (seg.isNotEmpty) {
      _fullTranscript = (_fullTranscript + ' ' + seg).trim();
      _sessionBuffer.clear();
    }
    _stateCtrl.add(false);
    _transcriptCtrl.add(_fullTranscript);
    return _fullTranscript;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // dispose() — libera todos os recursos (zero memory leak)
  // ─────────────────────────────────────────────────────────────────────────
  void dispose() {
    _elapsedTimer?.cancel();
    _maxTimer?.cancel();
    _sessionTimer?.cancel();
    SttHelper.stop();
    _transcriptCtrl.close();
    _stateCtrl.close();
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSec++;
    });
  }

  void _startMaxTimer() {
    _maxTimer?.cancel();
    _maxTimer = Timer(Duration(seconds: _maxDurationSec), () async {
      debugPrint('[ClinicalRecorder] Limite de 15 min atingido — parando automaticamente');
      await stop();
    });
  }

  Future<void> _startSttSession() async {
    _sessionTimer?.cancel();
    _sessionBuffer.clear();

    // Configura o locale
    final locale = _currentLang == 'es' ? 'es-ES' : 'pt-BR';

    await SttHelper.start(
      locale: locale,
      onResult: (text) {
        if (!_isRecording || _isPaused) return;
        // Acumula texto no buffer da sessão
        final seg = text.trim();
        if (seg.isNotEmpty) {
          _sessionBuffer.clear();
          _sessionBuffer.write(seg);
          // Emite transcript completo em tempo real
          final live = (_fullTranscript + ' ' + seg).trim();
          _transcriptCtrl.add(live);
        }
      },
      onError: (err) {
        debugPrint('[ClinicalRecorder] STT error: $err — reiniciando sessão');
        if (_isRecording && !_isPaused) {
          // Flush buffer atual e reinicia
          final seg = _sessionBuffer.toString().trim();
          if (seg.isNotEmpty) {
            _fullTranscript = (_fullTranscript + ' ' + seg).trim();
            _sessionBuffer.clear();
          }
          Future.delayed(const Duration(milliseconds: 500), _startSttSession);
        }
      },
      onEnd: () {
        if (_isRecording && !_isPaused) {
          // Sessão STT encerrou (timeout nativo) — flush e reinicia
          final seg = _sessionBuffer.toString().trim();
          if (seg.isNotEmpty) {
            _fullTranscript = (_fullTranscript + ' ' + seg).trim();
            _sessionBuffer.clear();
            _transcriptCtrl.add(_fullTranscript);
          }
          Future.delayed(const Duration(milliseconds: 300), _startSttSession);
        }
      },
    );

    // Timer de reinício preventivo (55s) antes do timeout do iOS
    _sessionTimer = Timer(Duration(seconds: _sessionLimitSec), () {
      if (_isRecording && !_isPaused) {
        debugPrint('[ClinicalRecorder] Reiniciando sessão STT preventivamente (55s)');
        SttHelper.stop();
        final seg = _sessionBuffer.toString().trim();
        if (seg.isNotEmpty) {
          _fullTranscript = (_fullTranscript + ' ' + seg).trim();
          _sessionBuffer.clear();
          _transcriptCtrl.add(_fullTranscript);
        }
        Future.delayed(const Duration(milliseconds: 300), _startSttSession);
      }
    });
  }

  // ── Formatação do tempo ────────────────────────────────────────────────────
  static String formatTime(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
