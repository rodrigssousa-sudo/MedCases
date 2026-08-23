enum StudySourceType { recordedAudio, uploadedAudio, pdf, image, text }

enum StudySourceState { added, processing, review, accepted, failed }

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
  });

  final String id;
  final StudySourceType type;
  final String title;
  final StudySourceState state;
  final DateTime createdAtUtc;
  final String text;
  final List<SourceRef> refs;
  final String? errorCode;

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

    if (!(allowed[state]?.contains(next) ?? false)) {
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
  });

  final String id;
  final String title;
  final String locale;
  final DateTime createdAtUtc;
  final List<StudySource> sources;
  final List<StudyArtifact> artifacts;

  List<StudySource> get acceptedSources =>
      sources.where((source) => source.isAccepted).toList(growable: false);

  Study copyWith({
    String? title,
    List<StudySource>? sources,
    List<StudyArtifact>? artifacts,
  }) {
    return Study(
      id: id,
      title: title ?? this.title,
      locale: locale,
      createdAtUtc: createdAtUtc,
      sources: sources ?? this.sources,
      artifacts: artifacts ?? this.artifacts,
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

      if (buffer.length >= maxCharacters) break;
    }

    final value = buffer.toString();
    return value.length <= maxCharacters
        ? value
        : value.substring(0, maxCharacters);
  }
}
