import 'dart:math' as math;

/// Read-only observations of the recorder's measured peak dBFS, never synthetic.
enum RecordingInputQuality { unavailable, tooLow, good, high, clipping }

class RecordingInputLevel {
  const RecordingInputLevel(
      {this.dbfs, this.history = const [], this.silenceMs = 0});
  final double? dbfs;
  final List<double> history;
  final int silenceMs;
  RecordingInputQuality get quality {
    final value = dbfs;
    if (value == null) return RecordingInputQuality.unavailable;
    if (value >= -1) return RecordingInputQuality.clipping;
    if (value >= -8) return RecordingInputQuality.high;
    if (value < -42) return RecordingInputQuality.tooLow;
    return RecordingInputQuality.good;
  }

  double get normalized => dbfs == null ? 0 : ((dbfs! + 60) / 60).clamp(0, 1);
}

/// Energy-based activity detector. It is conservative: silence is never removed
/// and a quiet observation alone is never treated as microphone failure.
class RecordingLevelMonitor {
  final List<double> _history = [];
  double _floor = -65;
  int _silenceMs = 0;
  RecordingInputLevel add(double dbfs, {int intervalMs = 120}) {
    if (!dbfs.isFinite) return const RecordingInputLevel();
    dbfs = dbfs.clamp(-160, 0);
    if (dbfs < _floor + 6) _floor = (_floor * .96 + dbfs * .04).clamp(-80, -42);
    final threshold = math.max(-50.0, _floor + 10);
    _silenceMs = dbfs < threshold ? _silenceMs + intervalMs : 0;
    _history.add(((dbfs + 60) / 60).clamp(0, 1));
    if (_history.length > 48) _history.removeAt(0);
    return RecordingInputLevel(
        dbfs: dbfs,
        history: List.unmodifiable(_history),
        silenceMs: _silenceMs);
  }

  void reset() {
    _history.clear();
    _silenceMs = 0;
    _floor = -65;
  }
}
