/// Presentation-only topic label; never generates a diagnosis or edits content.
class AiResponseTitle {
  static String fromQuery(String query) {
    final text = query.trim().split('\n').first
        .replaceAll(RegExp(r'^[#*\s]+|[*#]+$'), '').trim();
    if (text.isEmpty || RegExp(
      r'^(?:e |y |¿?y |e se |e quais |qual seria |cu[aá]l ser[ií]a )',
      caseSensitive: false).hasMatch(text)) return '';
    if (text.length > 160) return '';
    if (text == text.toUpperCase() && text.length > 6) {
      return text[0] + text.substring(1).toLowerCase();
    }
    return text;
  }
}
