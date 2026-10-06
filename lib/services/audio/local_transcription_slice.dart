import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'continuous_aac_file.dart';

/// Immutable AAC original; only complete frames enter a separate derived file.
class LocalTranscriptionSlice {
  const LocalTranscriptionSlice(
      {required this.path,
      required this.startFrame,
      required this.endFrame,
      required this.totalFrames,
      required this.sampleRate,
      required this.originalSha256});
  final String path, originalSha256;
  final int startFrame, endFrame, totalFrames, sampleRate;
  int get durationMs =>
      ((endFrame - startFrame) * 1024 * 1000 / sampleRate).ceil();
  int get originalDurationMs => (totalFrames * 1024 * 1000 / sampleRate).ceil();
  int get transcribedUntilMs => (endFrame * 1024 * 1000 / sampleRate).ceil();
  int get remainingMs =>
      ((totalFrames - endFrame) * 1024 * 1000 / sampleRate).ceil();

  static Future<LocalTranscriptionSlice> prepare(
      {required String original,
      required String destination,
      required int startFrame,
      required int allowedMs}) async {
    if (startFrame < 0 || allowedMs <= 0 || original == destination)
      throw StateError('INVALID_TRANSCRIPTION_RANGE');
    if (await File(destination).exists() ||
        await File('$destination.pending').exists())
      throw StateError('DERIVED_FILE_EXISTS');
    final originalSha256 =
        (await sha256.bind(File(original).openRead()).first).toString();
    final input = await File(original).open();
    final pending = File('$destination.pending');
    final output = await pending.open(mode: FileMode.writeOnly);
    var frames = 0, end = startFrame;
    int? rate, channels;
    try {
      while (true) {
        final header = await input.read(7);
        if (header.isEmpty) break;
        final h = aacFrameHeader(Uint8List.fromList(header), 0);
        if (rate != null && (rate != h.rate || channels != h.channels))
          throw const FormatException('invalid_audio');
        rate = h.rate;
        channels = h.channels;
        final rest = await input.read(h.length - 7);
        if (rest.length != h.length - 7)
          throw const FormatException('invalid_audio');
        final selected = frames >= startFrame &&
            ((frames - startFrame + 1) * 1024 * 1000 / rate).ceil() <=
                allowedMs;
        if (selected) {
          await output.writeFrom(header);
          await output.writeFrom(rest);
          end = frames + 1;
        }
        frames++;
      }
      if (rate == null || end <= startFrame || startFrame >= frames)
        throw StateError('TRANSCRIPTION_RANGE_EMPTY');
      await output.flush();
      await output.close();
      await input.close();
      final finalFingerprint =
          (await sha256.bind(File(original).openRead()).first).toString();
      if (finalFingerprint != originalSha256)
        throw StateError('ORIGINAL_AUDIO_CHANGED');
      await pending.rename(destination);
      return LocalTranscriptionSlice(
          path: destination,
          startFrame: startFrame,
          endFrame: end,
          totalFrames: frames,
          sampleRate: rate,
          originalSha256: originalSha256);
    } catch (_) {
      try {
        await output.close();
      } catch (_) {}
      try {
        await input.close();
      } catch (_) {}
      if (await pending.exists())
        await pending.delete(); // Only our derivative.
      rethrow;
    }
  }
}
