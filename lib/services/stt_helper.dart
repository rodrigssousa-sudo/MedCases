// ignore_for_file: avoid_web_libraries_in_flutter
// STT Helper — Web Speech API para reconhecimento de voz no Flutter Web.
// Usa dart:html condicionado: compilado apenas quando kIsWeb == true.
// No mobile/desktop, todas as chamadas são no-op (retornam silenciosamente).
import 'package:flutter/foundation.dart' show kIsWeb;

// dart:html só está disponível no compilador web (dart2js / wasm).
// A conditional import garante que no mobile o stub é usado.
import 'stt_helper_stub.dart'
    if (dart.library.html) 'stt_helper_web.dart';

/// Interface pública de STT — delegada ao helper correto por plataforma.
class SttHelper {
  SttHelper._();

  /// Inicia o reconhecimento de voz.
  /// [locale]: código de idioma (ex: 'pt-BR', 'es-ES').
  /// [onResult]: chamado com o texto reconhecido quando o STT termina com sucesso.
  /// [onError]: chamado com o código de erro em caso de falha.
  /// [onEnd]:   chamado quando o reconhecimento finaliza (com ou sem resultado).
  static void start({
    required String locale,
    required void Function(String text) onResult,
    required void Function(String error) onError,
    required void Function() onEnd,
  }) {
    if (!kIsWeb) return; // no-op em mobile
    startSttImpl(
      locale: locale,
      onResult: onResult,
      onError: onError,
      onEnd: onEnd,
    );
  }

  /// Para o reconhecimento de voz em andamento.
  static void stop() {
    if (!kIsWeb) return;
    stopSttImpl();
  }
}
