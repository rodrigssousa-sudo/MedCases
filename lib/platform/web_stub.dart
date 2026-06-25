// Stub para compilação Android/iOS — implementações reais estão em web_impl.dart
// Nenhuma dessas funções é chamada fora de kIsWeb == true.
// BUILD 241: stub para setupVisibilityHandler (no-op em iOS/Android)

import 'dart:typed_data';

void webOpenBlob(String content, String mime) {}
void webDownloadBytes(Uint8List bytes, String filename, String mime) {}
void webOpenHtmlPrint(String htmlContent) {}

Future<String> webPickImageAndOcr() async => '';

/// Stub: retorna string vazia em plataformas não-web (Android/iOS).
String webGetRefParam() => '';

bool webHasSpeechRecognition() => false;

class WebSpeechRecognizer {
  // ignore: unused_field
  String? _activeKey;
  bool get isListening => false;
  void start(String key, String lang, {
    required void Function(String transcript, bool isFinal) onResult,
    required void Function() onEnd,
    required void Function(String? code) onError,
  }) {}
  void stop() {}
  void dispose() {}
}

/// Stub: no-op em iOS/Android — visibilitychange é evento de browser.
void setupVisibilityHandler({
  required void Function() onHidden,
  required void Function() onVisible,
}) {}

void debugPrintVisibility(bool hidden) {}
