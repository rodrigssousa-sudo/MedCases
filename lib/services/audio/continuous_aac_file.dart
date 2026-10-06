import 'dart:io';
import 'dart:typed_data';

/// AAC-LC ADTS frames are individually recoverable without a final MP4 index.
/// Only complete frames reach disk; a crash cannot invalidate earlier frames.
class ContinuousAacFile {
  ContinuousAacFile(this.path, {DateTime Function()? now, bool append = false})
      : _now = now ?? DateTime.now,
        _file = _open(path, append) {
    _lastFlush = _now();
    _writtenBytes = _file.lengthSync();
    if (_writtenBytes > 0) {
      final reader = File(path).openSync();
      try {
        final h = aacFrameHeader(reader.readSync(7), 0);
        _rate = h.rate;
        _channels = h.channels;
      } finally {
        reader.closeSync();
      }
    }
  }
  static RandomAccessFile _open(String path, bool append) {
    final file = File(path);
    if (append) {
      final scan = inspectContinuousAacFile(path, allowIncompleteTail: true);
      if (scan.bytes > 0 && scan.completeBytes == 0) {
        throw const FormatException('invalid_audio');
      }
      if (scan.completeBytes < scan.bytes) {
        // Preserve every original byte before removing an incomplete crash tail.
        var suffix = 0;
        File backup;
        do {
          backup = File('$path.crash-preserved-${suffix++}');
        } while (backup.existsSync());
        file.copySync(backup.path);
        final repair = File('$path.recovering');
        final input = file.openSync();
        final output = repair.openSync(mode: FileMode.writeOnly);
        try {
          var remaining = scan.completeBytes;
          while (remaining > 0) {
            final chunk = input.readSync(remaining.clamp(0, 64 * 1024));
            if (chunk.isEmpty) throw const FormatException('invalid_audio');
            output.writeFromSync(chunk);
            remaining -= chunk.length;
          }
          output.flushSync();
        } finally {
          input.closeSync();
          output.closeSync();
        }
        repair.renameSync(path);
      }
      return file.openSync(mode: FileMode.append);
    }
    if (file.existsSync() && file.lengthSync() > 0)
      throw StateError('RECORDING_FILE_EXISTS');
    return file.openSync(mode: FileMode.writeOnly);
  }

  final String path;
  final RandomAccessFile _file;
  final DateTime Function() _now;
  late DateTime _lastFlush;
  Uint8List _tail = Uint8List(0);
  int? _rate, _channels;
  bool _closed = false;
  int writtenFrames = 0;
  int _writtenBytes = 0;

  void add(Uint8List chunk) {
    if (_closed) throw StateError('RECORDING_FILE_CLOSED');
    if (chunk.length > 1024 * 1024) throw StateError('RECORDING_FRAME_INVALID');
    final bytes = Uint8List(_tail.length + chunk.length)
      ..setAll(0, _tail)
      ..setAll(_tail.length, chunk);
    var offset = 0;
    while (bytes.length - offset >= 7) {
      final header = aacFrameHeader(bytes, offset);
      if (_rate != null &&
          (_rate != header.rate || _channels != header.channels)) {
        throw StateError('RECORDING_FRAME_INVALID');
      }
      if (bytes.length - offset < header.length) break;
      _rate = header.rate;
      _channels = header.channels;
      _file.writeFromSync(bytes, offset, offset + header.length);
      _writtenBytes += header.length;
      writtenFrames++;
      offset += header.length;
    }
    _tail = Uint8List.fromList(bytes.sublist(offset));
    if (_tail.length > 8191) throw StateError('RECORDING_FRAME_INVALID');
    if (_now().difference(_lastFlush) >= const Duration(seconds: 10)) {
      _file.flushSync();
      _lastFlush = _now();
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    try {
      _file.flushSync();
    } finally {
      _file.closeSync();
    }
    if (_tail.isNotEmpty) throw StateError('RECORDING_INCOMPLETE_FRAME');
  }
}

({int length, int rate, int channels}) aacFrameHeader(Uint8List b, int at) {
  const rates = [
    96000,
    88200,
    64000,
    48000,
    44100,
    32000,
    24000,
    22050,
    16000,
    12000,
    11025,
    8000,
    7350
  ];
  if (at + 7 > b.length ||
      b[at] != 255 ||
      (b[at + 1] & 0xfe) != 0xf0 ||
      (b[at + 1] & 1) != 1 ||
      (b[at + 2] >> 6) != 1 ||
      (b[at + 6] & 3) != 0) {
    throw const FormatException('invalid_audio');
  }
  final index = (b[at + 2] >> 2) & 15;
  final channels = ((b[at + 2] & 1) << 2) | (b[at + 3] >> 6);
  final length = ((b[at + 3] & 3) << 11) | (b[at + 4] << 3) | (b[at + 5] >> 5);
  if (index >= rates.length ||
      rates[index] < 8000 ||
      rates[index] > 48000 ||
      ![1, 2].contains(channels) ||
      length <= 7) {
    throw const FormatException('invalid_audio');
  }
  return (length: length, rate: rates[index], channels: channels);
}

int continuousAacDurationMs(Uint8List bytes) {
  int offset = 0, frames = 0;
  int? rate, channels;
  if (bytes.isEmpty) throw const FormatException('invalid_audio');
  while (offset < bytes.length) {
    final h = aacFrameHeader(bytes, offset);
    if (rate != null && (rate != h.rate || channels != h.channels) ||
        offset + h.length > bytes.length) {
      throw const FormatException('invalid_audio');
    }
    rate = h.rate;
    channels = h.channels;
    frames++;
    offset += h.length;
  }
  final duration = (frames * 1024 * 1000 / rate!).ceil();
  return duration;
}

/// Only an incomplete final frame can be recovered. Interior corruption fails.
int recoverableAacPrefix(Uint8List bytes) {
  var offset = 0;
  int? rate, channels;
  while (offset < bytes.length) {
    if (bytes.length - offset < 7) return offset;
    final h = aacFrameHeader(bytes, offset);
    if (rate != null && (rate != h.rate || channels != h.channels))
      throw const FormatException('invalid_audio');
    if (offset + h.length > bytes.length) return offset;
    rate = h.rate;
    channels = h.channels;
    offset += h.length;
  }
  return offset;
}

/// Scan from disk with constant memory. Long originals never need to be loaded
/// into RAM just to resume capture or determine their duration.
({int bytes, int completeBytes, int frames, int durationMs})
    inspectContinuousAacFile(String path, {bool allowIncompleteTail = false}) {
  final input = File(path).openSync();
  try {
    final length = input.lengthSync();
    int offset = 0, frames = 0;
    int? rate, channels;
    while (offset < length) {
      if (length - offset < 7) {
        if (allowIncompleteTail) break;
        throw const FormatException('invalid_audio');
      }
      input.setPositionSync(offset);
      final h = aacFrameHeader(input.readSync(7), 0);
      if (rate != null && (rate != h.rate || channels != h.channels)) {
        throw const FormatException('invalid_audio');
      }
      if (offset + h.length > length) {
        if (allowIncompleteTail) break;
        throw const FormatException('invalid_audio');
      }
      rate = h.rate;
      channels = h.channels;
      offset += h.length;
      frames++;
    }
    if (length > 0 && frames == 0) throw const FormatException('invalid_audio');
    return (
      bytes: length,
      completeBytes: offset,
      frames: frames,
      durationMs: rate == null ? 0 : (frames * 1024 * 1000 / rate).ceil()
    );
  } finally {
    input.closeSync();
  }
}
