enum StudySourceType { recordedAudio, uploadedAudio, pdf, image, text }

enum StudySourceState {
  added,
  processing,
  review,
  accepted,
  failed,
  transcriptionPending,
  retryableError,
  terminalError
}

enum StudyArtifactType {
  visualSummary,
  fullSummary,
  examSummary,
  mindMap,
  flashcards,
  questionsAndAnswers,
  multipleChoice,
  oralExam,
  keyPoints,
  comparisonTable,
  finalPdf,
}

final class SourceRef {
  const SourceRef({
    required this.sourceId,
    required this.sourceType,
    this.pageNumber,
    this.timestampStartMs,
    this.timestampEndMs,
    this.imageIndex,
    this.textBlockIndex,
  });

  final String sourceId;
  final StudySourceType sourceType;
  final int? pageNumber;
  final int? timestampStartMs;
  final int? timestampEndMs;
  final int? imageIndex;
  final int? textBlockIndex;

  String label({required bool isEs}) {
    switch (sourceType) {
      case StudySourceType.pdf:
        return pageNumber == null ? 'PDF' : 'PDF · pág. $pageNumber';
      case StudySourceType.recordedAudio:
      case StudySourceType.uploadedAudio:
        return timestampStartMs == null
            ? (isEs ? 'Audio' : 'Áudio')
            : '${isEs ? "Audio" : "Áudio"} · ${_clock(timestampStartMs!)}';
      case StudySourceType.image:
        return imageIndex == null
            ? (isEs ? 'Imagen' : 'Imagem')
            : '${isEs ? "Imagen" : "Imagem"} · $imageIndex';
      case StudySourceType.text:
        return textBlockIndex == null
            ? 'Texto'
            : '${isEs ? "Texto · bloque" : "Texto · bloco"} $textBlockIndex';
    }
  }

  static String _clock(int ms) {
    final seconds = ms ~/ 1000;
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
}

final class StudySource {
  const StudySource({
    required this.id,
    required this.type,
    required this.title,
    required this.state,
    required this.createdAtUtc,
    this.text = '',
    this.refs = const <SourceRef>[],
    this.errorCode,
    this.recordingSessionId,
    this.audioPaths = const [],
    this.audioDurationMs = 0,
  });

  final String id;
  final StudySourceType type;
  final String title;
  final StudySourceState state;
  final DateTime createdAtUtc;
  final String text;
  final List<SourceRef> refs;
  final String? errorCode;
  final String? recordingSessionId;
  final List<String> audioPaths;
  final int audioDurationMs;

  static String recordingIdentity(String sessionId) => 'recording_$sessionId';
  bool get isTranscriptionPending =>
      state == StudySourceState.transcriptionPending ||
      state == StudySourceState.retryableError ||
      (state == StudySourceState.failed &&
          errorCode == 'transcription_pending');
  bool get canRetryTranscription =>
      type == StudySourceType.recordedAudio &&
      recordingSessionId != null &&
      (isTranscriptionPending || state == StudySourceState.failed);
  bool get canReview =>
      state == StudySourceState.review && text.trim().isNotEmpty;

  StudySource bindRecording(
          String sessionId, List<String> paths, int durationMs) =>
      StudySource(
          id: id,
          type: type,
          title: title,
          state: state,
          createdAtUtc: createdAtUtc,
          text: text,
          refs: refs,
          errorCode: errorCode,
          recordingSessionId: sessionId,
          audioPaths: List.unmodifiable(paths),
          audioDurationMs: durationMs);

  bool get isAudio =>
      type == StudySourceType.recordedAudio ||
      type == StudySourceType.uploadedAudio;

  bool get isAccepted =>
      state == StudySourceState.accepted && text.trim().isNotEmpty;

  StudySource transition(
    StudySourceState next, {
    String? extractedText,
    List<SourceRef>? sourceRefs,
    String? error,
  }) {
    final allowed = <StudySourceState, Set<StudySourceState>>{
      StudySourceState.added: <StudySourceState>{
        StudySourceState.processing,
        StudySourceState.failed,
      },
      StudySourceState.processing: <StudySourceState>{
        StudySourceState.review,
        StudySourceState.failed,
      },
      StudySourceState.review: <StudySourceState>{
        StudySourceState.accepted,
        StudySourceState.failed,
      },
      StudySourceState.accepted: <StudySourceState>{},
      StudySourceState.failed: <StudySourceState>{StudySourceState.processing},
    };

    final recordingTransitions = type == StudySourceType.recordedAudio &&
        {
              StudySourceState.added: {
                StudySourceState.processing,
                StudySourceState.transcriptionPending,
                StudySourceState.review
              },
              StudySourceState.processing: {
                StudySourceState.review,
                StudySourceState.transcriptionPending,
                StudySourceState.retryableError,
                StudySourceState.terminalError
              },
              StudySourceState.transcriptionPending: {
                StudySourceState.processing,
                StudySourceState.review,
                StudySourceState.retryableError,
                StudySourceState.terminalError
              },
              StudySourceState.retryableError: {
                StudySourceState.processing,
                StudySourceState.review,
                StudySourceState.transcriptionPending,
                StudySourceState.terminalError
              },
              StudySourceState.terminalError: {StudySourceState.review},
              StudySourceState.failed: {
                StudySourceState.processing,
                StudySourceState.review,
                StudySourceState.transcriptionPending
              },
            }[state]
                ?.contains(next) ==
            true;
    if (state != next &&
        !recordingTransitions &&
        !(allowed[state]?.contains(next) ?? false)) {
      throw StateError('Invalid StudySource transition: $state -> $next');
    }

    final nextText = extractedText ?? text;
    if (next == StudySourceState.accepted && nextText.trim().isEmpty) {
      throw StateError('Accepted StudySource requires reviewed text.');
    }

    return StudySource(
      id: id,
      type: type,
      title: title,
      state: next,
      createdAtUtc: createdAtUtc,
      text: nextText,
      refs: sourceRefs ?? refs,
      errorCode: error,
      recordingSessionId: recordingSessionId,
      audioPaths: audioPaths,
      audioDurationMs: audioDurationMs,
    );
  }
}

final class StudyArtifact {
  const StudyArtifact({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.createdAtUtc,
    required this.sourceIds,
  });

  final String id;
  final StudyArtifactType type;
  final String title;
  final String content;
  final DateTime createdAtUtc;
  final List<String> sourceIds;
}

final class Study {
  const Study({
    required this.id,
    required this.title,
    required this.locale,
    required this.createdAtUtc,
    this.sources = const <StudySource>[],
    this.artifacts = const <StudyArtifact>[],
    this.activeSourceId,
    this.ownerUid,
  });

  final String id;
  final String title;
  final String locale;
  final DateTime createdAtUtc;
  final List<StudySource> sources;
  final List<StudyArtifact> artifacts;
  final String? activeSourceId;
  final String? ownerUid;

  List<StudySource> get operationalSources => sources
      .where((s) => !s.isAudio || s.id == activeSourceId)
      .toList(growable: false);
  List<StudySource> get historicalAudioSources => sources
      .where((s) => s.isAudio && s.id != activeSourceId)
      .toList(growable: false);

  Study activateAudio(String sourceId) {
    if (!sources.any((s) => s.id == sourceId && s.isAudio)) {
      throw StateError('unknown_audio_source');
    }
    return copyWith(activeSourceId: sourceId);
  }

  bool artifactMatchesSelection(StudyArtifact artifact) {
    final ids = acceptedSources.map((s) => s.id).toSet();
    return ids.isNotEmpty &&
        ids.length == artifact.sourceIds.toSet().length &&
        ids.containsAll(artifact.sourceIds);
  }

  List<StudyArtifact> get activeArtifacts =>
      artifacts.where(artifactMatchesSelection).toList(growable: false);

  List<StudySource> get acceptedSources => operationalSources
      .where((source) => source.isAccepted)
      .toList(growable: false);

  bool get canGenerate => acceptedSources.isNotEmpty;

  Study upsertRecording(
      {required String sessionId,
      required String title,
      required List<String> audioPaths,
      required int durationMs}) {
    final matches = sources.where((s) =>
        s.recordingSessionId == sessionId ||
        s.id == StudySource.recordingIdentity(sessionId));
    // Existing records are never destructively merged by this insertion path.
    if (matches.isNotEmpty) return activateAudio(matches.single.id);
    return copyWith(
        activeSourceId: StudySource.recordingIdentity(sessionId),
        sources: [
          ...sources,
          StudySource(
              id: StudySource.recordingIdentity(sessionId),
              type: StudySourceType.recordedAudio,
              title: title,
              state: StudySourceState.transcriptionPending,
              createdAtUtc: DateTime.now().toUtc(),
              recordingSessionId: sessionId,
              audioPaths: List.unmodifiable(audioPaths),
              audioDurationMs: durationMs)
        ]);
  }

  Study copyWith({
    String? title,
    List<StudySource>? sources,
    List<StudyArtifact>? artifacts,
    String? activeSourceId,
    String? ownerUid,
    bool clearActiveSource = false,
  }) {
    return Study(
      id: id,
      title: title ?? this.title,
      locale: locale,
      createdAtUtc: createdAtUtc,
      sources: sources ?? this.sources,
      artifacts: artifacts ?? this.artifacts,
      activeSourceId:
          clearActiveSource ? null : activeSourceId ?? this.activeSourceId,
      ownerUid: ownerUid ?? this.ownerUid,
    );
  }

  String buildContext({required bool isEs, int maxCharacters = 120000}) {
    if (acceptedSources.isEmpty) {
      throw StateError('Study has no accepted sources.');
    }

    final buffer = StringBuffer();
    for (final source in acceptedSources) {
      buffer.writeln(
        '===== ${source.id} | ${source.title} | ${source.type.name} =====',
      );
      if (source.refs.isNotEmpty) {
        buffer.writeln(
          'PROVENANCE: '
          '${source.refs.map((ref) => ref.label(isEs: isEs)).join(' | ')}',
        );
      }
      buffer.writeln(source.text.trim());
      buffer.writeln();
    }

    final value = buffer.toString();
    if (value.length > maxCharacters) {
      throw StateError('study_context_requires_hierarchical_generation');
    }
    return value;
  }
}
