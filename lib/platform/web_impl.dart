// Implementação real para Web — usa dart:html e dart:js
// Este arquivo SÓ é importado quando kIsWeb == true (via conditional import)

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:async';
import 'dart:typed_data';

/// Abre conteúdo HTML como blob em nova aba (para impressão/PDF).
void webOpenHtmlPrint(String htmlContent) {
  final blob = html.Blob([htmlContent], 'text/html');
  final url  = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  Future.delayed(const Duration(milliseconds: 1500), () {
    html.Url.revokeObjectUrl(url);
  });
}

/// Dispara download de bytes como arquivo no browser.
void webDownloadBytes(Uint8List bytes, String filename, String mime) {
  final blob = html.Blob([bytes], mime);
  final url  = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

/// Abre file picker de imagem e tenta OCR via Tesseract.js; retorna texto.
Future<String> webPickImageAndOcr() async {
  final completer = Completer<String>();
  try {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..style.display = 'none';
    html.document.body!.append(input);

    input.onChange.listen((e) async {
      final files = input.files;
      if (files == null || files.isEmpty) {
        input.remove();
        completer.complete('');
        return;
      }
      final reader = html.FileReader();
      reader.readAsDataUrl(files[0]);
      reader.onLoadEnd.listen((_) async {
        try {
          final dataUrl = reader.result as String;
          final text    = await _runOcr(dataUrl);
          input.remove();
          completer.complete(text);
        } catch (err) {
          input.remove();
          completer.completeError(err);
        }
      });
    });

    input.click();
  } catch (e) {
    completer.completeError(e);
  }
  return completer.future;
}

Future<String> _runOcr(String dataUrl) async {
  final hasTess = js.context.hasProperty('Tesseract');
  if (!hasTess) return '';
  final c = Completer<String>();
  final promise = js.context.callMethod('eval', [
    '''(function(){ return Tesseract.recognize("$dataUrl","por+spa").then(r=>r.data.text); })()'''
  ]);
  final obj = js.JsObject.fromBrowserObject(promise);
  obj.callMethod('then', [js.allowInterop((dynamic v) => c.complete(v?.toString() ?? ''))]);
  obj.callMethod('catch', [js.allowInterop((dynamic e) => c.completeError(e?.toString() ?? 'OCR error'))]);
  return c.future;
}

/// Lê o parâmetro ?ref= da URL atual do browser e retorna o valor.
/// Retorna string vazia se o parâmetro não existir ou ocorrer erro.
String webGetRefParam() {
  try {
    final href = html.window.location.href;
    final uri  = Uri.parse(href);
    return uri.queryParameters['ref'] ?? '';
  } catch (_) {
    return '';
  }
}

/// Retorna true se o browser tem SpeechRecognition API.
bool webHasSpeechRecognition() {
  final w = js.context;
  return w.hasProperty('SpeechRecognition') || w.hasProperty('webkitSpeechRecognition');
}

/// Wrapper da Web Speech API para uso no Dart.
class WebSpeechRecognizer {
  js.JsObject? _recog;
  String?      _activeKey;
  bool         _listening = false;

  bool get isListening => _listening;

  void start(String key, String lang, {
    required void Function(String transcript, bool isFinal) onResult,
    required void Function() onEnd,
    required void Function(String? code) onError,
  }) {
    if (_listening) stop();
    _activeKey = key;

    final w       = js.context;
    final ctor    = w.hasProperty('SpeechRecognition') ? 'SpeechRecognition' : 'webkitSpeechRecognition';
    final recog   = js.JsObject(w[ctor] as js.JsFunction, []);

    recog['lang']            = lang;
    recog['continuous']      = true;
    recog['interimResults']  = true;
    recog['maxAlternatives'] = 1;

    recog['onresult'] = js.allowInterop((dynamic event) {
      try {
        final ev      = event as js.JsObject;
        final results = ev['results'] as js.JsObject;
        final length  = (results['length'] as num).toInt();
        final start   = ev.hasProperty('resultIndex') ? (ev['resultIndex'] as num).toInt() : 0;
        String interim = '';
        for (int i = start; i < length; i++) {
          final r        = js.JsObject.fromBrowserObject(results.callMethod('item', [i]) ?? results[i]);
          final isFinal  = r['isFinal'] as bool? ?? false;
          final alt      = js.JsObject.fromBrowserObject(r.callMethod('item', [0]) ?? r[0]);
          final text     = alt['transcript'] as String? ?? '';
          if (isFinal) onResult(text, true) ; else interim += text;
        }
        if (interim.isNotEmpty) onResult(interim, false);
      } catch (_) {}
    });

    recog['onerror'] = js.allowInterop((dynamic event) {
      String? code;
      try { code = (event as js.JsObject)['error'] as String?; } catch (_) {}
      if (code == 'no-speech') return;
      _listening = false;
      onError(code);
    });

    recog['onend'] = js.allowInterop((dynamic _) {
      if (_listening && _activeKey == key) {
        try { recog.callMethod('start', []); return; } catch (_) {}
      }
      _listening = false;
      onEnd();
    });

    recog.callMethod('start', []);
    _recog     = recog;
    _listening = true;
  }

  void stop() {
    try { _recog?.callMethod('stop', []); } catch (_) {}
    _listening = false;
    _activeKey = null;
    _recog     = null;
  }

  void dispose() => stop();
}
