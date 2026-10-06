import '../../models/study_workspace_model.dart';

/// Pure, opt-in development migration. It never writes preferences or deletes audio.
/// Callers must independently confirm these IDs belong to test data before saving.
final class RecordingSourceCleanupPreview {
  const RecordingSourceCleanupPreview(this.study, this.removedSourceIds);
  final Study study;
  final List<String> removedSourceIds;
}

RecordingSourceCleanupPreview previewRecordingSourceCleanup(Study study,
    {required Set<String> confirmedTestSourceIds}) {
  final groups = <String, List<StudySource>>{};
  for (final source in study.sources) {
    final sid = source.recordingSessionId;
    if (source.type == StudySourceType.recordedAudio &&
        sid != null &&
        sid.isNotEmpty) (groups[sid] ??= []).add(source);
  }
  final replacements = <String, StudySource>{};
  final removed = <String, String>{};
  int rank(StudySource s) => s.isAccepted
      ? 5
      : s.canReview
          ? 4
          : s.text.trim().isNotEmpty
              ? 3
              : s.audioPaths.isNotEmpty
                  ? 2
                  : 1;
  for (final group in groups.values) {
    if (group.length < 2 ||
        !group.every((s) => confirmedTestSourceIds.contains(s.id))) continue;
    // Conflicting transcripts need human review; neither is discarded.
    if (group
            .where((s) => s.text.trim().isNotEmpty)
            .map((s) => s.text)
            .toSet()
            .length >
        1) continue;
    group.sort((a, b) => rank(b).compareTo(rank(a)));
    final keep = group.first;
    final audio = group.expand((s) => s.audioPaths).toSet().toList();
    replacements[keep.id] = keep.bindRecording(keep.recordingSessionId!, audio,
        group.map((s) => s.audioDurationMs).reduce((a, b) => a > b ? a : b));
    for (final duplicate in group.skip(1)) {
      removed[duplicate.id] = keep.id;
    }
  }
  return RecordingSourceCleanupPreview(
      study.copyWith(
          sources: study.sources
              .where((s) => !removed.containsKey(s.id))
              .map((s) => replacements[s.id] ?? s)
              .toList(),
          artifacts: study.artifacts
              .map((a) => StudyArtifact(
                  id: a.id,
                  type: a.type,
                  title: a.title,
                  content: a.content,
                  createdAtUtc: a.createdAtUtc,
                  sourceIds: a.sourceIds
                      .map((id) => removed[id] ?? id)
                      .toSet()
                      .toList()))
              .toList()),
      List.unmodifiable(removed.keys));
}
