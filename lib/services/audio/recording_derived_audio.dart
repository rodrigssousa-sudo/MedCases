import 'continuous_aac_file.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Optional, immutable-source enhancement. Unsupported devices use the master.
class RecordingDerivedAudio {
  static const _channel = MethodChannel('medcases/recording_derived_audio_v1');
  static final Map<String, Future<String>> _pending = {};
  static Future<void> waitForMasters(Iterable<String> masters) async {
    final pending = masters
        .map((path) => _pending[path])
        .whereType<Future<String>>()
        .toList();
    await Future.wait(pending).timeout(const Duration(seconds: 10));
  }

  static Future<String> prepare(String master) {
    final existing = _pending[master];
    if (existing != null) return existing;
    final future = _prepare(master);
    _pending[master] = future;
    return future.whenComplete(() => _pending.remove(master));
  }

  static Future<String> _prepare(String master) async {
    if (!Platform.isIOS) return master;
    final output =
        '${File(master).parent.path}/derived_${File(master).uri.pathSegments.last.replaceAll('.m4a', '.wav')}';
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
          'prepare', {'source': master, 'destination': output});
      if (result?['path'] == output &&
          await File(output).exists() &&
          await File(output).length() > 0) return output;
    } on PlatformException {
      /* Never risk the master or block recovery for DSP. */
    } on MissingPluginException {
      /* Older native builds retain the original path. */
    }
    return master;
  }
}

/// Only apply when the capture metadata proves an actual overlap. Repeated
/// clinical language across non-overlapping segments must never be discarded.
String removeProvenTranscriptOverlap(String previous, String next,
    {required bool hasAudioOverlap}) {
  if (!hasAudioOverlap) return next;
  final a = previous.trim().split(RegExp(r'\s+'));
  final b = next.trim().split(RegExp(r'\s+'));
  String normalized(String word) =>
      word.toLowerCase().replaceAll(RegExp(r'[,.;:!?]'), '');
  for (var count = a.length < b.length ? a.length : b.length;
      count >= 3;
      count--) {
    if (count > 30) continue;
    if (List.generate(count, (i) => normalized(a[a.length - count + i]))
            .join(' ') ==
        b.take(count).map(normalized).join(' ')) {
      return b.skip(count).join(' ');
    }
  }
  return next;
}

/// Same conservative AAC-LC access-unit duration used by the gateway. The
/// display timer excludes encoder priming/padding and is not a media budget.
int aacTranscriptionDurationMs(Uint8List bytes, {bool longRecording = false}) {
  if (longRecording && bytes.length >= 2 && bytes[0] == 255) {
    return continuousAacDurationMs(bytes);
  }
  final data = ByteData.sublistView(bytes);
  int? frames, rate;
  int operations = 0, tracks = 0;
  void walk(int start, int end, int depth) {
    if (depth > 10) throw const FormatException('invalid_audio');
    for (var at = start; at < end;) {
      if (++operations > 1000 || at + 8 > end)
        throw const FormatException('invalid_audio');
      var size = data.getUint32(at);
      var header = 8;
      final type = String.fromCharCodes(bytes.sublist(at + 4, at + 8));
      if (size == 1) {
        if (at + 16 > end) throw const FormatException('invalid_audio');
        size = data.getUint64(at + 8);
        header = 16;
      }
      if (size == 0 && type == 'mdat' && depth == 0) size = end - at;
      if (size < header || at + size > end)
        throw const FormatException('invalid_audio');
      final body = at + header, stop = at + size;
      if (type == 'trak' && ++tracks > 1)
        throw const FormatException('invalid_audio');
      if (type == 'stsz') {
        if (frames != null || body + 12 > stop)
          throw const FormatException('invalid_audio');
        frames = data.getUint32(body + 8);
      }
      if (type == 'mdhd') {
        if (body >= stop) throw const FormatException('invalid_audio');
        final offset = bytes[body] == 1
            ? 20
            : bytes[body] == 0
                ? 12
                : -1;
        if (rate != null || offset < 0 || body + offset + 4 > stop)
          throw const FormatException('invalid_audio');
        rate = data.getUint32(body + offset);
      }
      if (const {'moov', 'trak', 'mdia', 'minf', 'stbl'}.contains(type))
        walk(body, stop, depth + 1);
      at = stop;
    }
  }

  walk(0, bytes.length, 0);
  if (tracks != 1 ||
      frames == null ||
      frames! <= 0 ||
      frames! > (longRecording ? 253126 : 50000) ||
      rate == null ||
      rate! < 8000 ||
      rate! > 48000) throw const FormatException('invalid_audio');
  return (frames! * 1024 * 1000 + rate! - 1) ~/ rate!;
}

int transcriptionMediaDurationMs(Uint8List bytes,
    {bool longRecording = false}) {
  if (bytes.length >= 44 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF') {
    final d = ByteData.sublistView(bytes);
    final length = d.getUint32(40, Endian.little);
    final rate = d.getUint32(24, Endian.little);
    final align = d.getUint16(32, Endian.little);
    if (String.fromCharCodes(bytes.sublist(8, 16)) != 'WAVEfmt ' ||
        d.getUint32(16, Endian.little) != 16 ||
        d.getUint16(20, Endian.little) != 1 ||
        String.fromCharCodes(bytes.sublist(36, 40)) != 'data' ||
        length != bytes.length - 44 ||
        rate < 8000 ||
        rate > 48000 ||
        align <= 0 ||
        length % align != 0) {
      throw const FormatException('invalid_audio');
    }
    return (length * 1000 + align * rate - 1) ~/ (align * rate);
  }
  return aacTranscriptionDurationMs(bytes, longRecording: longRecording);
}
