import 'dart:convert';

final class StudyVisualSummarySection {
  const StudyVisualSummarySection({required this.title, required this.body});

  final String title;
  final String body;
}

final class StudyVisualSummaryData {
  const StudyVisualSummaryData({
    required this.title,
    required this.overview,
    required this.sections,
    required this.keyPoints,
    required this.takeaway,
  });

  final String title;
  final String overview;
  final List<StudyVisualSummarySection> sections;
  final List<String> keyPoints;
  final String takeaway;
}

final class StudyMindMapNode {
  const StudyMindMapNode({required this.text, required this.depth});

  final String text;
  final int depth;
}

final class StudyVisualResultCodec {
  const StudyVisualResultCodec._();

  static StudyVisualSummaryData decodeVisualSummary(String raw,
      {bool isEs = false}) {
    final cleaned = _stripFence(raw).trim();

    try {
      final decoded = _decodeEnvelope(raw);
      if (decoded is Map<String, dynamic>) {
        final sections = <StudyVisualSummarySection>[];
        final rawSections = decoded['sections'];

        if (rawSections is List) {
          for (final item in rawSections) {
            if (item is! Map) continue;
            final title = _text(item['title']);
            final body = _text(item['body']);
            if (title.isEmpty && body.isEmpty) continue;

            sections.add(
              StudyVisualSummarySection(
                title: title.isEmpty ? '—' : title,
                body: body,
              ),
            );
          }
        }

        final keyPoints = <String>[];
        final rawPoints = decoded['keyPoints'];
        if (rawPoints is List) {
          for (final item in rawPoints) {
            final value = _text(item);
            if (value.isNotEmpty) keyPoints.add(value);
          }
        }

        return StudyVisualSummaryData(
          title: _text(decoded['title']),
          overview: _text(decoded['overview']),
          sections: List<StudyVisualSummarySection>.unmodifiable(
            sections,
          ),
          keyPoints: List<String>.unmodifiable(keyPoints),
          takeaway: _text(decoded['takeaway']),
        );
      }
    } catch (_) {
      // Structured failures must never become raw JSON in UI or exports.
    }

    final plain = _looksStructured(cleaned)
        ? (isEs
            ? 'No se pudo interpretar el resumen visual. Intenta generar este formato de nuevo.'
            : 'Não foi possível interpretar o resumo visual. Tente gerar este formato novamente.')
        : stripMarkdown(cleaned);
    final paragraphs = plain
        .split(RegExp(r'\n\s*\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    final overview = paragraphs.isEmpty ? plain : paragraphs.first;
    final sections = <StudyVisualSummarySection>[];

    for (var i = 1; i < paragraphs.length && sections.length < 6; i++) {
      sections.add(
        StudyVisualSummarySection(
          title: '${isEs ? "Punto" : "Ponto"} ${sections.length + 1}',
          body: paragraphs[i],
        ),
      );
    }

    return StudyVisualSummaryData(
      title: '',
      overview: overview,
      sections: List<StudyVisualSummarySection>.unmodifiable(sections),
      keyPoints: const <String>[],
      takeaway: '',
    );
  }

  /// Apply the existing clinical validator to text fields, never to JSON syntax.
  static String validateStructuredText(
      String raw, String Function(String) validate) {
    final decoded = _decodeEnvelope(raw);
    if (decoded is! Map<String, dynamic> || !isCompleteStructuredSummary(raw)) {
      throw const FormatException('invalid_visual_payload');
    }
    Object? visit(Object? value) {
      if (value is String) return validate(value);
      if (value is List) return value.map(visit).toList();
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), visit(value)));
      }
      return value;
    }
    final result = jsonEncode(visit(decoded));
    if (!isCompleteStructuredSummary(result)) {
      throw const FormatException('invalid_visual_payload');
    }
    return result;
  }

  static bool isCompleteStructuredSummary(String raw) {
    try {
      final value = _decodeEnvelope(raw);
      if (value is! Map<String, dynamic> || _text(value['title']).isEmpty) {
        return false;
      }
      // Only title and substantive content are essential. Optional layout
      // blocks never authorize discarding an otherwise valid summary.
      final overview = _text(value['overview']);
      final sections = value['sections'];
      final validSection = sections is List &&
          sections.any((item) => item is Map && _text(item['body']).isNotEmpty);
      return overview.isNotEmpty || validSection;
    } catch (_) {
      return false;
    }
  }

  static String _text(Object? value) {
    if (value is! String || _looksStructured(value)) return '';
    return value.trim();
  }

  static bool _looksStructured(String value) => RegExp(
          r'[{}]|^\s*[\["]|```(?:json)?|"(?:title|overview|sections|body)"\s*:')
      .hasMatch(value);

  // Providers and stored legacy records may wrap JSON in a string or a fence.
  // Bounded unwrapping does not repair or invent incomplete clinical content.
  static Object? _decodeEnvelope(String raw) {
    Object? value = raw;
    for (var i = 0; i < 3 && value is String; i++) {
      var candidate = value.trim();
      final fenced =
          RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false)
              .firstMatch(candidate);
      if (fenced != null) {
        if (!_safeWrapper(candidate.substring(0, fenced.start)) ||
            !_safeWrapper(candidate.substring(fenced.end))) {
          throw const FormatException('unsafe_visual_envelope');
        }
        candidate = fenced.group(1)!.trim();
      } else {
        candidate = _stripFence(candidate);
        if (!candidate.startsWith('"')) {
          final start = candidate.indexOf('{');
          final end = candidate.lastIndexOf('}');
          if (start < 0 ||
              end < start ||
              !_safeWrapper(candidate.substring(0, start)) ||
              !_safeWrapper(candidate.substring(end + 1))) {
            throw const FormatException('invalid_visual_envelope');
          }
          candidate = candidate.substring(start, end + 1);
        }
      }
      // jsonDecode rejects malformed/truncated objects and extra objects.
      // Never repair braces, sentences or numeric values.
      value = jsonDecode(candidate);
    }
    return value;
  }

  static bool _safeWrapper(String value) {
    final text = value.trim();
    return text.isEmpty ||
        RegExp(
          r'^(?:(?:resultado|json|resumo visual|resumen visual|output)\s*:?|fim do json\.?|fin del json\.?)$',
          caseSensitive: false,
        ).hasMatch(text);
  }

  static List<StudyMindMapNode> decodeMindMap(String raw) {
    final nodes = <StudyMindMapNode>[];

    for (final rawLine in raw.split('\n')) {
      var line = rawLine.trimRight();
      if (line.trim().isEmpty) continue;

      final leftTrimmed = line.trimLeft();
      final leadingSpaces = line.length - leftTrimmed.length;
      line = leftTrimmed;
      var depth = 0;

      final heading = RegExp(r'^(#{1,6})\s+').firstMatch(line);
      if (heading != null) {
        depth = (heading.group(1)!.length - 1).clamp(0, 3);
        line = line.substring(heading.end);
      } else {
        final bullet = RegExp(r'^[-*+]\s+').firstMatch(line);
        if (bullet != null) {
          depth = 1 + (leadingSpaces ~/ 2);
          line = line.substring(bullet.end);
        } else {
          final numbered = RegExp(r'^\d+[.)]\s+').firstMatch(line);
          if (numbered != null) {
            depth = 1 + (leadingSpaces ~/ 2);
            line = line.substring(numbered.end);
          }
        }
      }

      line = stripMarkdown(line).trim();
      if (line.isEmpty) continue;

      nodes.add(StudyMindMapNode(text: line, depth: depth.clamp(0, 3)));
    }

    if (nodes.isEmpty) {
      final plain = stripMarkdown(raw).trim();
      if (plain.isNotEmpty) {
        nodes.add(StudyMindMapNode(text: plain, depth: 0));
      }
    }

    return List<StudyMindMapNode>.unmodifiable(nodes.take(80));
  }

  static String stripMarkdown(String value) {
    return value
        .replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*\d+[.)]\s+', multiLine: true), '')
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAll('`', '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String _stripFence(String value) {
    return value
        .trim()
        .replaceFirst(
          RegExp(r'^```(?:json|markdown|md|text)?\s*', caseSensitive: false),
          '',
        )
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();
  }
}
