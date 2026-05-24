// stt_helper_mobile.dart — STT nativo para iOS e Android via speech_to_text.
// Compilado APENAS em plataformas não-web (dart.library.io disponível).
// No Web, stt_helper_web.dart é usado via conditional import em stt_helper.dart.

import 'package:speech_to_text/speech_to_text.dart';

// ── Singleton do SpeechToText ─────────────────────────────────────────────────
// Uma única instância para todo o ciclo de vida — evita conflitos de sessão.
final _stt        = SpeechToText();
bool  _initialized = false;
bool  _listening   = false;

// ── Inicialização lazy ────────────────────────────────────────────────────────
// Na primeira chamada: inicializa + pede permissão ao usuário (iOS/Android).
// iOS: exibe diálogo do sistema com NSMicrophoneUsageDescription do Info.plist.
// Android: exibe diálogo do sistema com RECORD_AUDIO do AndroidManifest.
Future<bool> _ensureInit() async {
  if (_initialized) return true;
  try {
    _initialized = await _stt.initialize(
      onStatus: (_) {},  // mudanças de estado (listening/notListening/done)
      onError:  (_) {},  // erros de sessão — tratados no listen() abaixo
    );
  } catch (_) {
    _initialized = false;
  }
  return _initialized;
}

/// Inicia o reconhecimento de voz nativo (iOS / Android).
Future<void> startSttImpl({
  required String locale,
  required void Function(String text) onResult,
  required void Function(String error) onError,
  required void Function() onEnd,
}) async {
  // Para sessão anterior se ainda estiver ativa
  if (_listening) await stopSttImpl();

  // Inicializa (pede permissão na 1ª vez — iOS/Android)
  final ok = await _ensureInit();
  if (!ok) {
    onError('not_available');
    onEnd();
    return;
  }

  // Verifica disponibilidade (permissão concedida e hardware OK)
  if (!_stt.isAvailable) {
    onError('permission_denied');
    onEnd();
    return;
  }

  try {
    _listening = true;

    await _stt.listen(
      onResult: (result) {
        // finalResult = true: frase completa após pausa detectada
        if (result.finalResult) {
          final text = result.recognizedWords.trim();
          _listening = false;
          if (text.isNotEmpty) {
            onResult(text);
          } else {
            onError('no_speech');
          }
          onEnd();
        }
        // Resultados parciais: ignorados (evita texto instável no campo)
      },
      // ── API moderna: SpeechListenOptions ──────────────────────────────
      listenOptions: SpeechListenOptions(
        // Idioma: pt-BR ou es-ES (BCP-47 — iOS e Android aceitam o mesmo formato)
        localeId: locale,
        // Pausa de silêncio antes de encerrar automaticamente (3s)
        pauseFor: const Duration(seconds: 3),
        // Timeout de segurança — sem isso o microfone ficaria aberto para sempre
        listenFor: const Duration(seconds: 30),
        // Resultados parciais ativados para que o pauseFor funcione corretamente
        partialResults: true,
        // Cancela automaticamente ao detectar erro
        cancelOnError: true,
      ),
    );
  } catch (e) {
    _listening = false;
    onError(e.toString());
    onEnd();
  }
}

/// Para o reconhecimento em andamento.
Future<void> stopSttImpl() async {
  if (!_listening) return;
  try {
    await _stt.stop();
  } catch (_) {}
  _listening = false;
}
