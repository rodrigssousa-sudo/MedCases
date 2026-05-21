// pdf_picker_stub.dart — Stub para iOS/Android/Desktop.
// Nenhuma dessas funções é chamada fora de kIsWeb == true.
import 'dart:typed_data';

/// Abre seletor de PDF no browser e retorna (bytes, nome, tamanho).
/// No iOS/Android retorna null — chamador deve checar kIsWeb antes de invocar.
Future<({Uint8List bytes, String name, int size})?> webPickPdf() async => null;
