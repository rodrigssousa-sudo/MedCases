// stt_helper.dart — Interface pública de STT para Web, iOS e Android.
//
// Arquitetura de imports condicionais:
//   Web    → stt_helper_web.dart    (dart:html SpeechRecognition API)
//   Mobile → stt_helper_mobile.dart (speech_to_text plugin nativo)
//
// O conditional import escolhe a implementação em tempo de compilação:
//   dart.library.html  → disponível APENAS no target web (dart2js/wasm)
//   dart.library.io    → disponível APENAS no target nativo (iOS/Android/Desktop)
//
// Fluxo de permissões:
//   iOS     → NSMicrophoneUsageDescription + NSSpeechRecognitionUsageDescription
//             já declarados no Info.plist. O speech_to_text pede a permissão
//             ao usuário na primeira chamada a initialize().
//   Android → RECORD_AUDIO no AndroidManifest (adicionado abaixo).
//             O speech_to_text pede a permissão em runtime automaticamente.
//   Web     → Permissão do browser — pedida pelo SpeechRecognition nativo.

import 'dart:async';
import 'entitlement_service.dart';
import 'monthly_usage_ledger.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// ── Conditional import ─────────────────────────────────────────────────────
// Fallback (stub) → stt_helper_stub.dart  (no-op — nunca chamado em prod)
// Web             → stt_helper_web.dart   (compilado apenas com dart2js)
// Mobile/Desktop  → stt_helper_mobile.dart (compilado apenas com dart:io)
import 'stt_helper_stub.dart'
    if (dart.library.html) 'stt_helper_web.dart'
    if (dart.library.io) 'stt_helper_mobile.dart';

/// Interface estática de STT — delegada à implementação correta por plataforma.
class SttHelper {
  SttHelper._();
  static Future<void>? _ending;
  static UsageReservation? _usage;
  static Stopwatch? _clock;
  static Timer? _quotaTimer;
  static bool _starting = false;
  static bool _hadResult = false;
  static Future<void> _finishUsage() async {
    final usage = _usage;
    final elapsed = _clock?.elapsedMilliseconds ?? 0;
    _usage = null;
    _clock?.stop();
    _clock = null;
    _quotaTimer?.cancel();
    if (usage != null)
      await usage.finish(
          actualMs: elapsed.clamp(0, usage.maximumMs), success: _hadResult);
  }

  /// Inicia o reconhecimento de voz.
  ///
  /// [locale]             — código BCP-47 do idioma (ex: 'pt-BR', 'es-ES').
  /// [onResult]           — chamado com o texto reconhecido final.
  /// [onPartialResult]    — chamado com a hipótese parcial mais recente; o
  ///                        consumidor deve substituir, nunca concatenar.
  /// [onError]            — chamado com o código de erro ('permission_denied',
  ///                        'not_available', 'no_speech', 'network', etc.).
  /// [onEnd]              — chamado quando a sessão encerra (com ou sem resultado).
  /// [onSoundLevelChange] — chamado com nível de som normalizado 0.0–1.0 em tempo
  ///                        real (mobile via plugin; web recebe 0.5 constante
  ///                        enquanto ativo, pois a Web Speech API não expõe nível).
  static Future<void> start({
    required String locale,
    required void Function(String text) onResult,
    required void Function(String error) onError,
    required void Function() onEnd,
    void Function(String text)? onPartialResult,
    void Function(double level)? onSoundLevelChange,
  }) async {
    if (_starting || _usage != null) {
      onError('recording_busy');
      return;
    }
    _starting = true;
    try {
      if (_ending != null) await _ending;
      await EntitlementService.instance.refreshAuthoritativeTier();
      _usage = await MonthlyUsageLedger.instance.begin(
          operationId: MonthlyUsageLedger.operationId(),
          kinds: {UsageKind.recording, UsageKind.transcription},
          maximumMs: 90000,
          allowPartial: true);
      final reservation = _usage!;
      bool ownsSession() =>
          identical(_usage, reservation) &&
          reservation.authorizes(UsageKind.recording);
      _hadResult = false;
      _clock = Stopwatch();
      await startSttImpl(
          locale: locale,
          onResult: (text) {
            if (!ownsSession()) return;
            if (text.trim().isNotEmpty) _hadResult = true;
            onResult(text);
          },
          onError: (code) {
            if (!ownsSession()) return;
            onError(code);
            _ending = _finishUsage();
          },
          onEnd: () {
            if (!ownsSession()) return;
            _ending = _finishUsage();
            onEnd();
          },
          onPartialResult: (text) {
            if (!ownsSession()) return;
            if (text.trim().isNotEmpty) _hadResult = true;
            onPartialResult?.call(text);
          },
          onSoundLevelChange: (level) {
            if (ownsSession()) onSoundLevelChange?.call(level);
          });
      if (_usage != null) {
        _clock?.start();
        _quotaTimer = Timer(Duration(milliseconds: _usage!.maximumMs), () {
          unawaited(stop());
        });
      }
    } catch (error) {
      await _finishUsage();
      onError(error.toString().contains('MONTHLY_USAGE_LIMIT')
          ? 'monthly_usage_limit'
          : 'usage_connection_required');
    } finally {
      _starting = false;
    }
  }

  /// Para o reconhecimento de voz em andamento.
  static Future<void> stop() async {
    try {
      await stopSttImpl();
    } finally {
      _ending = _finishUsage();
      await _ending;
    }
  }

  /// Indica se STT está disponível na plataforma atual.
  /// Web: sempre true (browser tem a API).
  /// Mobile: true após inicialização e permissão concedida.
  static bool get isAvailable => !kIsWeb ? true : true;
}
