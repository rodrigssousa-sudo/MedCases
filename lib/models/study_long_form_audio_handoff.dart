final class StudyLongFormAudioSegment {
  const StudyLongFormAudioSegment({
    required this.index,
    required this.path,
    required this.activeDurationMs,
  });

  final int index;
  final String path;
  final int activeDurationMs;
}

final class StudyLongFormAudioHandoff {
  const StudyLongFormAudioHandoff({
    required this.sessionId,
    required this.locale,
    required this.totalActiveDurationMs,
    required this.segments,
  });

  final String sessionId;
  final String locale;
  final int totalActiveDurationMs;
  final List<StudyLongFormAudioSegment> segments;

  bool get isUsable => segments.isNotEmpty && totalActiveDurationMs > 0;
}
