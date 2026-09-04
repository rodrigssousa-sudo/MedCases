import 'dart:typed_data';

import 'clinical_audio_capture_provider.dart';

/// Reempacota chunks arbitrários do plugin em frames PCM16 temporais estáveis.
///
/// O stream nativo não é obrigado a respeitar exatamente os limites de 100 ms.
/// Esta classe garante uma geometria determinística para a futura camada ASR.
final class ClinicalPcm16ChunkFramer {
  ClinicalPcm16ChunkFramer(this.format) {
    format.validate();
  }

  final ClinicalPcmFormat format;

  final BytesBuilder _pending = BytesBuilder(copy: false);

  int get pendingBytes => _pending.length;

  List<Uint8List> add(Uint8List input) {
    if (input.isEmpty) {
      return const <Uint8List>[];
    }

    _pending.add(input);
    if (_pending.length < format.bytesPerChunk) {
      return const <Uint8List>[];
    }

    final bytes = _pending.takeBytes();
    final frames = <Uint8List>[];
    var offset = 0;

    while (bytes.length - offset >= format.bytesPerChunk) {
      frames.add(
        Uint8List.sublistView(
          bytes,
          offset,
          offset + format.bytesPerChunk,
        ),
      );
      offset += format.bytesPerChunk;
    }

    if (offset < bytes.length) {
      _pending.add(Uint8List.sublistView(bytes, offset));
    }

    return frames;
  }

  Uint8List? flush() {
    if (_pending.length == 0) {
      return null;
    }
    return _pending.takeBytes();
  }

  void reset() {
    if (_pending.length > 0) {
      _pending.takeBytes();
    }
  }
}
