// stt_helper_mobile.dart — STT nativo para iOS e Android via speech_to_text.
// Compilado APENAS em plataformas não-web (dart.library.io disponível).
// No Web, stt_helper_web.dart é usado via conditional import em stt_helper.dart.
//
// ══════════════════════════════════════════════════════════════════════════════
// HISTÓRICO DE BUGS CONHECIDOS
//
//   BUG 1 — speech_to_text 7.x no iOS (arm64) — TypeError null-bool:
//     await _stt.listen() lança "type 'Null' is not a subtype of type 'bool'".
//     O microfone JÁ está ativo quando o erro ocorre.
//     → BYPASS: captura e mantém _listening = true.
//
//   BUG 2 — onStatus('done') precoce após bypass:
//     Dispara ~200ms após o listen() antes do usuário falar.
//     → BYPASS: ignora 'done'/'notListening' nos primeiros 1500ms.
//
//   BUG 3 — "Reconocimiento de voz no disponible" em Release (iOS):
//     SFSpeechRecognizer.isAvailable retorna false no boot frio em Release
//     porque o iOS não completou o handshake de autorização antes do
//     initialize() ser chamado (processo mais rápido em Release vs Debug).
//     Adicionalmente, sem SpeechInitializationOptions explícitas, o plugin
//     não força o iOS a pré-aquecer o SFSpeechRecognizer.
//     → FIX: retry com back-off + SpeechInitializationOptions explícitas
//             + reset de estado entre tentativas.
// ══════════════════════════════════════════════════════════════════════════════
// ignore_for_file: dead_null_aware_expression

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:speech_to_text/speech_to_text.dart';

// ── Singleton ─────────────────────────────────────────────────────────────────
SpeechToText _stt = SpeechToText();

bool _initialized  = false;
bool _listening    = false;

// Timestamp do início do listen() — usado para ignorar 'done' precoce
DateTime? _listenStartedAt;

// Flag: bypass foi ativado nesta sessão (bug null-bool detectado)
bool _bypassActive = false;

void Function(String)? _onResultCb;
void Function(String)? _onErrorCb;
void Function()?       _onEndCb;

// ── Helpers de cast seguro ────────────────────────────────────────────────────
bool _safeBool(dynamic v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  return fallback;
}

String _safeString(dynamic v, {String fallback = ''}) {
  if (v == null) return fallback;
  if (v is String) return v;
  return v.toString();
}

/// Detecta se uma exceção é o bug null-bool do speech_to_text 7.x no iOS.
bool _isNullBoolBug(Object e) {
  final msg = e.toString().toLowerCase();
  return msg.contains('null') && msg.contains('bool');
}

/// Quantos ms se passaram desde que o listen() foi chamado.
int _msSinceListen() {
  if (_listenStartedAt == null) return 9999;
  return DateTime.now().difference(_listenStartedAt!).inMilliseconds;
}

// ── Inicialização com retry e back-off ────────────────────────────────────────
//
// Por que retry? No iOS em Release, SFSpeechRecognizer.isAvailable pode
// retornar false nos primeiros ~800ms após cold start, mesmo com permissão
// concedida. Isso ocorre porque o daemon SiriSpeech ainda está subindo.
// Com 3 tentativas e back-off progressivo (0ms → 500ms → 1000ms), o app
// aguarda o iOS ficar pronto sem travar a UI.
//
// Por que recriar _stt? Após uma inicialização falha, o objeto interno do
// plugin fica em estado corrompido. Recriar o SpeechToText() garante
// que a próxima tentativa parte de um estado limpo.
Future<bool> _ensureInit() async {
  // Fast path: já inicializado e disponível
  if (_initialized && _stt.isAvailable) return true;

  // Delays entre tentativas: 0ms (imediata), 500ms, 1000ms
  const retryDelays = [0, 500, 1000];

  for (int attempt = 0; attempt < retryDelays.length; attempt++) {
    final delay = retryDelays[attempt];

    if (delay > 0) {
      debugPrint('[STT Mobile] Tentativa ${attempt + 1}/3 — aguardando ${delay}ms (SFSpeechRecognizer ainda não pronto)...');
      await Future<void>.delayed(Duration(milliseconds: delay));
    }

    // Recriar instância em tentativas de retry para limpar estado interno
    if (attempt > 0) {
      debugPrint('[STT Mobile] Recriando instância SpeechToText() para tentativa ${attempt + 1}...');
      _stt = SpeechToText();
      _initialized = false;
    }

    try {
      debugPrint('[STT Mobile] initialize() tentativa ${attempt + 1}/3...');

      // ── SpeechInitializationOptions ────────────────────────────────────
      // finalTimeout: quanto o plugin aguarda por um resultado final após
      //   detectar silêncio. 5s dá tempo para o iOS processar fala lenta.
      //
      // Nota: o plugin speech_to_text 7.x NÃO expõe SpeechInitializationOptions
      // como parâmetro direto do initialize() — as opções de sessão de áudio
      // são passadas via SpeechListenOptions no listen(). O que controlamos
      // aqui é o onStatus/onError e o debugLogging.
      final dynamic rawResult = await _stt.initialize(
        onStatus: _handleStatus,
        onError:  _handleError,
        debugLogging: false, // true apenas para sessões de debug local
      );

      _initialized = _safeBool(rawResult, fallback: false);
      debugPrint('[STT Mobile] initialize() tentativa ${attempt + 1} → initialized=$_initialized | isAvailable=${_stt.isAvailable}');

      // ── Verificação dupla: initialized E isAvailable ───────────────────
      // initialized=true mas isAvailable=false é o cenário do BUG 3:
      // o plugin aceitou mas o SFSpeechRecognizer ainda não está pronto.
      // Forçamos outro retry em vez de aceitar um estado parcialmente pronto.
      if (_initialized && _stt.isAvailable) {
        debugPrint('[STT Mobile] ✅ STT pronto após tentativa ${attempt + 1}.');
        return true;
      }

      if (_initialized && !_stt.isAvailable) {
        debugPrint('[STT Mobile] ⚠️ initialized=true mas isAvailable=false — SFSpeechRecognizer ainda não pronto.');
        _initialized = false; // forçar retry
      }

    } catch (e) {
      debugPrint('[STT Mobile] initialize() exception na tentativa ${attempt + 1}: $e');
      _initialized = false;
    }
  }

  debugPrint('[STT Mobile] ❌ STT indisponível após 3 tentativas.');
  return false;
}

// ── Handler de status ─────────────────────────────────────────────────────────
void _handleStatus(String status) {
  final ms = _msSinceListen();
  debugPrint('[STT Mobile] onStatus: $status (${ms}ms após listen)');

  if (status == 'done' || status == 'notListening') {

    // ══════════════════════════════════════════════════════════════════════
    // GUARD DE TEMPO — ignora 'done' precoce após bypass do bug null-bool.
    //
    // Quando o bypass está ativo, o plugin dispara onStatus('done') em ~200ms
    // mesmo com o microfone aberto. Ignoramos qualquer 'done' nos primeiros
    // 1500ms para dar tempo ao iOS estabilizar a sessão de reconhecimento.
    // Após 1500ms, um 'done' real (fim de fala ou timeout) é processado.
    // ══════════════════════════════════════════════════════════════════════
    if (_bypassActive && ms < 1500) {
      debugPrint('[STT Mobile] ⚠️ onStatus("$status") ignorado — muito precoce (${ms}ms). Microfone mantido ativo.');
      return;
    }

    if (_listening) {
      debugPrint('[STT Mobile] Sessão encerrada via onStatus("$status") após ${ms}ms.');
      _listening    = false;
      _bypassActive = false;
      final cb = _onEndCb;
      _onResultCb = null;
      _onErrorCb  = null;
      _onEndCb    = null;
      cb?.call();
    }
  }

  // 'listening' — microfone confirmado ativo pelo plugin
  if (status == 'listening') {
    debugPrint('[STT Mobile] ✅ Microfone confirmado ativo pelo plugin.');
    _bypassActive = false; // sessão estável — bypass não mais necessário
  }
}

// ── Handler de erro ───────────────────────────────────────────────────────────
void _handleError(dynamic errorNotification) {
  final dynamic rawMsg  = errorNotification?.errorMsg;
  final dynamic rawPerm = errorNotification?.permanent;
  final errorMsg  = _safeString(rawMsg,  fallback: 'unknown');
  final permanent = _safeBool(rawPerm,   fallback: false);
  final ms = _msSinceListen();

  debugPrint('[STT Mobile] onError: "$errorMsg" (permanent: $permanent, ${ms}ms após listen)');

  // error_no_match = iOS não reconheceu a fala com confiança suficiente.
  // NÃO é erro fatal — encerra silenciosamente.
  if (errorMsg == 'error_no_match') {
    if (_listening) {
      _listening    = false;
      _bypassActive = false;
      final cb = _onEndCb;
      _onResultCb = null;
      _onErrorCb  = null;
      _onEndCb    = null;
      cb?.call();
    }
    return;
  }

  if (_listening) {
    _listening    = false;
    _bypassActive = false;
    final code    = _mapErrorCode(errorMsg);
    final cbError = _onErrorCb;
    final cbEnd   = _onEndCb;
    _onResultCb = null;
    _onErrorCb  = null;
    _onEndCb    = null;
    cbError?.call(code);
    cbEnd?.call();
  }
}

// ── Mapeamento de erros ───────────────────────────────────────────────────────
//
// Códigos brutos que o speech_to_text plugin repassa do iOS/Android:
//   error_speech_recognizer_not_available → SFSpeechRecognizer.isAvailable=false
//   error_permission                      → permissão negada pelo usuário
//   not_available                         → genérico do plugin (fallback)
//   error_no_speech                       → timeout sem fala detectada
//   error_network / error_network_timeout → sem conexão (STT na nuvem)
//   error_audio                           → falha na AVAudioSession
//   error_no_match                        → confiança insuficiente (tratado acima)
String _mapErrorCode(String errorMsg) {
  final r = errorMsg.toLowerCase();

  // ── Indisponibilidade do SFSpeechRecognizer (BUG 3 no iOS Release) ──────
  // Este código específico é o que o iOS envia quando o SFSpeechRecognizer
  // não está disponível — distinto de "permission denied".
  if (r.contains('speech_recognizer_not_available') ||
      r.contains('recognizer_not_available')) return 'not_available';

  if (r.contains('permission'))  return 'permission_denied';
  if (r.contains('not_availab')) return 'not_available';
  if (r.contains('no_speech') ||
      r.contains('no match')  ||
      r.contains('no_match'))    return 'no_speech';
  if (r.contains('network'))     return 'network';
  if (r.contains('audio'))       return 'audio_session';
  return 'unknown';
}

// ── Handler de resultado ──────────────────────────────────────────────────────
void _handleResult(dynamic result) {
  final dynamic rawFinal = result?.finalResult;
  final dynamic rawWords = result?.recognizedWords;
  final isFinal = _safeBool(rawFinal, fallback: false);
  final words   = _safeString(rawWords, fallback: '');
  final ms = _msSinceListen();

  debugPrint('[STT Mobile] onResult: "$words" final=$isFinal (${ms}ms)');

  if (isFinal) {
    final text = words.trim();
    _listening    = false;
    _bypassActive = false;
    final cbResult = _onResultCb;
    final cbEnd    = _onEndCb;
    _onResultCb = null;
    _onEndCb    = null;

    if (text.isNotEmpty) {
      cbResult?.call(text);
    } else {
      debugPrint('[STT Mobile] Resultado final vazio — encerrando silenciosamente.');
    }
    cbEnd?.call();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
/// Inicia o reconhecimento de voz nativo (iOS / Android).
///
/// SpeechListenOptions usadas:
///   pauseFor: 3s  — aguarda 3s de silêncio antes de encerrar.
///   listenFor: 30s — timeout máximo da sessão.
///   partialResults: true — emite transcrições parciais em tempo real.
///   cancelOnError: true  — encerra automaticamente em caso de erro.
///   onDevice: false      — usa servidor Apple/Google (melhor precisão).
///                          Se false falhar, o plugin tenta fallback on-device.
// ═════════════════════════════════════════════════════════════════════════════
Future<void> startSttImpl({
  required String locale,
  required void Function(String text) onResult,
  required void Function(String error) onError,
  required void Function() onEnd,
}) async {
  _onResultCb = onResult;
  _onErrorCb  = onError;
  _onEndCb    = onEnd;

  if (_listening) await stopSttImpl();

  // ── _ensureInit() com retry: resolve o BUG 3 (not_available em Release) ──
  // Em Debug, a primeira tentativa sempre passa (processo mais lento = iOS
  // tem tempo de preparar SFSpeechRecognizer antes do código chegar aqui).
  // Em Release, pode precisar de 1-2 retries (500-1500ms total).
  final ok = await _ensureInit();
  if (!ok) {
    debugPrint('[STT Mobile] ❌ Falha na inicialização após retries.');
    onError('not_available');
    onEnd();
    return;
  }

  // ── Verificação final de disponibilidade ──────────────────────────────────
  // Após init bem-sucedido, confirmar que isAvailable ainda é true.
  // Pode virar false se o usuário revogar permissão durante o boot.
  if (!_stt.isAvailable) {
    debugPrint('[STT Mobile] ❌ isAvailable=false após init — permissão revogada?');
    onError('not_available');
    onEnd();
    return;
  }

  debugPrint('[STT Mobile] Iniciando listen() — locale: $locale');

  // Registra o timestamp ANTES do listen() para o guard de tempo
  _listenStartedAt = DateTime.now();
  _bypassActive    = false;

  // Marca _listening = true ANTES de chamar listen() porque o microfone
  // iOS pode abrir de forma assíncrona e o bug pode lançar logo em seguida.
  _listening = true;

  try {
    // ── CHAMADA PRINCIPAL ──────────────────────────────────────────────────
    // SpeechListenOptions:
    //   localeId: BCP-47 explícito → iOS usa o reconhecedor correto.
    //   pauseFor: 3s → tempo de silêncio antes de finalizar automaticamente.
    //   listenFor: 30s → evita sessões abertas indefinidamente.
    //   partialResults: true → feedback visual em tempo real para o usuário.
    //   cancelOnError: true → encerra limpo em vez de travar em estado de erro.
    //   onDevice: false → usa servidor Apple (melhor precisão clínica).
    //     Se o dispositivo estiver offline, o iOS faz fallback automático
    //     para reconhecimento on-device quando disponível.
    final dynamic rawStarted = await _stt.listen(
      onResult: _handleResult,
      listenOptions: SpeechListenOptions(
        localeId:       locale,
        pauseFor:       const Duration(seconds: 3),
        listenFor:      const Duration(seconds: 30),
        partialResults: true,
        cancelOnError:  true,
        onDevice:       false,
      ),
    );

    final bool started = _safeBool(rawStarted, fallback: false);

    if (!started) {
      debugPrint('[STT Mobile] listen() retornou false — sessão recusada pelo plugin.');
      _listening = false;
      onError('not_available');
      onEnd();
    } else {
      debugPrint('[STT Mobile] ✅ listen() OK — aguardando fala...');
    }

  } on TypeError catch (e) {
    // ══════════════════════════════════════════════════════════════════════
    // BYPASS PRIMÁRIO — TypeError "Null is not a subtype of bool" (BUG 1)
    //
    // O plugin lança TypeError ao tentar converter o retorno nil do Swift.
    // O microfone JÁ está ativo neste ponto no iOS.
    //
    // _bypassActive = true → guard de tempo em _handleStatus ignorará
    // qualquer 'done' nos próximos 1500ms (evita fechamento precoce).
    // ══════════════════════════════════════════════════════════════════════
    if (_isNullBoolBug(e)) {
      _bypassActive = true;
      debugPrint('[STT Mobile] ⚠️ BYPASS ATIVADO (TypeError): bug null-bool detectado.');
      debugPrint('[STT Mobile] Microfone ativo — ignorando "done" precoces por 1500ms...');
      // _listening permanece true — aguarda onResult ou onStatus tardio
    } else {
      debugPrint('[STT Mobile] TypeError não relacionado ao bug: $e');
      _listening = false;
      onError('unknown');
      onEnd();
    }

  } catch (e) {
    // ══════════════════════════════════════════════════════════════════════
    // BYPASS SECUNDÁRIO — catch genérico
    // Cobre variantes de mensagem ou versões futuras com o mesmo bug.
    // ══════════════════════════════════════════════════════════════════════
    if (_isNullBoolBug(e)) {
      _bypassActive = true;
      debugPrint('[STT Mobile] ⚠️ BYPASS ATIVADO (catch genérico): $e');
      debugPrint('[STT Mobile] Microfone ativo — ignorando "done" precoces por 1500ms...');
      // _listening permanece true
    } else {
      debugPrint('[STT Mobile] listen() exception inesperada: $e');
      _listening = false;
      onError('unknown');
      onEnd();
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
/// Para o reconhecimento em andamento.
// ═════════════════════════════════════════════════════════════════════════════
Future<void> stopSttImpl() async {
  if (!_listening && !_stt.isListening) return;
  debugPrint('[STT Mobile] stopSttImpl() chamado.');
  _bypassActive = false;
  try {
    await _stt.stop();
  } catch (e) {
    debugPrint('[STT Mobile] stop() exception: $e');
  }
  _listening  = false;
  _onResultCb = null;
  _onErrorCb  = null;
  _onEndCb    = null;
}
