/// Compara o texto clínico validado pelo backend com o texto já higienizado
/// para apresentação.
///
/// São ignoradas apenas diferenças visuais: marcadores Markdown, caixa,
/// espaços, quebras de linha e caracteres invisíveis. Conteúdo, números,
/// unidades, fármacos, vias, pontuação e ordem permanecem na identidade.
abstract final class StructuredOutputTextEquivalence {
  static bool matches({
    required String backendText,
    required String uiText,
  }) {
    final backendIdentity = canonicalIdentity(backendText);
    final uiIdentity = canonicalIdentity(uiText);

    if (backendIdentity.isEmpty || uiIdentity.isEmpty) {
      return false;
    }

    return backendIdentity == uiIdentity;
  }

  static String canonicalIdentity(String value) {
    return value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\u200B', '')
        .replaceAll('\u200C', '')
        .replaceAll('\u200D', '')
        .replaceAll('\uFEFF', '')
        .replaceAll(RegExp(r'[*_`]'), '')
        .toLowerCase()
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
