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

  static StudyVisualSummaryData decodeVisualSummary(String raw) {
    final cleaned = _stripFence(raw).trim();

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) {
        final sections = <StudyVisualSummarySection>[];
        final rawSections = decoded['sections'];

        if (rawSections is List) {
          for (final item in rawSections) {
            if (item is! Map) continue;
            final title = '${item['title'] ?? ''}'.trim();
            final body = '${item['body'] ?? ''}'.trim();
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
            final value = '$item'.trim();
            if (value.isNotEmpty) keyPoints.add(value);
          }
        }

        return StudyVisualSummaryData(
          title: '${decoded['title'] ?? ''}'.trim(),
          overview: '${decoded['overview'] ?? ''}'.trim(),
          sections: List<StudyVisualSummarySection>.unmodifiable(
            sections.take(8),
          ),
          keyPoints: List<String>.unmodifiable(keyPoints.take(10)),
          takeaway: '${decoded['takeaway'] ?? ''}'.trim(),
        );
      }
    } catch (_) {
      // Fall back to readable text for malformed or legacy content.
    }

    final plain = stripMarkdown(cleaned);
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
          title: 'Ponto ${sections.length + 1}',
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
