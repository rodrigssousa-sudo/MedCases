// Stub para compilação Android/iOS — implementações reais estão em web_impl.dart
// Nenhuma dessas funções é chamada fora de kIsWeb == true.

import 'dart:typed_data';

void webOpenBlob(String content, String mime) {}
void webDownloadBytes(Uint8List bytes, String filename, String mime) {}
void webOpenHtmlPrint(String htmlContent) {}

Future<String> webPickImageAndOcr() async => '';

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
