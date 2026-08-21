// ignore_for_file: avoid_web_libraries_in_flutter
// Implementação Web Speech API via dart:html.
// Este arquivo só é compilado no target web (dart2js / wasm).
//
// ── Correção de eco / repetição ────────────────────────────────────────────
//   A Web Speech API com interimResults=true dispara onResult para CADA chunk
//   parcial (ex: "eu", "eu eu", "eu eu fui"). Sem a verificação de isFinal,
//   ai_screen.dart concatenaria cada chunk parcial → "eu eu eu eu eu".
//   FIX: só chama onResult quando firstResult.isFinal == true.
//
// ── Sound level na Web ─────────────────────────────────────────────────────
//   A Web Speech API não expõe nível de microfone nativamente (AudioContext
//   exigiria permissão separada e complexidade adicional). Para dar feedback
//   visual de "microfone ativo", emitimos 0.5 constante a cada 100ms enquanto
//   o reconhecimento estiver ativo, e paramos ao fechar. Isso aciona a onda
//   de áudio no UI no nível médio sem requerer APIs extras.
// ──────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:html' as html;

html.SpeechRecognition? _recognition;
Timer? _levelTimer; // emite nível constante na web enquanto ativo
int _sessionEpoch = 0;

Future<void> startSttImpl({
  required String locale,
  required void Function(String text) onResult,
  required void Function(String error) onError,
  required void Function() onEnd,
  void Function(String text)? onPartialResult,
  void Function(double level)? onSoundLevelChange,
}) async {
  try {
    await stopSttImpl();
    final sessionEpoch = ++_sessionEpoch;
    var ended = false;

    void finishEnd() {
      if (ended || sessionEpoch != _sessionEpoch) return;
      ended = true;
      _stopLevelTimer();
      onSoundLevelChange?.call(0.0);
      _recognition = null;
      onEnd();
    }

    final sr = html.SpeechRecognition();
    _recognition = sr;

    sr.lang = locale;
    sr.interimResults = true; // feedback visual imediato (chunks parciais)
    sr.maxAlternatives = 3; // avalia mais candidatos para maior precisão médica
    sr.continuous = false;

    sr.onResult.listen((event) {
      if (sessionEpoch != _sessionEpoch) return;
      try {
        final results = event.results;
        if (results != null && results.isNotEmpty) {
          final firstResult = results[0];
          final isFinal = firstResult.isFinal ?? false;
          final length = firstResult.length ?? 0;
          if (length > 0) {
            final alt = firstResult.item(0);
            final transcript = (alt.transcript ?? '').trim();
            if (transcript.isEmpty) return;
            if (isFinal) {
              onResult(transcript);
            } else {
              onPartialResult?.call(transcript);
            }
          }
        }
      } catch (_) {}
    });

    sr.onError.listen((event) {
      if (sessionEpoch != _sessionEpoch) return;
      try {
        final dynamic ev = event;
        onError(ev.error?.toString() ?? 'unknown');
      } catch (_) {
        onError('unknown');
      }
      finishEnd();
    });

    sr.onEnd.listen((_) {
      finishEnd();
    });

    sr.start();

    // ── Feedback de nível de som constante (Web Speech API não tem callback)
    // Emite 0.5 a cada 80ms para dar à onda de áudio uma animação suave e
    // contínua enquanto o microfone estiver ativo.
    if (onSoundLevelChange != null) {
      _levelTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
        onSoundLevelChange(0.5);
      });
    }
  } catch (e) {
    _stopLevelTimer();
    onError(e.toString());
    onEnd();
  }
}

void _stopLevelTimer() {
  _levelTimer?.cancel();
  _levelTimer = null;
}

Future<void> stopSttImpl() async {
  _sessionEpoch++;
  _stopLevelTimer();
  final recognition = _recognition;
  _recognition = null;
  try {
    recognition?.stop();
    recognition?.abort();
  } catch (_) {}
}
