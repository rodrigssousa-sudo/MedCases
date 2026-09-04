import 'dart:typed_data';

/// AUDIO ENGINE V2 FOUNDATION
///
/// Contrato puro de captura. Esta camada NÃO transcreve, NÃO envia áudio à rede
/// e NÃO substitui o speech_to_text produtivo nesta build.
final class ClinicalPcmFormat {
  const ClinicalPcmFormat({
    this.sampleRate = 24000,
    this.channels = 1,
    this.bitsPerSample = 16,
    this.targetChunkDurationMs = 100,
  });

  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  final int targetChunkDurationMs;

  int get bytesPerSample => bitsPerSample ~/ 8;

  int get bytesPerSecond => sampleRate * channels * bytesPerSample;

  int get bytesPerChunk => (bytesPerSecond * targetChunkDurationMs) ~/ 1000;

  void validate() {
    if (sampleRate <= 0) {
      throw ArgumentError.value(sampleRate, 'sampleRate');
    }
    if (channels != 1) {
      throw ArgumentError.value(
        channels,
        'channels',
        'Audio Engine V2 foundation is intentionally mono.',
      );
    }
    if (bitsPerSample != 16) {
      throw ArgumentError.value(
        bitsPerSample,
        'bitsPerSample',
        'Audio Engine V2 foundation is intentionally PCM16.',
      );
    }
    if (targetChunkDurationMs < 20 || targetChunkDurationMs > 1000) {
      throw ArgumentError.value(
        targetChunkDurationMs,
        'targetChunkDurationMs',
      );
    }
    if ((bytesPerSecond * targetChunkDurationMs) % 1000 != 0) {
      throw ArgumentError(
        'PCM geometry must produce an integer number of bytes per chunk.',
      );
    }
  }
}

enum ClinicalAudioCaptureState {
  idle,
  recording,
  paused,
  stopped,
  disposed,
}

final class ClinicalAudioCaptureException implements Exception {
  const ClinicalAudioCaptureException(this.code, [this.cause]);

  final String code;
  final Object? cause;

  @override
  String toString() =>
      'ClinicalAudioCaptureException(code: $code, cause: $cause)';
}

/// Provider de bytes PCM. Não possui qualquer semântica de STT/ASR.
abstract interface class ClinicalAudioCaptureProvider {
  String get providerId;

  ClinicalPcmFormat get format;

  ClinicalAudioCaptureState get state;

  Stream<double> get amplitudeStream;

  Future<bool> hasPermission();

  Future<Stream<Uint8List>> start();

  Future<void> pause();

  Future<void> resume();

  Future<void> stop();

  Future<void> dispose();
}
