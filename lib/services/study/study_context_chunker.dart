import '../../models/study_workspace_model.dart';

final class StudyContextChunk {
  const StudyContextChunk({
    required this.index,
    required this.total,
    required this.value,
    required this.sourceId,
  });

  final int index;
  final int total;
  final String value;
  final String sourceId;
}

final class StudyContextChunker {
  const StudyContextChunker._();

  static const int defaultMaxCharacters = 42000;

  static List<StudyContextChunk> build({
    required Study study,
    required bool isEs,
    int maxCharacters = defaultMaxCharacters,
  }) {
    if (study.acceptedSources.isEmpty) {
      throw StateError('Study has no accepted sources.');
    }
    if (maxCharacters < 8000 || maxCharacters > 80000) {
      throw ArgumentError.value(maxCharacters, 'maxCharacters');
    }

    final raw = <({String sourceId, String value})>[];

    for (final source in study.acceptedSources) {
      final provenance = source.refs.isEmpty
          ? ''
          : 'PROVENANCE: '
              '${source.refs.map((ref) => ref.label(isEs: isEs)).join(' | ')}\n';

      final header =
          '===== ${source.id} | ${source.title} | ${source.type.name} =====\n'
          '$provenance';

      final payloadBudget = maxCharacters - header.length - 80;
      if (payloadBudget < 1000) {
        throw StateError('study_context_header_too_large');
      }

      final pieces = splitText(
        source.text.trim(),
        maxCharacters: payloadBudget,
      );

      for (var i = 0; i < pieces.length; i++) {
        raw.add(
          (
            sourceId: source.id,
            value:
                '${header}SOURCE_PART: ${i + 1}/${pieces.length}\n${pieces[i]}',
          ),
        );
      }
    }

    final total = raw.length;
    return List<StudyContextChunk>.generate(
      total,
      (i) => StudyContextChunk(
        index: i + 1,
        total: total,
        value: raw[i].value,
        sourceId: raw[i].sourceId,
      ),
      growable: false,
    );
  }

  static List<String> splitText(
    String input, {
    required int maxCharacters,
  }) {
    final text = input.trim();
    if (text.isEmpty) return const <String>[];
    if (text.length <= maxCharacters) return <String>[text];

    final out = <String>[];
    var start = 0;

    while (start < text.length) {
      var end = start + maxCharacters;
      if (end >= text.length) {
        out.add(text.substring(start).trim());
        break;
      }

      final minBreak = start + (maxCharacters * 0.65).floor();
      var cut = text.lastIndexOf('\n\n', end);
      if (cut < minBreak) cut = text.lastIndexOf('\n', end);
      if (cut < minBreak) cut = text.lastIndexOf(' ', end);
      if (cut < minBreak) cut = end;

      final piece = text.substring(start, cut).trim();
      if (piece.isNotEmpty) out.add(piece);

      start = cut;
      while (start < text.length &&
          (text.codeUnitAt(start) == 10 ||
              text.codeUnitAt(start) == 13 ||
              text.codeUnitAt(start) == 32 ||
              text.codeUnitAt(start) == 9)) {
        start++;
      }
    }

    if (out.isEmpty) throw StateError('study_context_chunking_failed');
    return List<String>.unmodifiable(out);
  }
}
