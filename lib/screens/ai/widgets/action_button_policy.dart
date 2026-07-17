/// Resultado efetivo da ação pedagógica exibida no Modo Estudo.
class StudyActionDecision {
  final bool hasStudyNext;
  final bool isRepeatedPathophysiology;
  final String prompt;
  final String label;

  const StudyActionDecision({
    required this.hasStudyNext,
    required this.isRepeatedPathophysiology,
    required this.prompt,
    required this.label,
  });
}

/// Políticas puras usadas pelos botões abaixo das respostas da IA.
class ActionButtonPolicy {
  ActionButtonPolicy._();

  static final RegExp _pathophysiologyPattern = RegExp(
    r'fisiopatol',
    caseSensitive: false,
  );

  static final RegExp _leadingVisualSymbolPattern = RegExp(
    r'^[^a-zA-Z0-9À-ÿ]+',
  );

  static const String _advancedMechanismsPrompt =
      'Expanda a discussão anterior trazendo os mecanismos celulares '
      'avançados e alterações moleculares que não foram mencionadas na '
      'resposta de cima. Proibido repetir conceitos já apresentados.';

  static StudyActionDecision resolveStudyAction({
    required bool isPlantaoMode,
    required String studyNextPrompt,
    required String studyNextLabel,
    required String lastSentStudyPrompt,
    required String languageCode,
  }) {
    final hasStudyNext = !isPlantaoMode &&
        studyNextPrompt.isNotEmpty &&
        studyNextLabel.isNotEmpty;

    if (!hasStudyNext) {
      return const StudyActionDecision(
        hasStudyNext: false,
        isRepeatedPathophysiology: false,
        prompt: '',
        label: '',
      );
    }

    final isRepeatedPathophysiology = lastSentStudyPrompt.isNotEmpty &&
        _pathophysiologyPattern.hasMatch(studyNextPrompt) &&
        _pathophysiologyPattern.hasMatch(lastSentStudyPrompt);

    if (!isRepeatedPathophysiology) {
      return StudyActionDecision(
        hasStudyNext: true,
        isRepeatedPathophysiology: false,
        prompt: studyNextPrompt,
        label: studyNextLabel,
      );
    }

    return StudyActionDecision(
      hasStudyNext: true,
      isRepeatedPathophysiology: true,
      prompt: _advancedMechanismsPrompt,
      label: languageCode == 'es'
          ? 'Mecanismos Moleculares Avanzados >'
          : 'Mecanismos Moleculares Avançados >',
    );
  }

  static String sanitizeToolLabel(String label) {
    return label.replaceFirst(_leadingVisualSymbolPattern, '').trim();
  }
}
