/// Pure visual projection for user messages created by deterministic
/// Plantão action buttons.
///
/// The canonical message text remains unchanged in the model/history/provider.
/// Only the text rendered inside the user's bubble is compacted.
class UserMessageDisplayPolicy {
  UserMessageDisplayPolicy._();

  static const String _questionsEsPrefix =
      'Enumera solamente las preguntas clínicas clave que debo hacer al '
      'paciente para discriminar los diagnósticos diferenciales';

  static const String _questionsPtPrefix =
      'Liste somente as perguntas clínicas-chave que devo fazer ao paciente '
      'para discriminar os diagnósticos diferenciais';

  static const String _questionsEsSentinel =
      'No inventes respuestas del paciente.';

  static const String _questionsPtSentinel =
      'Não invente respostas do paciente.';

  static String visibleText(String rawText) {
    final text = rawText.trim();

    if (text.startsWith(_questionsEsPrefix) &&
        text.contains(_questionsEsSentinel)) {
      return 'Preguntas clave';
    }

    if (text.startsWith(_questionsPtPrefix) &&
        text.contains(_questionsPtSentinel)) {
      return 'Perguntas-chave';
    }

    return rawText;
  }
}
