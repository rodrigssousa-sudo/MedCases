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

  // AI-RECONSTRUCTION-R18.6AA-R1C-R1:
  // Remove somente uma linha final composta exclusivamente por 📌.
  // Linhas clínicas como "📌 Monitorar: creatinina" permanecem intactas.
  static final RegExp _orphanStudyPinPattern = RegExp(
    r'(?:^|[\r\n])[ \t]*📌[ \t]*$',
  );

  static String _removeOrphanStudyPin(String text) {
    final normalized = text.trimRight();

    return normalized.replaceFirst(_orphanStudyPinPattern, '').trimRight();
  }

  // STUDY-PREMIUM-V1-B-R6: defesa final exclusiva do texto Study visível.
  // O parser permanece semanticamente estável; o resolver chama este método
  // apenas no caminho isStudyMode=true.
  static bool _isStudyEmojiRune(int rune) {
    return (rune >= 0x1F000 && rune <= 0x1FAFF) ||
        (rune >= 0x2600 && rune <= 0x27BF) ||
        rune == 0xFE0F ||
        rune == 0x200D ||
        rune == 0x20E3;
  }

  static String sanitizeStudyVisibleText(String text) {
    final withoutEmoji = String.fromCharCodes(
      text.runes.where((rune) => !_isStudyEmojiRune(rune)),
    );
    return withoutEmoji
        .replaceAll(RegExp(r'[ \t]+$', multiLine: true), '')
        .trimRight();
  }

  static const List<String> _legacyStudyContinuationMarkers = [
    'me gustaría',
    'me gustaria',
    'quieres saber',
    '¿quieres',
    'deseas saber',
    'podemos continuar',
    'para continuar',
    'profundizar',
    'saber más',
    'saber mas',
    'siguiente tema',
    'siguiente pregunta',
    'gostaria de',
    'quer saber',
    'você quer',
    'voce quer',
    'deseja saber',
    'podemos continuar',
    'para continuar',
    'aprofundar',
    'saber mais',
    'próximo tema',
    'proximo tema',
    'próxima pergunta',
    'proxima pergunta',
  ];

  // R18.6AC-R1B-H3B:
  // Convites conversacionais que o modelo antigo inseria como último
  // parágrafo antes do botão pedagógico canônico.
  static final RegExp _legacyStudyInvitationPattern = RegExp(
    r'^(?:'
    r'estoy\s+list[oa]\s+para|'
    r'estamos\s+list[oa]s?\s+para|'
    r'estou\s+pront[oa]\s+para|'
    r'estamos\s+pront[oa]s?\s+para|'
    r'si\s+(?:deseas|quieres)|'
    r'se\s+(?:desejar|quiser)|'
    r'puedo\s+(?:explicar|detallar|discutir|continuar|ayudar)|'
    r'posso\s+(?:explicar|detalhar|discutir|continuar|ajudar)|'
    r'podemos\s+(?:continuar|discutir|revisar|abordar|profundizar)|'
    r'vamos\s+a\s+(?:continuar|discutir|revisar|abordar)|'
    r'vamos\s+(?:continuar|discutir|revisar|abordar)'
    r')\b',
    caseSensitive: false,
  );

  // Sinais inequívocos de conteúdo clínico operacional.
  // Mesmo iniciados por 📌, esses parágrafos nunca podem ser removidos.
  static final RegExp _legacyStudyClinicalSignalPattern = RegExp(
    r'\b(?:'
    r'monitorar|monitorizar|monitorização|monitorizacion|monitoreo|'
    r'alerta|atenção|atencion|'
    r'risco|riesgo|'
    r'contraindicação|contraindicacao|contraindicación|contraindicacion|'
    r'dose|dosis|posologia|dosificación|dosificacion|'
    r'administrar|administración|administracao|'
    r'urgência|urgencia|emergência|emergencia|'
    r'mg|mcg|µg|ml|mmhg|spo2|ecg|'
    r'creatinina|potássio|potasio|diurese|diuresis'
    r')\b',
    caseSensitive: false,
  );

  /// Remove somente um parágrafo final de continuação pedagógica legado.
  ///
  /// Conteúdo clínico como "📌 Monitorar: creatinina" permanece intacto.
  static String _removeLegacyStudyContinuation(String text) {
    final normalized = _removeOrphanStudyPin(text);

    if (normalized.isEmpty) {
      return normalized;
    }

    int paragraphStart = -1;

    for (final match in RegExp(r'\n[ \t]*\n').allMatches(normalized)) {
      paragraphStart = match.end;
    }

    String trailing = paragraphStart >= 0
        ? normalized.substring(paragraphStart).trim()
        : normalized.trim();

    if (!trailing.startsWith('📌')) {
      final lineBreak = normalized.lastIndexOf('\n');

      if (lineBreak >= 0) {
        final lastLine = normalized.substring(lineBreak + 1).trim();

        if (lastLine.startsWith('📌')) {
          paragraphStart = lineBreak + 1;
          trailing = lastLine;
        }
      }
    }

    if (!trailing.startsWith('📌')) {
      return normalized;
    }

    final body = trailing.substring('📌'.length).trim().toLowerCase();

    final hasClinicalSignal = _legacyStudyClinicalSignalPattern.hasMatch(body);

    if (hasClinicalSignal) {
      return normalized;
    }

    final looksLikeContinuation = body.isEmpty ||
        body.endsWith('?') ||
        _legacyStudyInvitationPattern.hasMatch(body) ||
        _legacyStudyContinuationMarkers.any(body.contains);

    if (!looksLikeContinuation) {
      return normalized;
    }

    final start = paragraphStart < 0 ? 0 : paragraphStart;

    return normalized.substring(0, start).trimRight();
  }

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
        displayText: _removeLegacyStudyContinuation(text),
      );
    }

    final displayText = _removeLegacyStudyContinuation(
      text
          .replaceAll(_nextActionLabelPattern, '')
          .replaceAll(_nextActionPromptPattern, ''),
    );

    return StudyActionMetadata(
      label: label,
      prompt: prompt,
      displayText: displayText,
    );
  }
}
