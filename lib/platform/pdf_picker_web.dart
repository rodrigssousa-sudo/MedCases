// pdf_picker_web.dart — Implementação Web usando dart:html.
// Compilado APENAS no target Web (dart2js / wasm).
// iOS/Android usam pdf_picker_stub.dart via conditional import.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';

/// Abre seletor de PDF no browser e retorna (bytes, nome, tamanho).
Future<({Uint8List bytes, String name, int size})?> webPickPdf() async {
  final completer = Completer<({Uint8List bytes, String name, int size})?>();

  final input = html.FileUploadInputElement()
    ..accept = 'application/pdf'
    ..style.display = 'none';
  html.document.body!.append(input);
  input.click();

  input.onChange.first.then((_) {
    final file = input.files?.first;
    if (file == null) {
      input.remove();
      completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoad.first.then((_) {
      final bytes = Uint8List.fromList(reader.result as List<int>);
      input.remove();
      completer.complete((bytes: bytes, name: file.name, size: file.size));
    });
    reader.onError.first.then((_) {
      input.remove();
      completer.complete(null);
    });
  });

  return completer.future;
}
