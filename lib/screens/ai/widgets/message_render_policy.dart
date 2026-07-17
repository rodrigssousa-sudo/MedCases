import '../../../providers/app_provider.dart';

/// Metadados de progressão pedagógica extraídos da resposta da IA.
///
/// As tags permanecem ocultas para o usuário e são usadas apenas para montar
/// o botão contextual do Modo Estudo.
class StudyActionMetadata {
  final String label;
  final String prompt;
  final String displayText;

  const StudyActionMetadata({
    required this.label,
    required this.prompt,
    required this.displayText,
  });

  bool get hasAction => label.isNotEmpty || prompt.isNotEmpty;
}

/// Políticas puras utilizadas pelo renderizador de mensagens.
///
/// Não acessa BuildContext, não modifica estado e não executa engines.
/// Pode ser testada independentemente da árvore visual.
class MessageRenderPolicy {
  MessageRenderPolicy._();

  static final RegExp _nextActionLabelPattern = RegExp(
    r'\[NEXT_ACTION_LABEL:\s*(.*?)(?:\]|$)',
    dotAll: true,
  );

  static final RegExp _nextActionPromptPattern = RegExp(
    r'\[NEXT_ACTION_PROMPT:\s*(.*?)(?:\]|$)',
    dotAll: true,
  );

  /// Identifica respostas de contingência que não podem receber:
  /// StructuredClinicalOutput, botões, calculadoras ou evidências.
  static bool isSafeCard(String text) {
    if (text.startsWith(AppProvider.kSafeCardMarkerPt) ||
        text.startsWith(AppProvider.kSafeCardMarkerEs)) {
      return true;
    }

    final normalizedText = text.toLowerCase();

    return normalizedText.contains('não consegui completar a resposta') ||
        normalizedText.contains('não consegui concluir a resposta') ||
        normalizedText.contains('no pude completar la respuesta') ||
        normalizedText.contains('estamos ajustando a resposta') ||
        normalizedText.contains('estamos ajustando la respuesta');
  }

  /// Extrai e remove as tags internas usadas no Modo Estudo.
  ///
  /// No Modo Plantão, devolve o texto intacto e não expõe metadados.
  static StudyActionMetadata parseStudyAction({
    required String text,
    required bool isStudyMode,
  }) {
    if (!isStudyMode) {
      return StudyActionMetadata(
        label: '',
        prompt: '',
        displayText: text,
      );
    }

    final labelMatch = _nextActionLabelPattern.firstMatch(text);
    final promptMatch = _nextActionPromptPattern.firstMatch(text);

    final label = (labelMatch?.group(1) ?? '').trim();
    final prompt = (promptMatch?.group(1) ?? '').trim();

    if (label.isEmpty && prompt.isEmpty) {
      return StudyActionMetadata(
        label: '',
        prompt: '',
        displayText: text,
      );
    }

    final displayText = text
        .replaceAll(_nextActionLabelPattern, '')
        .replaceAll(_nextActionPromptPattern, '')
        .trimRight();

    return StudyActionMetadata(
      label: label,
      prompt: prompt,
      displayText: displayText,
    );
  }
}
