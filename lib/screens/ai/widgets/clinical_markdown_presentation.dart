/// Transformação exclusivamente visual do Markdown clínico.
///
/// Não altera o conteúdo original utilizado por persistência, cópia,
/// histórico ou leitura em voz alta.
abstract final class ClinicalMarkdownPresentation {
  static const String firstLineIndent = '\u2003';

  static const String _clinicalHeadingSource =
      r'diagnóstico\s+diferencial|diagnostico\s+diferencial|'
      r'diagnóstico|diagnostico|'
      r'definição|definicao|definición|definicion|'
      r'fisiopatologia|fisiopatología|'
      r'classificação|classificacao|clasificación|clasificacion|'
      r'etiologia|etiología|'
      r'epidemiologia|epidemiología|'
      r'clínica|clinica|'
      r'manifestações\s+clínicas|manifestacoes\s+clinicas|'
      r'manifestaciones\s+clínicas|manifestaciones\s+clinicas|'
      r'quadro\s+clínico|quadro\s+clinico|'
      r'cuadro\s+clínico|cuadro\s+clinico|'
      r'critérios\s+diagnósticos|criterios\s+diagnosticos|'
      r'criterios\s+diagnósticos|'
      r'diagnóstico\s+laboratorial|diagnostico\s+laboratorial|'
      r'diagnóstico\s+por\s+imagem|diagnostico\s+por\s+imagem|'
      r'estudos\s+complementares|estudios\s+complementarios|'
      r'classificação\s+de\s+gravidade|'
      r'classificacao\s+de\s+gravidade|'
      r'clasificación\s+de\s+gravedad|'
      r'tratamento|tratamiento|'
      r'conduta|conducta|manejo|'
      r'complicações|complicacoes|complicaciones|'
      r'prognóstico|prognostico|pronóstico|pronostico|'
      r'prevenção|prevencao|prevención|prevencion|'
      r'alertas|red\s+flags|'
      r'referências|referencias';

  static final RegExp _isolatedHeadingPattern = RegExp(
    r'^(\s*(?:(?:#{1,3})\s+)?'
    r'(?:(?:\d+|[ivxlcdm]+|[a-z])[.)]\s+)?)'
    '($_clinicalHeadingSource)'
    r'\s*:?\s*$',
    caseSensitive: false,
  );

  static final RegExp _inlineHeadingPattern = RegExp(
    r'^(\s*(?:(?:#{1,3})\s+)?'
    r'(?:(?:\d+|[ivxlcdm]+|[a-z])[.)]\s+)?)'
    '($_clinicalHeadingSource)'
    r'\s*:\s+(.+)$',
    caseSensitive: false,
  );

  static final RegExp _alreadyBoldHeadingPattern = RegExp(
    r'^\s*(?:(?:\d+|[ivxlcdm]+|[a-z])[.)]\s+)?'
    r'\*\*[^*]+:?\*\*',
    caseSensitive: false,
  );

  static final RegExp _markdownStructurePattern = RegExp(
    r'^(?:'
    r'#{1,6}\s|'
    r'[-*+]\s|'
    r'>\s?|'
    r'```|~~~|'
    r'\||'
    r'(?:\d+|[ivxlcdm]+|[a-z])[.)]\s+'
    r')',
    caseSensitive: false,
  );

  static final RegExp _clinicalCardPattern = RegExp(
    r'^(?:'
    r'🟥|⛔|📌|📚|🚨|💊|🧠|💉|⚠️|⚠|'
    r'✅|❌|🔴|🟡|🟢|🔵|🩺|🧪|🫀|🫁'
    r')',
  );

  static String format(
    String input, {
    bool indentParagraphs = true,
  }) {
    if (input.isEmpty) return input;

    final lines =
        input.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

    final output = <String>[];
    var atParagraphStart = true;
    var insideFence = false;

    for (final originalLine in lines) {
      final trimmed = originalLine.trim();

      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        insideFence = !insideFence;
        output.add(originalLine);
        atParagraphStart = false;
        continue;
      }

      if (insideFence) {
        output.add(originalLine);
        continue;
      }

      if (trimmed.isEmpty) {
        output.add(originalLine);
        atParagraphStart = true;
        continue;
      }

      final formattedHeading = _formatHeading(originalLine);

      if (formattedHeading != originalLine) {
        output.add(formattedHeading);
        atParagraphStart = false;
        continue;
      }

      if (indentParagraphs &&
          atParagraphStart &&
          _shouldIndent(originalLine)) {
        output.add('$firstLineIndent$originalLine');
      } else {
        output.add(originalLine);
      }

      atParagraphStart = false;
    }

    return output.join('\n');
  }

  static String _formatHeading(String line) {
    if (_alreadyBoldHeadingPattern.hasMatch(line)) {
      return line;
    }

    final inlineMatch = _inlineHeadingPattern.firstMatch(line);

    if (inlineMatch != null) {
      final prefix = inlineMatch.group(1) ?? '';
      final heading = inlineMatch.group(2)?.trim() ?? '';
      final content = inlineMatch.group(3)?.trim() ?? '';

      return '$prefix**$heading:** $content';
    }

    final isolatedMatch = _isolatedHeadingPattern.firstMatch(line);

    if (isolatedMatch != null) {
      final prefix = isolatedMatch.group(1) ?? '';
      final heading = isolatedMatch.group(2)?.trim() ?? '';

      return '$prefix**$heading**';
    }

    return line;
  }

  static bool _shouldIndent(String line) {
    // O EM SPACE deve ser detectado antes de trimLeft(), porque Dart o
    // reconhece como whitespace e o removeria da cópia normalizada.
    if (line.startsWith(firstLineIndent) || line.startsWith('&emsp;')) {
      return false;
    }

    final trimmed = line.trimLeft();

    if (trimmed.isEmpty) return false;

    if (_isolatedHeadingPattern.hasMatch(line) ||
        _inlineHeadingPattern.hasMatch(line) ||
        _alreadyBoldHeadingPattern.hasMatch(line)) {
      return false;
    }

    if (_markdownStructurePattern.hasMatch(trimmed)) {
      return false;
    }

    if (_clinicalCardPattern.hasMatch(trimmed)) {
      return false;
    }

    if (trimmed == '---' || trimmed == '***') {
      return false;
    }

    return true;
  }
}
