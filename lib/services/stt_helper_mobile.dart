// stt_helper_mobile.dart — STT nativo para iOS e Android via speech_to_text.
// Compilado APENAS em plataformas não-web (dart.library.io disponível).
// No Web, stt_helper_web.dart é usado via conditional import em stt_helper.dart.
//
// ══════════════════════════════════════════════════════════════════════════════
// BUG CONHECIDO — speech_to_text 7.2.0 no iOS (arm64):
//
//   Problema 1: await _stt.listen() lança internamente:
//               "type 'Null' is not a subtype of type 'bool'"
//               O microfone JÁ está ativo quando o erro ocorre.
//               → BYPASS: captura o erro e mantém _listening = true.
//
//   Problema 2: onStatus('done') dispara ~200ms após o bypass, antes mesmo
//               de o usuário falar, porque o plugin acha que a sessão terminou.
//               → BYPASS: ignora qualquer 'done'/'notListening' nos primeiros
//                 1500ms após o listen() para dar tempo ao microfone estabilizar.
// ══════════════════════════════════════════════════════════════════════════════
// ignore_for_file: dead_null_aware_expression

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:speech_to_text/speech_to_text.dart';

// ── Singleton ─────────────────────────────────────────────────────────────────
final _stt = SpeechToText();

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

// ── Inicialização lazy ────────────────────────────────────────────────────────
Future<bool> _ensureInit() async {
  if (_initialized && _stt.isAvailable) return true;

  _initialized = false;
  debugPrint('[STT Mobile] Iniciando SpeechToText.initialize()...');

  try {
    final dynamic rawResult = await _stt.initialize(
      onStatus: _handleStatus,
      onError:  _handleError,
      debugLogging: false,
    );
    _initialized = _safeBool(rawResult, fallback: false);
    debugPrint('[STT Mobile] initialize() → $_initialized | isAvailable: ${_stt.isAvailable}');
  } catch (e) {
    debugPrint('[STT Mobile] initialize() exception: $e');
    _initialized = false;
  }

  return _initialized;
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
    _bypassActive = false; // já não precisamos do bypass — sessão estável
  }
}

// ── Handler de erro ───────────────────────────────────────────────────────────
void _handleError(dynamic errorNotification) {
  final dynamic rawMsg  = errorNotification?.errorMsg;
  final dynamic rawPerm = errorNotification?.permanent;
  final errorMsg  = _safeString(rawMsg,  fallback: 'unknown');
  final permanent = _safeBool(rawPerm,   fallback: false);
  final ms = _msSinceListen();

  debugPrint('[STT Mobile] onError: $errorMsg (permanent: $permanent, ${ms}ms após listen)');

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
String _mapErrorCode(String errorMsg) {
  final r = errorMsg.toLowerCase();
  if (r.contains('permission'))  return 'permission_denied';
  if (r.contains('not_availab')) return 'not_available';
  if (r.contains('no_speech') || r.contains('no match') || r.contains('no_match')) return 'no_speech';
  if (r.contains('network'))     return 'network';
  if (r.contains('audio'))       return 'audio';
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

  final ok = await _ensureInit();
  if (!ok) {
    debugPrint('[STT Mobile] Falha na inicialização — permissão negada ou indisponível.');
    onError('permission_denied');
    onEnd();
    return;
  }

  if (!_stt.isAvailable) {
    debugPrint('[STT Mobile] isAvailable=false — verificar permissão ou hardware.');
    onError('permission_denied');
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
    // ─────────────────────────────────────────────────────────────────────
    // CHAMADA PRINCIPAL
    // Em funcionamento normal: retorna true quando o microfone abre.
    // Com o bug 7.2.0 no iOS: lança TypeError antes de retornar.
    // ─────────────────────────────────────────────────────────────────────
    final dynamic rawStarted = await _stt.listen(
      onResult: _handleResult,
      listenOptions: SpeechListenOptions(
        localeId:       locale,
        pauseFor:       const Duration(seconds: 3),
        listenFor:      const Duration(seconds: 30),
        partialResults: true,
        cancelOnError:  true,
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
    // BYPASS PRIMÁRIO — TypeError "Null is not a subtype of bool"
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
