import 'clinical_long_form_audio_contract.dart';
import 'clinical_long_form_recording_manifest.dart';

final class ClinicalLongFormRecordingSession {
  ClinicalLongFormRecordingSession({
    required String sessionId,
    required String locale,
    required ClinicalLongFormFileCapture capture,
    ClinicalLongFormRecordingConfig config =
        const ClinicalLongFormRecordingConfig(),
  })  : _sessionId = sessionId.trim(),
        _locale = locale.trim(),
        _capture = capture,
        _config = config {
    if (_sessionId.isEmpty) {
      throw ArgumentError.value(sessionId, 'sessionId');
    }
    if (_locale.isEmpty) {
      throw ArgumentError.value(locale, 'locale');
    }
    _config.validate();
  }

  final String _sessionId;
  final String _locale;
  final ClinicalLongFormFileCapture _capture;
  final ClinicalLongFormRecordingConfig _config;

  final List<ClinicalLongFormSegmentManifest> _completedSegments =
      <ClinicalLongFormSegmentManifest>[];

  ClinicalLongFormRecordingState _state = ClinicalLongFormRecordingState.idle;

  DateTime? _createdAtUtc;
  DateTime? _currentSegmentStartedAtUtc;
  DateTime? _activeStartedAtUtc;
  String? _currentPath;

  Duration _completedActiveDuration = Duration.zero;
  Duration _currentSegmentAccumulated = Duration.zero;

  ClinicalLongFormRecordingState get state => _state;
  ClinicalLongFormRecordingConfig get config => _config;

  Duration activeDurationAt(DateTime nowUtc) {
    var total = _completedActiveDuration + _currentSegmentAccumulated;

    final activeStart = _activeStartedAtUtc;
    if (_state == ClinicalLongFormRecordingState.recording &&
        activeStart != null) {
      total += _positiveDuration(activeStart, nowUtc.toUtc());
    }

    return total;
  }

  bool shouldRotate(DateTime nowUtc) {
    if (_state != ClinicalLongFormRecordingState.recording) {
      return false;
    }

    var segmentActive = _currentSegmentAccumulated;
    final activeStart = _activeStartedAtUtc;
    if (activeStart != null) {
      segmentActive += _positiveDuration(activeStart, nowUtc.toUtc());
    }

    return segmentActive >= _config.segmentDuration;
  }

  bool reachedMaxDuration(DateTime nowUtc) =>
      activeDurationAt(nowUtc) >= _config.maxDuration;

  Future<void> start({
    required String firstSegmentPath,
    required DateTime nowUtc,
  }) async {
    if (_state != ClinicalLongFormRecordingState.idle) {
      throw StateError('Long-form session already started.');
    }

    final now = nowUtc.toUtc();
    _createdAtUtc = now;
    await _startSegment(firstSegmentPath, now);
    _state = ClinicalLongFormRecordingState.recording;
  }

  Future<void> pause(DateTime nowUtc) async {
    if (_state != ClinicalLongFormRecordingState.recording) {
      throw StateError('Long-form session is not recording.');
    }

    _accumulateCurrentActive(nowUtc.toUtc());
    await _capture.pause();
    _state = ClinicalLongFormRecordingState.paused;
  }

  Future<void> resume(DateTime nowUtc) async {
    if (_state != ClinicalLongFormRecordingState.paused) {
      throw StateError('Long-form session is not paused.');
    }

    if (reachedMaxDuration(nowUtc.toUtc())) {
      throw StateError('Long-form maximum duration reached.');
    }

    await _capture.resume();
    _activeStartedAtUtc = nowUtc.toUtc();
    _state = ClinicalLongFormRecordingState.recording;
  }

  Future<void> rotate({
    required String nextSegmentPath,
    required DateTime nowUtc,
  }) async {
    if (_state != ClinicalLongFormRecordingState.recording) {
      throw StateError('Rotate requires active recording.');
    }

    final now = nowUtc.toUtc();
    _accumulateCurrentActive(now);

    await _capture.stopSegment();
    _completeCurrentSegment();

    if (_completedActiveDuration >= _config.maxDuration) {
      _state = ClinicalLongFormRecordingState.stopped;
      return;
    }

    await _startSegment(nextSegmentPath, now);
    _state = ClinicalLongFormRecordingState.recording;
  }

  Future<void> stop(DateTime nowUtc) async {
    if (_state == ClinicalLongFormRecordingState.stopped ||
        _state == ClinicalLongFormRecordingState.idle) {
      return;
    }

    final now = nowUtc.toUtc();

    if (_state == ClinicalLongFormRecordingState.recording) {
      _accumulateCurrentActive(now);
    }

    await _capture.stopSegment();
    _completeCurrentSegment();
    _state = ClinicalLongFormRecordingState.stopped;
  }

  ClinicalLongFormRecordingManifest snapshot(DateTime nowUtc) {
    final created = _createdAtUtc;
    if (created == null) {
      throw StateError('Long-form session has not started.');
    }

    final segments = <ClinicalLongFormSegmentManifest>[
      ..._completedSegments,
    ];

    final path = _currentPath;
    final started = _currentSegmentStartedAtUtc;

    if (path != null && started != null) {
      var duration = _currentSegmentAccumulated;
      final activeStart = _activeStartedAtUtc;

      if (_state == ClinicalLongFormRecordingState.recording &&
          activeStart != null) {
        duration += _positiveDuration(
          activeStart,
          nowUtc.toUtc(),
        );
      }

      segments.add(
        ClinicalLongFormSegmentManifest(
          index: _completedSegments.length,
          path: path,
          startedAtUtc: started,
          activeDuration: duration,
          completed: false,
        ),
      );
    }

    return ClinicalLongFormRecordingManifest(
      sessionId: _sessionId,
      locale: _locale,
      state: _state,
      createdAtUtc: created,
      totalActiveDuration: activeDurationAt(nowUtc.toUtc()),
      segments: segments,
    );
  }

  Future<void> dispose() => _capture.dispose();

  Future<void> _startSegment(
    String path,
    DateTime nowUtc,
  ) async {
    if (!path.toLowerCase().endsWith('.m4a')) {
      throw ArgumentError.value(path, 'path');
    }

    await _capture.startSegment(
      path: path,
      config: _config,
    );

    _currentPath = path;
    _currentSegmentStartedAtUtc = nowUtc;
    _activeStartedAtUtc = nowUtc;
    _currentSegmentAccumulated = Duration.zero;
  }

  void _accumulateCurrentActive(DateTime nowUtc) {
    final activeStart = _activeStartedAtUtc;
    if (activeStart == null) {
      return;
    }

    _currentSegmentAccumulated += _positiveDuration(
      activeStart,
      nowUtc,
    );
    _activeStartedAtUtc = null;
  }

  void _completeCurrentSegment() {
    final path = _currentPath;
    final started = _currentSegmentStartedAtUtc;

    if (path == null || started == null) {
      return;
    }

    _completedSegments.add(
      ClinicalLongFormSegmentManifest(
        index: _completedSegments.length,
        path: path,
        startedAtUtc: started,
        activeDuration: _currentSegmentAccumulated,
        completed: true,
      ),
    );

    _completedActiveDuration += _currentSegmentAccumulated;
    _currentPath = null;
    _currentSegmentStartedAtUtc = null;
    _activeStartedAtUtc = null;
    _currentSegmentAccumulated = Duration.zero;
  }

  static Duration _positiveDuration(
    DateTime startUtc,
    DateTime endUtc,
  ) {
    if (endUtc.isBefore(startUtc)) {
      throw ArgumentError('Time cannot move backwards.');
    }
    return endUtc.difference(startUtc);
  }
}
