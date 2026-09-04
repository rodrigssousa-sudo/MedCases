import 'dart:math' as math;
import 'dart:typed_data';

import 'clinical_audio_capture_provider.dart';

final class ClinicalPcmRuntimeSnapshot {
  const ClinicalPcmRuntimeSnapshot({
    required this.elapsedActive,
    required this.frameCount,
    required this.totalBytes,
    required this.fullFrameCount,
    required this.tailFrameCount,
    required this.minFrameBytes,
    required this.maxFrameBytes,
    required this.bytesPerSecondObserved,
    required this.estimatedSampleRateHz,
    required this.intervalAverageMs,
    required this.intervalP50Ms,
    required this.intervalP95Ms,
    required this.intervalMaxMs,
    required this.amplitudeCurrent,
    required this.amplitudeAverage,
    required this.amplitudePeak,
  });

  final Duration elapsedActive;
  final int frameCount;
  final int totalBytes;
  final int fullFrameCount;
  final int tailFrameCount;
  final int minFrameBytes;
  final int maxFrameBytes;
  final double bytesPerSecondObserved;
  final double estimatedSampleRateHz;
  final double intervalAverageMs;
  final double intervalP50Ms;
  final double intervalP95Ms;
  final double intervalMaxMs;
  final double amplitudeCurrent;
  final double amplitudeAverage;
  final double amplitudePeak;

  String toReport(ClinicalPcmFormat format, String providerId) {
    String f(double value, [int digits = 1]) =>
        value.isFinite ? value.toStringAsFixed(digits) : '0';
    return <String>[
      'MEDCASES_PCM_RUNTIME_PROBE=V1',
      'PROVIDER=$providerId',
      'FORMAT=PCM16',
      'REQUESTED_SAMPLE_RATE_HZ=${format.sampleRate}',
      'CHANNELS=${format.channels}',
      'BITS_PER_SAMPLE=${format.bitsPerSample}',
      'TARGET_CHUNK_MS=${format.targetChunkDurationMs}',
      'TARGET_CHUNK_BYTES=${format.bytesPerChunk}',
      'ACTIVE_ELAPSED_MS=${elapsedActive.inMilliseconds}',
      'FRAME_COUNT=$frameCount',
      'FULL_FRAME_COUNT=$fullFrameCount',
      'TAIL_FRAME_COUNT=$tailFrameCount',
      'TOTAL_BYTES=$totalBytes',
      'MIN_FRAME_BYTES=$minFrameBytes',
      'MAX_FRAME_BYTES=$maxFrameBytes',
      'OBSERVED_BYTES_PER_SECOND=${f(bytesPerSecondObserved)}',
      'ESTIMATED_SAMPLE_RATE_HZ=${f(estimatedSampleRateHz)}',
      'FRAME_INTERVAL_AVG_MS=${f(intervalAverageMs, 2)}',
      'FRAME_INTERVAL_P50_MS=${f(intervalP50Ms, 2)}',
      'FRAME_INTERVAL_P95_MS=${f(intervalP95Ms, 2)}',
      'FRAME_INTERVAL_MAX_MS=${f(intervalMaxMs, 2)}',
      'AMPLITUDE_CURRENT=${f(amplitudeCurrent, 3)}',
      'AMPLITUDE_AVG=${f(amplitudeAverage, 3)}',
      'AMPLITUDE_PEAK=${f(amplitudePeak, 3)}',
      'AUDIO_SAVED=NO',
      'AUDIO_UPLOADED=NO',
      'TRANSCRIPTION=NO',
    ].join('\n');
  }
}

final class ClinicalPcmRuntimeMetrics {
  ClinicalPcmRuntimeMetrics(this.format) {
    format.validate();
  }

  final ClinicalPcmFormat format;
  final Stopwatch _clock = Stopwatch();
  final List<int> _intervals = <int>[];
  int? _lastUs;
  int _frames = 0;
  int _bytes = 0;
  int _full = 0;
  int _tail = 0;
  int? _minBytes;
  int _maxBytes = 0;
  double _ampCurrent = 0;
  double _ampSum = 0;
  double _ampPeak = 0;
  int _ampSamples = 0;

  void start() {
    reset();
    _clock.start();
  }

  void pause() {
    _clock.stop();
    _lastUs = null;
  }

  void resume() {
    if (!_clock.isRunning) _clock.start();
    _lastUs = null;
  }

  void stop() {
    _clock.stop();
    _lastUs = null;
  }

  void reset() {
    _clock
      ..stop()
      ..reset();
    _intervals.clear();
    _lastUs = null;
    _frames = 0;
    _bytes = 0;
    _full = 0;
    _tail = 0;
    _minBytes = null;
    _maxBytes = 0;
    _ampCurrent = 0;
    _ampSum = 0;
    _ampPeak = 0;
    _ampSamples = 0;
  }

  void addFrame(Uint8List data) {
    if (data.isEmpty) return;
    final now = _clock.elapsedMicroseconds;
    if (_lastUs != null && now >= _lastUs!) _intervals.add(now - _lastUs!);
    _lastUs = now;
    if (_intervals.length > 12000) _intervals.removeRange(0, 2000);
    _frames++;
    _bytes += data.length;
    _minBytes = math.min(_minBytes ?? data.length, data.length);
    _maxBytes = math.max(_maxBytes, data.length);
    if (data.length == format.bytesPerChunk) {
      _full++;
    } else {
      _tail++;
    }
  }

  void addAmplitude(double value) {
    final v = value.clamp(0.0, 1.0).toDouble();
    _ampCurrent = v;
    _ampSum += v;
    _ampSamples++;
    _ampPeak = math.max(_ampPeak, v);
  }

  ClinicalPcmRuntimeSnapshot snapshot() {
    final seconds = _clock.elapsedMicroseconds <= 0
        ? 0.0
        : _clock.elapsedMicroseconds / Duration.microsecondsPerSecond;
    final bps = seconds <= 0 ? 0.0 : _bytes / seconds;
    final hz = bps <= 0 ? 0.0 : bps / (format.channels * format.bytesPerSample);
    final sorted = List<int>.from(_intervals)..sort();
    double pct(double p) {
      if (sorted.isEmpty) return 0;
      final i = ((sorted.length - 1) * p).round().clamp(0, sorted.length - 1);
      return sorted[i] / 1000.0;
    }

    final avg = _intervals.isEmpty
        ? 0.0
        : _intervals.reduce((a, b) => a + b) / _intervals.length / 1000.0;
    return ClinicalPcmRuntimeSnapshot(
      elapsedActive: _clock.elapsed,
      frameCount: _frames,
      totalBytes: _bytes,
      fullFrameCount: _full,
      tailFrameCount: _tail,
      minFrameBytes: _minBytes ?? 0,
      maxFrameBytes: _maxBytes,
      bytesPerSecondObserved: bps,
      estimatedSampleRateHz: hz,
      intervalAverageMs: avg,
      intervalP50Ms: pct(.50),
      intervalP95Ms: pct(.95),
      intervalMaxMs: sorted.isEmpty ? 0 : sorted.last / 1000.0,
      amplitudeCurrent: _ampCurrent,
      amplitudeAverage: _ampSamples == 0 ? 0 : _ampSum / _ampSamples,
      amplitudePeak: _ampPeak,
    );
  }
}
