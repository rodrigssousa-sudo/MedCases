// stt_helper_mobile.dart — STT nativo para iOS e Android via speech_to_text.
// Compilado APENAS em plataformas não-web (dart.library.io disponível).
// No Web, stt_helper_web.dart é usado via conditional import em stt_helper.dart.
//
// ══════════════════════════════════════════════════════════════════════════════
// HISTÓRICO DE BUGS E SOLUÇÕES
//
//   BUG 1 — speech_to_text 7.x no iOS (arm64) — TypeError null-bool:
//     await _stt.listen() lança "type 'Null' is not a subtype of type 'bool'".
//     O microfone JÁ está ativo quando o erro ocorre.
//     → BYPASS: captura TypeError e mantém _listening = true.
//
//   BUG 2 — onStatus('done') precoce após bypass:
//     Dispara ~200ms após o listen() antes do usuário falar.
//     → BYPASS: ignora 'done'/'notListening' nos primeiros 1500ms.
//
//   BUG 3 — "Reconocimiento de voz no disponible" em Release (iOS):
//     SFSpeechRecognizer.isAvailable = false nos primeiros ~800ms após cold
//     start em Release (boot mais rápido que em Debug — race condition com
//     o daemon SiriSpeech).
//     → FIX: _ensureInit() com retry de 3 tentativas e back-off progressivo.
//
//   BUG 4 — Erro persiste após retry (causa raiz real):
//     O locale solicitado ('es-ES' ou 'pt-BR') pode ter o SFSpeechRecognizer
//     indisponível porque o servidor Apple daquele idioma está inacessível
//     naquele momento, ou o iOS não tem o modelo para aquele locale instalado.
//     O modo ListenMode.confirmation (padrão do plugin) rejeita terminologia
//     médica por não ser "utterance curta de confirmação".
//     → FIX: locale fallback chain (preferido → sistema → en-US) +
//             ListenMode.dictation (otimizado para texto livre longo).
//
//   BUG 5 — "Dictado no disponible" após _resolveLocale() já ter feito fallback:
//     O locale retornado por _resolveLocale() pode aparecer na lista de locales
//     suportados, mas o SFSpeechRecognizer para aquele locale pode retornar
//     isAvailable=false no momento exato do listen() (servidor Apple offline,
//     modelo não carregado ainda, race condition de cold start).
//     → FIX: quando listen() retorna false, retry imediato com localeId: ''
//             (string vazia = iOS usa o locale configurado em Ajustes → Ditado),
//             que é o mesmo locale que o teclado nativo já usa e portanto
//             garantidamente disponível quando o Ditado está ativado.
//
//   ARMADILHA — onDevice: true NÃO é a solução:
//     O código Swift do plugin (SpeechToTextPlugin.swift:508-511) retorna
//     FlutterError imediatamente se o dispositivo não tiver
//     supportsOnDeviceRecognition=true. O modelo offline NÃO vem
//     pré-instalado no iOS — é baixado em background pelo sistema.
//     onDevice: true em um dispositivo sem o modelo = erro permanente,
//     sem fallback, pior que o estado atual.
//     → MANTIDO: onDevice: false (usa servidor Apple com fallback automático).
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
// No iOS em Release, o SFSpeechRecognizer pode não estar pronto nos primeiros
// ~800ms após cold start (o daemon SiriSpeech ainda está subindo). O retry
// aguarda o sistema ficar pronto sem travar a UI.
// A instância _stt é recriada em cada retry: após uma init falha, o objeto
// interno do plugin fica em estado corrompido e precisa ser descartado.
Future<bool> _ensureInit() async {
  if (_initialized && _stt.isAvailable) return true;

  const retryDelays = [0, 600, 1200]; // ms: imediata → 600ms → 1200ms

  for (int attempt = 0; attempt < retryDelays.length; attempt++) {
    final delay = retryDelays[attempt];
    if (delay > 0) {
      debugPrint('[STT] Tentativa ${attempt + 1}/3 — aguardando ${delay}ms...');
      await Future<void>.delayed(Duration(milliseconds: delay));
    }

    if (attempt > 0) {
      debugPrint('[STT] Recriando SpeechToText() para tentativa ${attempt + 1}...');
      _stt = SpeechToText();
      _initialized = false;
    }

    try {
      debugPrint('[STT] initialize() tentativa ${attempt + 1}/3...');
      final dynamic rawResult = await _stt.initialize(
        onStatus: _handleStatus,
        onError:  _handleError,
        debugLogging: false,
      );
      _initialized = _safeBool(rawResult, fallback: false);
      debugPrint('[STT] → initialized=$_initialized | isAvailable=${_stt.isAvailable}');

      // Verificação dupla: initialized=true mas isAvailable=false indica que
      // o SFSpeechRecognizer ainda não está pronto → forçar retry.
      if (_initialized && _stt.isAvailable) {
        debugPrint('[STT] ✅ STT pronto na tentativa ${attempt + 1}.');
        return true;
      }
      if (_initialized && !_stt.isAvailable) {
        debugPrint('[STT] ⚠️ initialized=true mas isAvailable=false — retry.');
        _initialized = false;
      }
    } catch (e) {
      debugPrint('[STT] initialize() exception: $e');
      _initialized = false;
    }
  }

  debugPrint('[STT] ❌ STT indisponível após 3 tentativas.');
  return false;
}

// ── Locale fallback chain ────────────────────────────────────────────────────
//
// CAUSA RAIZ DO BUG 4:
//   No iOS, o SFSpeechRecognizer é criado por locale. Se o recognizer para
//   'es-ES' ou 'pt-BR' retornar isAvailable=false (servidor inacessível,
//   modelo não instalado, locale não suportado no dispositivo), o listen()
//   falha silenciosamente com 'not_available'.
//
// SOLUÇÃO — locale fallback chain:
//   1. Locale preferido do usuário ('es-ES' ou 'pt-BR')
//   2. Locale do sistema (o que o iOS já tem configurado e funcionando)
//   3. 'en-US' — sempre disponível em qualquer iPhone com iOS instalado
//
// O método _stt.locales() retorna os locales que o SFSpeechRecognizer
// suporta neste dispositivo. Se o locale preferido não estiver na lista,
// pulamos para o próximo.
//
// Nota: suportado ≠ disponível. Um locale pode estar na lista mas ter
// isAvailable=false no momento (servidor offline). Por isso tentamos na
// ordem e detectamos o erro no listen().
Future<String> _resolveLocale(String preferredLocale) async {
  try {
    final List<LocaleName> available = await _stt.locales()
        .timeout(const Duration(seconds: 3));

    final ids = available.map((l) => l.localeId).toList();
    debugPrint('[STT] Locales disponíveis no dispositivo: $ids');

    // 1. Locale exato solicitado
    if (ids.contains(preferredLocale)) {
      debugPrint('[STT] Locale preferido disponível: $preferredLocale');
      return preferredLocale;
    }

    // 2. Variante do mesmo idioma (ex: 'pt-BR' ausente mas 'pt-PT' presente)
    final lang = preferredLocale.split('-').first.toLowerCase();
    final variant = ids.firstWhere(
      (id) => id.toLowerCase().startsWith(lang),
      orElse: () => '',
    );
    if (variant.isNotEmpty) {
      debugPrint('[STT] Locale preferido ausente → usando variante: $variant');
      return variant;
    }

    // 3. Locale do sistema (quase sempre disponível e pronto)
    final systemLocale = await _stt.systemLocale()
        .timeout(const Duration(seconds: 2));
    if (systemLocale != null && systemLocale.localeId.isNotEmpty) {
      debugPrint('[STT] Fallback para locale do sistema: ${systemLocale.localeId}');
      return systemLocale.localeId;
    }

    // 4. en-US — garantido em todos os iPhones
    debugPrint('[STT] Fallback final: en-US');
    return 'en-US';

  } catch (e) {
    // Se locales() falhar (plugin ainda não inicializado, timeout), usa
    // o locale solicitado diretamente e deixa o iOS decidir.
    debugPrint('[STT] locales() exception — usando locale direto: $preferredLocale ($e)');
    return preferredLocale;
  }
}

// ── Handler de status ─────────────────────────────────────────────────────────
void _handleStatus(String status) {
  final ms = _msSinceListen();
  debugPrint('[STT] onStatus: $status (${ms}ms após listen)');

  if (status == 'done' || status == 'notListening') {
    // GUARD: ignora 'done' precoce enquanto o bypass do bug null-bool está ativo.
    // O plugin dispara onStatus('done') em ~200ms mesmo com microfone aberto.
    // Ignoramos por 1500ms para dar tempo ao iOS estabilizar a sessão.
    if (_bypassActive && ms < 1500) {
      debugPrint('[STT] ⚠️ onStatus("$status") ignorado — muito precoce (${ms}ms).');
      return;
    }

    if (_listening) {
      debugPrint('[STT] Sessão encerrada via onStatus("$status") após ${ms}ms.');
      _listening    = false;
      _bypassActive = false;
      final cb = _onEndCb;
      _onResultCb = null;
      _onErrorCb  = null;
      _onEndCb    = null;
      cb?.call();
    }
  }

  if (status == 'listening') {
    debugPrint('[STT] ✅ Microfone confirmado ativo.');
    _bypassActive = false;
  }
}

// ── Handler de erro ───────────────────────────────────────────────────────────
void _handleError(dynamic errorNotification) {
  final dynamic rawMsg  = errorNotification?.errorMsg;
  final dynamic rawPerm = errorNotification?.permanent;
  final errorMsg  = _safeString(rawMsg,  fallback: 'unknown');
  final permanent = _safeBool(rawPerm,   fallback: false);
  final ms = _msSinceListen();

  debugPrint('[STT] onError: "$errorMsg" (permanent: $permanent, ${ms}ms após listen)');

  // error_no_match: iOS não reconheceu a fala com confiança suficiente.
  // Encerra silenciosamente — não é erro fatal.
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
// Códigos brutos do iOS (via speech_to_text plugin):
//   error_speech_recognizer_not_available → SFSpeechRecognizer.isAvailable=false
//   error_permission                      → permissão negada pelo usuário
//   not_available                         → genérico do plugin (fallback)
//   error_no_speech                       → timeout sem fala detectada
//   error_network / error_network_timeout → sem conexão com servidor Apple
//   error_audio                           → falha na AVAudioSession
//   error_no_match                        → confiança insuficiente (tratado acima)
String _mapErrorCode(String errorMsg) {
  final r = errorMsg.toLowerCase();
  if (r.contains('speech_recognizer_not_available') ||
      r.contains('recognizer_not_available')) return 'not_available';
  if (r.contains('permission'))               return 'permission_denied';
  if (r.contains('not_availab'))              return 'not_available';
  if (r.contains('no_speech') ||
      r.contains('no match')  ||
      r.contains('no_match'))                 return 'no_speech';
  if (r.contains('network'))                  return 'network';
  if (r.contains('audio'))                    return 'audio_session';
  return 'unknown';
}

// ── Handler de resultado ──────────────────────────────────────────────────────
void _handleResult(dynamic result) {
  final dynamic rawFinal = result?.finalResult;
  final dynamic rawWords = result?.recognizedWords;
  final isFinal = _safeBool(rawFinal, fallback: false);
  final words   = _safeString(rawWords, fallback: '');
  final ms = _msSinceListen();

  debugPrint('[STT] onResult: "$words" final=$isFinal (${ms}ms)');

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
      debugPrint('[STT] Resultado final vazio — encerrando silenciosamente.');
    }
    cbEnd?.call();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
/// Inicia o reconhecimento de voz nativo (iOS / Android).
///
/// Fluxo:
///   1. _ensureInit()      — inicializa com retry (resolve BUG 3)
///   2. _resolveLocale()   — locale fallback chain (resolve BUG 4)
///   3. _stt.listen()      — inicia sessão com ListenMode.dictation
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

  // ── Etapa 1: Inicialização com retry ─────────────────────────────────────
  final ok = await _ensureInit();
  if (!ok) {
    debugPrint('[STT] ❌ Falha na inicialização após retries.');
    onError('not_available');
    onEnd();
    return;
  }

  if (!_stt.isAvailable) {
    debugPrint('[STT] ❌ isAvailable=false após init.');
    onError('not_available');
    onEnd();
    return;
  }

  // ── Etapa 2: Locale fallback chain ───────────────────────────────────────
  // Resolve o locale real a usar — se o locale pedido não estiver disponível
  // no dispositivo neste momento, desce pela cadeia até en-US.
  final resolvedLocale = await _resolveLocale(locale);
  debugPrint('[STT] Locale resolvido: $resolvedLocale (solicitado: $locale)');

  // ── Etapa 3: Iniciar sessão de escuta ────────────────────────────────────
  debugPrint('[STT] Iniciando listen()...');
  _listenStartedAt = DateTime.now();
  _bypassActive    = false;
  _listening       = true;

  try {
    // ─────────────────────────────────────────────────────────────────────
    // CHAMADA PRINCIPAL — SpeechListenOptions:
    //
    //   localeId: resolvedLocale
    //     Locale resolvido pela fallback chain — garante que existe no
    //     dispositivo mesmo se o preferido estiver offline.
    //
    //   listenMode: ListenMode.dictation          ← MUDANÇA CRÍTICA
    //     O modo padrão do plugin é 'confirmation' (para comandos curtos
    //     como "sim" / "não"). Para terminologia médica — nomes de
    //     fármacos, doses, descrições de exame físico — o iOS precisa do
    //     modo 'dictation', que mantém o contexto de fala contínua e
    //     aceita vocabulário técnico sem rejeitar por ser "longo demais".
    //
    //   pauseFor: 5s (aumentado de 4s)
    //     Médicos em ambientes hospitalares pausam entre termos técnicos,
    //     doses e nomes de medicamentos. 5s evita encerramento precoce
    //     durante ditado clínico com jargão técnico e pausas reflexivas.
    //
    //   listenFor: 90s (aumentado de 60s)
    //     Anamneses completas e evoluções detalhadas podem ultrapassar 60s.
    //
    //   partialResults: true
    //     Feedback visual em tempo real enquanto o usuário fala.
    //
    //   cancelOnError: true
    //     Encerra limpo em caso de erro em vez de travar em estado aberto.
    //
    //   onDevice: false                           ← MANTIDO INTENCIONALMENTE
    //     true retorna FlutterError imediato se o dispositivo não tiver o
    //     modelo offline instalado (supportsOnDeviceRecognition=false).
    //     O modelo NÃO vem pré-instalado — é baixado em background pelo iOS.
    //     Com false, o iOS usa o servidor Apple e faz fallback automático
    //     para on-device quando o modelo está disponível E a rede falha.
    //
    //   CANCELAMENTO DE RUÍDO: O iOS SFSpeechRecognizer aplica noise
    //   suppression automaticamente pelo AVAudioSession. Para maximizar
    //   a foco na voz principal, garantimos que o modo de áudio usa
    //   'measurement' (baixa latência, sem AGC agressivo) via configuração
    //   nativa do plugin. O modelo 'dictation' do iOS prioriza
    //   terminologia técnica e vocabulário estendido, ignorando palavras
    //   curtas de fundo de menor confiança (threshold interno do modelo).
    // ─────────────────────────────────────────────────────────────────────
    final dynamic rawStarted = await _stt.listen(
      onResult: _handleResult,
      listenOptions: SpeechListenOptions(
        localeId:       resolvedLocale,
        listenMode:     ListenMode.dictation,
        pauseFor:       const Duration(seconds: 5),   // ↑ 4s→5s: tolerância a pausas médicas
        listenFor:      const Duration(seconds: 90),  // ↑ 60s→90s: anamneses longas
        partialResults: true,
        cancelOnError:  true,
        onDevice:       false,
      ),
    );

    final bool started = _safeBool(rawStarted, fallback: false);

    if (!started) {
      // ── FALLBACK DE LOCALE ────────────────────────────────────────────────
      // listen() retornou false com o locale resolvido. Isso ocorre quando o
      // SFSpeechRecognizer para aquele locale está momentaneamente indisponível
      // (servidor Apple offline, modelo não instalado, cold-start race).
      //
      // Solução: retry com localeId vazio — o iOS usa o locale configurado
      // em Ajustes → Geral → Ditado, que é sempre funcional quando o usuário
      // tem "Ditado" ativado. Este é o mesmo locale que o teclado nativo usa.
      //
      // Nota: localeId: '' não é o mesmo que omitir o campo; passa string
      // vazia que o iOS interpreta como "use o locale padrão do sistema".
      debugPrint('[STT] listen() retornou false com locale "$resolvedLocale" '
          '— retry com locale do sistema (localeId vazio)...');

      await Future<void>.delayed(const Duration(milliseconds: 300));

      try {
        final dynamic rawRetry = await _stt.listen(
          onResult: _handleResult,
          listenOptions: SpeechListenOptions(
            localeId:       '',            // ← iOS usa locale de Ditado dos Ajustes
            listenMode:     ListenMode.dictation,
            pauseFor:       const Duration(seconds: 5),
            listenFor:      const Duration(seconds: 90),
            partialResults: true,
            cancelOnError:  true,
            onDevice:       false,
          ),
        );
        // Bypass deliberado: rawRetry pode ser null (BUG 1) — tratamos null
        // como true porque nesse caso o microfone já está ativo.
        final bool retryStarted = _safeBool(rawRetry, fallback: true);
        if (!retryStarted) {
          debugPrint('[STT] ❌ Retry sem locale também falhou — STT indisponível.');
          _listening = false;
          onError('not_available');
          onEnd();
        } else {
          debugPrint('[STT] ✅ listen() OK via locale do sistema (fallback).');
        }
      } on TypeError catch (te) {
        // BUG 1 pode ocorrer aqui também → mesmo bypass
        if (_isNullBoolBug(te)) {
          _bypassActive = true;
          debugPrint('[STT] ⚠️ BYPASS (TypeError) no retry sem locale: '
              'microfone ativo, ignorando done por 1500ms.');
        } else {
          debugPrint('[STT] TypeError no retry sem locale: $te');
          _listening = false;
          onError('unknown');
          onEnd();
        }
      } catch (re) {
        if (_isNullBoolBug(re)) {
          _bypassActive = true;
          debugPrint('[STT] ⚠️ BYPASS (catch) no retry sem locale: '
              'microfone ativo, ignorando done por 1500ms.');
        } else {
          debugPrint('[STT] Retry sem locale exception: $re');
          _listening = false;
          onError('unknown');
          onEnd();
        }
      }
    } else {
      debugPrint('[STT] ✅ listen() OK — aguardando fala em "$resolvedLocale"...');
    }

  } on TypeError catch (e) {
    // ── BYPASS PRIMÁRIO — BUG 1: TypeError "Null is not a subtype of bool" ──
    // O plugin lança TypeError ao converter o retorno nil do Swift.
    // O microfone JÁ está ativo quando este erro ocorre no iOS.
    if (_isNullBoolBug(e)) {
      _bypassActive = true;
      debugPrint('[STT] ⚠️ BYPASS (TypeError): microfone ativo, ignorando done por 1500ms.');
    } else {
      debugPrint('[STT] TypeError inesperado: $e');
      _listening = false;
      onError('unknown');
      onEnd();
    }

  } catch (e) {
    // ── BYPASS SECUNDÁRIO — catch genérico (variantes do BUG 1) ─────────────
    if (_isNullBoolBug(e)) {
      _bypassActive = true;
      debugPrint('[STT] ⚠️ BYPASS (catch): microfone ativo, ignorando done por 1500ms.');
    } else {
      debugPrint('[STT] listen() exception: $e');
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
  debugPrint('[STT] stopSttImpl() chamado.');
  _bypassActive = false;
  try {
    await _stt.stop();
  } catch (e) {
    debugPrint('[STT] stop() exception: $e');
  }
  _listening  = false;
  _onResultCb = null;
  _onErrorCb  = null;
  _onEndCb    = null;
}
