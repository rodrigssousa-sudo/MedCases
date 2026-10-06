/// Presentation-only pruning after granular safety; never prunes body text.
class ClinicalSections {
  static String withoutEmptyHeadings(String text) {
    final lines = text.split('\n');
    final heading = RegExp(r'^\s*(#{1,6})\s+');
    final kept = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final match = heading.firstMatch(lines[i]);
      if (match == null) {
        kept.add(lines[i]);
        continue;
      }
      final level = match[1]!.length;
      var hasBody = false;
      for (var j = i + 1; j < lines.length; j++) {
        final next = heading.firstMatch(lines[j]);
        if (next != null && next[1]!.length <= level) break;
        if (next == null &&
            lines[j].trim().isNotEmpty &&
            !RegExp(r'^[-*_]{3,}$').hasMatch(lines[j].trim())) hasBody = true;
      }
      if (hasBody) kept.add(lines[i]);
    }
    return kept.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}
