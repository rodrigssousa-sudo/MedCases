// stt_helper_mobile.dart — STT nativo para iOS e Android via speech_to_text.
// Compilado APENAS em plataformas não-web (dart.library.io disponível).
// No Web, stt_helper_web.dart é usado via conditional import em stt_helper.dart.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:speech_to_text/speech_to_text.dart';

// ── Singleton do SpeechToText ─────────────────────────────────────────────────
// Uma única instância para todo o ciclo de vida — evita conflitos de sessão.
final _stt = SpeechToText();

// Estado interno — reiniciável
bool _initialized = false;
bool _listening   = false;

// Callbacks ativos — guardados para que onStatus possa encerrar corretamente
void Function(String)? _onResultCb;
void Function(String)? _onErrorCb;
void Function()?       _onEndCb;

// ── Inicialização lazy ────────────────────────────────────────────────────────
// Na primeira chamada: inicializa + pede permissão ao usuário (iOS/Android).
// iOS : exibe diálogo do sistema com NSMicrophoneUsageDescription do Info.plist.
// Android: exibe diálogo do sistema com RECORD_AUDIO do AndroidManifest.
//
// IMPORTANTE: se o usuário negou a permissão anteriormente, o iOS NÃO exibe
// o diálogo novamente — o app deve orientar o usuário a ir em Ajustes.
Future<bool> _ensureInit() async {
  // Se já inicializado com sucesso E o plugin ainda está funcional → reutiliza
  if (_initialized && _stt.isAvailable) return true;

  // Reseta para tentar novamente (ex: permissão concedida após ter sido negada)
  _initialized = false;

  debugPrint('[STT Mobile] Iniciando SpeechToText.initialize()...');

  try {
    _initialized = await _stt.initialize(
      // onStatus: recebe 'listening', 'notListening', 'done'
      onStatus: (status) {
        debugPrint('[STT Mobile] onStatus: $status');
        if (status == 'done' || status == 'notListening') {
          // O plugin encerrou a sessão (timeout, pausa, etc.)
          if (_listening) {
            _listening = false;
            _onEndCb?.call();
          }
        }
      },
      // onError: erros de sessão — tratados também no listen() abaixo
      onError: (errorNotification) {
        debugPrint('[STT Mobile] onError: ${errorNotification.errorMsg} (permanent: ${errorNotification.permanent})');
        if (_listening) {
          _listening = false;
          final code = _mapErrorCode(errorNotification.errorMsg);
          _onErrorCb?.call(code);
          _onEndCb?.call();
        }
      },
      debugLogging: false,
    );
    debugPrint('[STT Mobile] initialize() → $_initialized | isAvailable: ${_stt.isAvailable}');
  } catch (e) {
    debugPrint('[STT Mobile] initialize() exception: $e');
    _initialized = false;
  }

  return _initialized;
}

/// Mapeia mensagens de erro do plugin para códigos padronizados.
String _mapErrorCode(String raw) {
  final r = raw.toLowerCase();
  if (r.contains('permission'))  return 'permission_denied';
  if (r.contains('not_availab')) return 'not_available';
  if (r.contains('no_speech') || r.contains('no match')) return 'no_speech';
  if (r.contains('network'))     return 'network';
  if (r.contains('audio'))       return 'audio';
  return 'unknown';
}

/// Inicia o reconhecimento de voz nativo (iOS / Android).
Future<void> startSttImpl({
  required String locale,
  required void Function(String text) onResult,
  required void Function(String error) onError,
  required void Function() onEnd,
}) async {
  // Salva callbacks para uso pelo onStatus global
  _onResultCb = onResult;
  _onErrorCb  = onError;
  _onEndCb    = onEnd;

  // Para sessão anterior se ainda estiver ativa
  if (_listening) await stopSttImpl();

  // Inicializa (pede permissão na 1ª vez — iOS/Android)
  final ok = await _ensureInit();
  if (!ok) {
    debugPrint('[STT Mobile] Falha na inicialização — provavelmente permissão negada.');
    onError('permission_denied');
    onEnd();
    return;
  }

  // Verifica se o reconhecimento de voz está realmente disponível
  // (hardware OK + permissão concedida + serviço do sistema ativo)
  if (!_stt.isAvailable) {
    debugPrint('[STT Mobile] isAvailable=false após init — verificar permissão ou hardware.');
    onError('permission_denied');
    onEnd();
    return;
  }

  debugPrint('[STT Mobile] Iniciando listen() — locale: $locale');

  try {
    _listening = true;

    final started = await _stt.listen(
      onResult: (result) {
        debugPrint('[STT Mobile] onResult: "${result.recognizedWords}" final=${result.finalResult}');

        if (result.finalResult) {
          final text = result.recognizedWords.trim();
          _listening = false;
          // Limpa callbacks antes de chamar para evitar dupla chamada pelo onStatus
          final cbResult = _onResultCb;
          final cbEnd    = _onEndCb;
          _onResultCb = null;
          _onEndCb    = null;

          if (text.isNotEmpty) {
            cbResult?.call(text);
          } else {
            _onErrorCb?.call('no_speech');
          }
          cbEnd?.call();
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

    if (!started) {
      // O plugin recusou iniciar (ex: outra sessão ativa, permissão negada)
      debugPrint('[STT Mobile] listen() retornou false — sessão não iniciada.');
      _listening = false;
      onError('not_available');
      onEnd();
    }
  } catch (e) {
    debugPrint('[STT Mobile] listen() exception: $e');
    _listening = false;
    onError('unknown');
    onEnd();
  }
}

/// Para o reconhecimento em andamento.
Future<void> stopSttImpl() async {
  if (!_listening && !_stt.isListening) return;
  debugPrint('[STT Mobile] stopSttImpl() chamado.');
  try {
    await _stt.stop();
  } catch (e) {
    debugPrint('[STT Mobile] stop() exception: $e');
  }
  _listening = false;
  // Limpa callbacks
  _onResultCb = null;
  _onErrorCb  = null;
  _onEndCb    = null;
}
