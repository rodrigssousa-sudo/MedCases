// ignore_for_file: avoid_web_libraries_in_flutter
// Implementação Web Speech API via dart:html.
// Este arquivo só é compilado no target web (dart2js / wasm).
import 'dart:html' as html;

html.SpeechRecognition? _recognition;

void startSttImpl({
  required String locale,
  required void Function(String text) onResult,
  required void Function(String error) onError,
  required void Function() onEnd,
}) {
  try {
    stopSttImpl();

    final sr = html.SpeechRecognition();
    _recognition = sr;

    sr.lang = locale;
    sr.interimResults = false;
    sr.maxAlternatives = 1;
    sr.continuous = false;

    sr.onResult.listen((event) {
      try {
        final results = event.results;
        if (results != null && results.isNotEmpty) {
          // results é List<SpeechRecognitionResult>
          final firstResult = results[0];
          final length = firstResult.length ?? 0;
          if (length > 0) {
            // SpeechRecognitionResult.item(int) → SpeechRecognitionAlternative
            final alt = firstResult.item(0);
            final transcript = alt.transcript ?? '';
            if (transcript.isNotEmpty) {
              onResult(transcript);
            }
          }
        }
      } catch (_) {}
    });

    sr.onError.listen((event) {
      try {
        final dynamic ev = event;
        onError(ev.error?.toString() ?? 'unknown');
      } catch (_) {
        onError('unknown');
      }
    });

    sr.onEnd.listen((_) {
      _recognition = null;
      onEnd();
    });

    sr.start();
  } catch (e) {
    onError(e.toString());
    onEnd();
  }
}

void stopSttImpl() {
  try {
    _recognition?.stop();
    _recognition?.abort();
  } catch (_) {}
  _recognition = null;
}
