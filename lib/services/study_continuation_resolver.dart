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
  final String question;
  final StudyContinuationSource source;

  const StudyContinuationResolution({
    required this.displayText,
    required this.question,
    required this.source,
  });

  bool get hasContinuation => question.isNotEmpty;
}

/// Proprietário único da continuação pedagógica do Modo Estudo.
///
/// Precedência:
/// 1. NEXT_ACTION_PROMPT válido;
/// 2. NextActionEngine local;
/// 3. pergunta genérica bilíngue.
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

    final displayText = metadata.displayText;

    if (!isStudyMode ||
        isSafeCard ||
        isStreaming ||
        displayText.trim().isEmpty) {
      return StudyContinuationResolution(
        displayText: displayText,
        question: '',
        source: StudyContinuationSource.none,
      );
    }

    final remoteQuestion = _normalizeQuestion(
      metadata.prompt,
      languageCode,
    );

    if (_isUsable(remoteQuestion) &&
        !_sameQuestion(remoteQuestion, lastSentPrompt) &&
        !_isDuplicateOfUserQuestion(
          remoteQuestion,
          lastUserMessage,
        )) {
      return StudyContinuationResolution(
        displayText: displayText,
        question: remoteQuestion,
        source: StudyContinuationSource.remoteTag,
      );
    }

    final localAction = NextActionEngine.build(
      lastUserMessage: lastUserMessage,
      lastAiResponse: displayText,
      isPlantaoMode: false,
      currentLanguage: languageCode,
      chatHistory: chatHistory,
    );

    final localQuestion = _normalizeQuestion(
      localAction.promptToSend,
      languageCode,
    );

    if (_isUsable(localQuestion) &&
        !_sameQuestion(localQuestion, lastSentPrompt) &&
        !_isDuplicateOfUserQuestion(
          localQuestion,
          lastUserMessage,
        )) {
      return StudyContinuationResolution(
        displayText: displayText,
        question: localQuestion,
        source: StudyContinuationSource.localEngine,
      );
    }

    return StudyContinuationResolution(
      displayText: displayText,
      question: _genericQuestion(
        languageCode,
        lastUserMessage,
        lastSentPrompt,
        chatHistory,
      ),
      source: StudyContinuationSource.genericFallback,
    );
  }

  static String _normalizeQuestion(
    String raw,
    String languageCode,
  ) {
    var result = raw
        .replaceFirst(
          RegExp(r'^\s*(?:📌|✨|➡️|→)+\s*'),
          '',
        )
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        )
        .trim();

    if (result.isEmpty) {
      return '';
    }

    if (!result.endsWith('?')) {
      result = result
          .replaceFirst(
            RegExp(r'[.!;:]+\s*$'),
            '',
          )
          .trim();

      result = '$result?';
    }

    final isEs = languageCode.trim().toLowerCase().startsWith('es');

    if (isEs && !result.startsWith('¿')) {
      result = '¿$result';
    }

    return result;
  }

  static bool _isUsable(String question) {
    if (question.trim().length < 12) {
      return false;
    }

    final normalized = question.toUpperCase();

    return !normalized.contains('NEXT_ACTION_') &&
        !normalized.contains('OUTPUT_STARTS_HERE');
  }

  static bool _sameQuestion(
    String first,
    String second,
  ) {
    if (first.trim().isEmpty || second.trim().isEmpty) {
      return false;
    }

    return _comparisonKey(first) == _comparisonKey(second);
  }

  static bool _isDuplicateOfUserQuestion(
    String candidate,
    String originalQuestion,
  ) {
    final candidateKey = _comparisonKey(candidate);
    final originalKey = _comparisonKey(originalQuestion);

    if (candidateKey.isEmpty || originalKey.isEmpty) {
      return false;
    }

    if (candidateKey == originalKey) {
      return true;
    }

    // Captura wrappers produzidos pelo motor local, por exemplo:
    // "Pode explicar a fisiopatologia de [pergunta original]..."
    // O limite evita rejeitar continuações que apenas citam um tema curto.
    const minimumEmbeddedLength = 12;

    if (originalKey.length >= minimumEmbeddedLength &&
        candidateKey.contains(originalKey)) {
      return true;
    }

    if (candidateKey.length >= minimumEmbeddedLength &&
        originalKey.contains(candidateKey)) {
      return true;
    }

    return false;
  }

  static String _comparisonKey(String value) {
    var normalized = value.trim().toLowerCase();

    // Remove ¿, ¡, emojis e pontuação antes do conteúdo textual.
    normalized = normalized.replaceFirst(
      RegExp(
        r'^[^a-z0-9à-ÿ]+',
        caseSensitive: false,
      ),
      '',
    );

    // Remove apenas expressões introdutórias PT/ES.
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

    return normalized.replaceAll(
      RegExp(r'[^a-z0-9à-ÿ]+'),
      '',
    );
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
            '¿Qué relación fisiopatológica debería estudiar a continuación?',
            '¿Qué diagnóstico diferencial importante debería comparar ahora?',
            '¿Qué errores importantes debo evitar al estudiar este tema?',
          ]
        : const [
            'Qual é o próximo ponto-chave para aprofundar este tema?',
            'Qual relação fisiopatológica devo estudar em seguida?',
            'Qual diagnóstico diferencial importante devo comparar agora?',
            'Quais erros importantes devo evitar ao estudar este tema?',
          ];

    for (final candidate in candidates) {
      final repeatedInHistory = chatHistory.any(
        (item) => _sameQuestion(candidate, item),
      );

      if (!_isDuplicateOfUserQuestion(
            candidate,
            lastUserMessage,
          ) &&
          !_sameQuestion(candidate, lastSentPrompt) &&
          !repeatedInHistory) {
        return candidate;
      }
    }

    return candidates.last;
  }
}
