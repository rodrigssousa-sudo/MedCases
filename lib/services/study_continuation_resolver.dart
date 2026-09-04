import '../screens/ai/widgets/message_render_policy.dart';
import 'ai_next_action_engine.dart';

enum StudyContinuationSource {
  none,
  remoteTag,
  localEngine,
  genericFallback,
}

class StudyContinuationResolution {
  final String displayText;

  /// Rótulo humano curto exibido no botão.
  final String label;

  /// Prompt produtivo oculto enviado à IA.
  final String question;

  final StudyContinuationSource source;

  const StudyContinuationResolution({
    required this.displayText,
    required this.label,
    required this.question,
    required this.source,
  });

  bool get hasContinuation => label.isNotEmpty && question.isNotEmpty;
}

/// Proprietário único da continuação pedagógica do Modo Estudo.
///
/// Precedência preservada:
/// 1. NEXT_ACTION_PROMPT remoto + NEXT_ACTION_LABEL;
/// 2. NextActionEngine local (label + promptToSend);
/// 3. fallback genérico bilíngue.
///
/// STUDY-PREMIUM-V1-B-R6:
/// label = superfície visual curta; question = payload produtivo oculto.
class StudyContinuationResolver {
  StudyContinuationResolver._();

  static StudyContinuationResolution resolve({
    required String rawText,
    required bool isStudyMode,
    required bool isSafeCard,
    required bool isStreaming,
    required String lastUserMessage,
    required String languageCode,
    List<String> chatHistory = const [],
    String lastSentPrompt = '',
  }) {
    final metadata = MessageRenderPolicy.parseStudyAction(
      text: rawText,
      isStudyMode: isStudyMode,
    );

    final displayText = isStudyMode
        ? MessageRenderPolicy.sanitizeStudyVisibleText(metadata.displayText)
        : metadata.displayText;

    if (!isStudyMode ||
        isSafeCard ||
        isStreaming ||
        displayText.trim().isEmpty) {
      return StudyContinuationResolution(
        displayText: displayText,
        label: '',
        question: '',
        source: StudyContinuationSource.none,
      );
    }

    final remoteQuestion =
        _normalizeQuestion(metadata.prompt, languageCode);
    final remoteLabel = _normalizeLabel(metadata.label);
    final remoteDuplicatesUserQuestion = _isUsable(remoteQuestion) &&
        _isDuplicateOfUserQuestion(remoteQuestion, lastUserMessage);
    final remoteIsDirect =
        !_isMetaChoiceQuestion(remoteQuestion) &&
        _pairSemanticallyCoherent(remoteLabel, remoteQuestion);
    final remoteFocusAlreadyCovered =
        NextActionEngine.isStudyContinuationFocusCovered(
          label: remoteLabel,
          prompt: remoteQuestion,
          lastUserMessage: lastUserMessage,
          lastAiResponse: displayText,
          history: chatHistory,
          lastSentPrompt: lastSentPrompt,
        );

    if (_isUsable(remoteQuestion) &&
        !_sameQuestion(remoteQuestion, lastSentPrompt) &&
        !remoteDuplicatesUserQuestion &&
        remoteIsDirect &&
        !remoteFocusAlreadyCovered) {
      return StudyContinuationResolution(
        displayText: displayText,
        label: remoteLabel.isNotEmpty
            ? remoteLabel
            : _genericLabel(languageCode),
        question: remoteQuestion,
        source: StudyContinuationSource.remoteTag,
      );
    }

    // R5 — se o próprio NEXT_ACTION_PROMPT repete a pergunta original,
    // não permita que o NextActionEngine ressuscite a mesma intenção em wrapper.
    // Vai direto ao fallback pedagógico genérico bilíngue.
    //
    // Importante: prompt remoto repetido por lastSentPrompt NÃO entra aqui;
    // nesse caso o engine local ainda pode buscar uma progressão alternativa.
    if (remoteDuplicatesUserQuestion) {
      final genericQuestion = _genericQuestion(
        languageCode,
        lastUserMessage,
        lastSentPrompt,
        chatHistory,
      );

      return StudyContinuationResolution(
        displayText: displayText,
        label: genericQuestion.isEmpty ? '' : _genericLabel(languageCode),
        question: genericQuestion,
        source: genericQuestion.isEmpty
            ? StudyContinuationSource.none
            : StudyContinuationSource.genericFallback,
      );
    }

    final localAction = NextActionEngine.build(
      lastUserMessage: lastUserMessage,
      lastAiResponse: displayText,
      isPlantaoMode: false,
      currentLanguage: languageCode,
      chatHistory: chatHistory,
    );

    final localQuestion =
        _normalizeQuestion(localAction.promptToSend, languageCode);
    final localLabel = _normalizeLabel(localAction.label);
    final localIsDirect =
        !_isMetaChoiceQuestion(localQuestion) &&
        _pairSemanticallyCoherent(localLabel, localQuestion);
    final localFocusAlreadyCovered =
        NextActionEngine.isStudyContinuationFocusCovered(
          label: localLabel,
          prompt: localQuestion,
          lastUserMessage: lastUserMessage,
          lastAiResponse: displayText,
          history: chatHistory,
          lastSentPrompt: lastSentPrompt,
        );

    if (_isUsable(localQuestion) &&
        !_sameQuestion(localQuestion, lastSentPrompt) &&
        !_isDuplicateOfUserQuestion(localQuestion, lastUserMessage) &&
        localIsDirect &&
        !localFocusAlreadyCovered) {
      return StudyContinuationResolution(
        displayText: displayText,
        label: localLabel.isNotEmpty
            ? localLabel
            : _genericLabel(languageCode),
        question: localQuestion,
        source: StudyContinuationSource.localEngine,
      );
    }

    final genericQuestion = _genericQuestion(
      languageCode,
      lastUserMessage,
      lastSentPrompt,
      chatHistory,
    );

    return StudyContinuationResolution(
      displayText: displayText,
      label: genericQuestion.isEmpty ? '' : _genericLabel(languageCode),
      question: genericQuestion,
      source: genericQuestion.isEmpty
          ? StudyContinuationSource.none
          : StudyContinuationSource.genericFallback,
    );
  }

  // R10 — rejeita nova pergunta de consentimento/escolha como ação.
  static bool _isMetaChoiceQuestion(String value) {
    final folded = _foldSemanticText(value);
    const markers = <String>[
      'te gustaria que', 'deseas que', 'prefieres que', 'quieres que',
      'quiere que', 'si deseas', 'si prefieres', 'gostaria que eu',
      'voce gostaria que', 'deseja que eu', 'quer que eu', 'prefere que eu',
      'se deseja', 'se prefere', 'posso detalhar', 'puedo detallar',
    ];
    return markers.any(folded.contains);
  }

  // R10 — label visível + prompt oculto são um único contrato semântico.
  // Só rejeita quando AMBOS possuem família conhecida e são incompatíveis.
  static bool _pairSemanticallyCoherent(String label, String question) {
    final labelFamily = _semanticFamily(label);
    final questionFamily = _semanticFamily(question);
    if (labelFamily.isEmpty || questionFamily.isEmpty) return true;
    return labelFamily == questionFamily;
  }

  static String _semanticFamily(String value) {
    final folded = _foldSemanticText(value);
    bool hasAny(List<String> markers) => markers.any(folded.contains);
    if (hasAny(const ['fisiopat', 'fisiologia', 'pathophys'])) return 'pathophysiology';
    if (hasAny(const ['dose', 'doses', 'dosis', 'dosagem', 'posologia', 'dosificacion'])) return 'dose';
    if (hasAny(const ['diagnost', 'diagnosis', 'criterio diagnost', 'prueba diagnost'])) return 'diagnosis';
    if (hasAny(const ['tratamento', 'tratamiento', 'manejo', 'conduta', 'conducta', 'terapia'])) return 'treatment';
    if (hasAny(const ['complicacao', 'complicacoes', 'complicacion', 'complicaciones'])) return 'complications';
    if (hasAny(const ['prognostico', 'pronostico', 'prognosis'])) return 'prognosis';
    if (hasAny(const ['gravidade', 'gravedad', 'severidade', 'severidad', 'classificacao', 'clasificacion', 'estadiamento'])) return 'severity';
    return '';
  }

  static String _foldSemanticText(String value) {
    return value.trim().toLowerCase()
        .replaceAll('á','a').replaceAll('à','a').replaceAll('ã','a').replaceAll('â','a')
        .replaceAll('é','e').replaceAll('ê','e').replaceAll('í','i')
        .replaceAll('ó','o').replaceAll('ô','o').replaceAll('õ','o')
        .replaceAll('ú','u').replaceAll('ü','u').replaceAll('ç','c')
        .replaceAll('¿','').replaceAll('¡','').replaceAll(RegExp(r'\s+'),' ');
  }

  static String _normalizeLabel(String raw) {
    var result = _removeEmoji(raw).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (result.isEmpty) return '';

    result = result
        .replaceFirst(RegExp(r'^[\s\-–—:;,.!?¿¡<>]+'), '')
        .replaceFirst(RegExp(r'[\s\-–—:;,.!?¿¡<>]+$'), '')
        .trim();

    final upper = result.toUpperCase();
    if (result.isEmpty ||
        upper.contains('NEXT_ACTION_') ||
        upper.contains('OUTPUT_STARTS_HERE')) {
      return '';
    }

    final words = result.split(RegExp(r'\s+'));
    return (words.length > 5 ? words.take(5).join(' ') : result).trim();
  }

  static String _removeEmoji(String value) {
    return String.fromCharCodes(
      value.runes.where(
        (rune) => !((rune >= 0x1F000 && rune <= 0x1FAFF) ||
            (rune >= 0x2600 && rune <= 0x27BF) ||
            rune == 0xFE0F ||
            rune == 0x200D ||
            rune == 0x20E3),
      ),
    );
  }

  static String _normalizeQuestion(String raw, String languageCode) {
    var result = _removeEmoji(raw)
        .replaceFirst(RegExp(r'^\s*(?:→)+\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (result.isEmpty) return '';

    if (!result.endsWith('?')) {
      result = result.replaceFirst(RegExp(r'[.!;:]+\s*$'), '').trim();
      result = '$result?';
    }

    final isEs = languageCode.trim().toLowerCase().startsWith('es');
    if (isEs && !result.startsWith('¿')) result = '¿$result';
    return result;
  }

  static bool _isUsable(String question) {
    if (question.trim().length < 12) return false;
    final normalized = question.toUpperCase();
    return !normalized.contains('NEXT_ACTION_') &&
        !normalized.contains('OUTPUT_STARTS_HERE');
  }

  static bool _sameQuestion(String first, String second) {
    if (first.trim().isEmpty || second.trim().isEmpty) return false;
    return _comparisonKey(first) == _comparisonKey(second);
  }

  static bool _isDuplicateOfUserQuestion(
      String candidate, String originalQuestion) {
    final candidateKey = _comparisonKey(candidate);
    final originalKey = _comparisonKey(originalQuestion);
    if (candidateKey.isEmpty || originalKey.isEmpty) return false;

    if (candidateKey == originalKey) return true;

    // R3 — contenção contextual:
    // mantém a proteção H2B1 contra wrappers longos gerados pelo motor local,
    // mas NÃO confunde "mesmo tema" com "mesma pergunta".
    //
    // Wrapper duplicado:
    //   "Explique fisiologia detalhada"
    //   "Pode explicar a fisiologia detalhada..."
    //
    // Progressão válida:
    //   "Explique pancreatite aguda"
    //   "Quais critérios definem gravidade na pancreatite aguda?"
    final candidateFocus = _studyFocusTokens(candidate);
    final originalFocus = _studyFocusTokens(originalQuestion);
    final introducesNewFocus =
        candidateFocus.difference(originalFocus).isNotEmpty;

    const minimumEmbeddedLength = 12;

    if (originalKey.length >= minimumEmbeddedLength &&
        candidateKey.contains(originalKey)) {
      return !introducesNewFocus;
    }

    if (candidateKey.length >= minimumEmbeddedLength &&
        originalKey.contains(candidateKey)) {
      return !introducesNewFocus;
    }

    return false;
  }

  static Set<String> _studyFocusTokens(String value) {
    final folded = value
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c');

    final result = <String>{};

    void addIf(String token, List<String> markers) {
      if (markers.any(folded.contains)) result.add(token);
    }

    addIf('fisiologia', [
      'fisiologia',
      'fisiopatologia',
      'fisiopatologica',
      'fisiopatologico',
    ]);
    addIf('criterios', ['criterio', 'criterios']);
    addIf('gravidade', ['gravidade', 'gravedad', 'severidade', 'severidad']);
    addIf('classificacao', [
      'classificacao',
      'clasificacion',
      'estadiamento',
      'estadificacion',
    ]);
    addIf('diagnostico', ['diagnostico', 'diagnosis']);
    addIf('diferenciais', [
      'diferencial',
      'diferenciais',
      'diferenciales',
    ]);
    addIf('tratamento', [
      'tratamento',
      'tratamiento',
      'manejo',
      'conduta',
      'conducta',
      'terapia',
    ]);
    addIf('dose', ['dose', 'doses', 'dosis', 'posologia', 'dosificacion']);
    addIf('investigacao', [
      'investigacao',
      'investigacion',
      'exame',
      'exames',
      'laboratorio',
      'imagem',
      'imagen',
    ]);
    addIf('complicacoes', [
      'complicacao',
      'complicacoes',
      'complicacion',
      'complicaciones',
    ]);
    addIf('prognostico', ['prognostico', 'pronostico']);
    addIf('monitorizacao', [
      'monitorizacao',
      'monitoramento',
      'monitorizacion',
      'monitoreo',
    ]);
    addIf('mecanismo', ['mecanismo']);
    addIf('indicacoes',
        ['indicacao', 'indicacoes', 'indicacion', 'indicaciones']);
    addIf('contraindicacoes', [
      'contraindicacao',
      'contraindicacoes',
      'contraindicacion',
      'contraindicaciones',
    ]);
    addIf('efeitos_adversos', [
      'efeito adverso',
      'efeitos adversos',
      'efecto adverso',
      'efectos adversos',
    ]);

    return result;
  }

  static String _comparisonKey(String value) {
    var normalized = value.trim().toLowerCase();
    normalized = normalized.replaceFirst(
      RegExp(r'^[^a-z0-9à-ÿ]+', caseSensitive: false),
      '',
    );
    normalized = normalized.replaceFirst(
      RegExp(
        r'^(?:'
        r'pode\s+me\s+explicar|'
        r'poderia\s+me\s+explicar|'
        r'me\s+explique|'
        r'explique|'
        r'fale\s+sobre|'
        r'detalhe|'
        r'descreva|'
        r'puede\s+explicarme|'
        r'podría\s+explicarme|'
        r'explícame|'
        r'explica|'
        r'háblame\s+de|'
        r'habla\s+sobre|'
        r'detalla|'
        r'describe'
        r')\s+(?:(?:a|o|as|os|la|el|las|los)\s+)?',
        caseSensitive: false,
      ),
      '',
    );
    return normalized.replaceAll(RegExp(r'[^a-z0-9à-ÿ]+'), '');
  }

  static String _genericLabel(String languageCode) {
    final isEs = languageCode.trim().toLowerCase().startsWith('es');
    return isEs ? 'Siguiente punto' : 'Próximo ponto';
  }

  static String _genericQuestion(
    String languageCode,
    String lastUserMessage,
    String lastSentPrompt,
    List<String> chatHistory,
  ) {
    final isEs = languageCode.trim().toLowerCase().startsWith('es');
    final candidates = isEs
        ? const [
            '¿Cuál es el siguiente punto clave para profundizar este tema?',
            '¿Cómo aplicaría este conocimiento a un caso clínico típico?',
            '¿Qué diagnóstico diferencial importante debería comparar ahora?',
            '¿Qué errores importantes debo evitar al estudiar este tema?',
          ]
        : const [
            'Qual é o próximo ponto-chave para aprofundar este tema?',
            'Como aplicar este conhecimento a um caso clínico típico?',
            'Qual diagnóstico diferencial importante devo comparar agora?',
            'Quais erros importantes devo evitar ao estudar este tema?',
          ];

    for (final candidate in candidates) {
      final repeatedInHistory = chatHistory.any(
        (item) => _sameQuestion(candidate, item),
      );
      if (!_isDuplicateOfUserQuestion(candidate, lastUserMessage) &&
          !_sameQuestion(candidate, lastSentPrompt) &&
          !repeatedInHistory) {
        return candidate;
      }
    }

    // Fail-closed: não cria loop repetindo uma alternativa já consumida.
    return '';
  }
}
