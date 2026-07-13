// ══════════════════════════════════════════════════════════════════════════════
// truncation_inspector.dart — Structural Heuristic Truncation Inspector
//                             MICRO-BUILD 462E-A.5
//
// MOTOR 100% LOCAL — DETERMINÍSTICO — SEM IA — SEM REDE — SEM RAG
//
// Responsabilidade exclusiva:
//   • Inspecionar strings de resposta clínica gerada por IA buscando truncamentos.
//   • Retornar TruncationCheckResult com status, confidence e reason.
//   • Garantir que NUNCA instruções numéricas de dosagem parciais atinjam a UI.
//
// BIOHAZARD CLÍNICO — FAIL-CLOSED OBRIGATÓRIO:
//   • Número parcial de dosagem (ex: "Velocidade: **55–7") é PERIGO ABSOLUTO.
//   • Qualquer string de resposta com truncation=true e confidence=high deve:
//       1. Interromper o pipeline de apresentação IMEDIATAMENTE.
//       2. Disparar EXATAMENTE UM retry automatizado.
//       3. Se falhar 2ª vez → DROP TOTAL do payload → fallback estático seguro.
//       NUNCA renderizar instrução numérica fracionada.
//
// Heurísticas implementadas (confidence=high se QUALQUER uma disparar):
//   H1. Markdown Unclosed: token ** aberto sem fechamento no EOF.
//   H2. Numeric Range Abrupt End: dosagem terminando em separador (55–, 10-, >).
//   H3. Mid-Numeric Cut: linha cortando no meio de número/unidade.
//   H4. Non-Punctuation Abrupt End: texto terminando sem pontuação padrão.
//
// Telemetria estruturada:
//   [TRUNCATION_CHECK] requestId=... truncated=... confidence=... reason=...
//                      repairAttempted=... repairSucceeded=...
//
// Arquitetura: all-static, zero-state, zero-network — consistente com engine.
// ══════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
// TruncationConfidence — nível de certeza do heurístico de truncamento
// ─────────────────────────────────────────────────────────────────────────────
enum TruncationConfidence {
  /// Detecção ambígua ou fraca — pode ser falso positivo.
  low,

  /// Sinal moderado — comportamento suspeito mas sem certeza clínica.
  medium,

  /// Sinal forte e inequívoco — requer halt imediato do pipeline.
  /// Condições: token MD unclosed, range numérico truncado, corte mid-numeric.
  high,
}

// ─────────────────────────────────────────────────────────────────────────────
// TruncationCheckResult — resultado imutável da inspeção de truncamento
// ─────────────────────────────────────────────────────────────────────────────
class TruncationCheckResult {
  /// true se o heurístico detectou truncamento estrutural.
  final bool isTruncated;

  /// Nível de confiança da detecção.
  final TruncationConfidence confidenceLevel;

  /// Razão legível do truncamento detectado (null se isTruncated==false).
  final String? violationReason;

  /// true se o pipeline disparou um retry automatizado.
  final bool didRetry;

  /// true se o retry foi bem-sucedido (payload reparado e validado).
  final bool didFix;

  const TruncationCheckResult({
    required this.isTruncated,
    required this.confidenceLevel,
    this.violationReason,
    this.didRetry = false,
    this.didFix = false,
  });

  /// Resultado canônico para texto limpo (sem truncamento detectado).
  static const TruncationCheckResult clean = TruncationCheckResult(
    isTruncated: false,
    confidenceLevel: TruncationConfidence.low,
    violationReason: null,
  );

  /// Cria uma cópia com campos de repair atualizados (para pipeline de retry).
  TruncationCheckResult withRepair({
    required bool retried,
    required bool fixed,
  }) {
    return TruncationCheckResult(
      isTruncated: isTruncated,
      confidenceLevel: confidenceLevel,
      violationReason: violationReason,
      didRetry: retried,
      didFix: fixed,
    );
  }

  @override
  String toString() {
    return 'TruncationCheckResult('
        'isTruncated=$isTruncated, '
        'confidence=${confidenceLevel.name}, '
        'reason=${violationReason ?? "none"}, '
        'didRetry=$didRetry, '
        'didFix=$didFix'
        ')';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TruncationInspector — inspetor heurístico estrutural
//
// Métodos: all-static, zero-state, zero-network.
// Entrada: String bruta de texto de resposta AI (antes de qualquer renderização).
// Saída: TruncationCheckResult determinístico.
//
// REGRA DE ESCALADA DE CONFIDENCE:
//   • H1 (Markdown unclosed **) → confidence=high
//   • H2 (Range numérico abruptamente encerrado em separador) → confidence=high
//   • H3 (Corte mid-numeric/unit) → confidence=high
//   • H4 (Terminação sem pontuação) → confidence=medium (sem override de H1-H3)
//
// Se QUALQUER H1/H2/H3 disparar → isTruncated=true, confidence=high.
// Se APENAS H4 disparar → isTruncated=true, confidence=medium.
// Nenhuma heurística disparada → TruncationCheckResult.clean.
// ─────────────────────────────────────────────────────────────────────────────
class TruncationInspector {
  TruncationInspector._();

  // ── H1: Markdown Unclosed ─────────────────────────────────────────────────
  //
  // Detecta token ** aberto no EOF sem fechamento adequado.
  // Casos:
  //   a) Texto termina com "**" (ex: "dose máxima é **")
  //   b) Contagem ímpar de "**" no texto (sem normalização de escape)
  //
  // Nota: verificamos apenas "**" não dentro de código fence (```).
  // ─────────────────────────────────────────────────────────────────────────
  static bool _hasUnclosedMarkdownBold(String text) {
    final trimmed = text.trimRight();

    // Case A: termina literalmente com **
    if (trimmed.endsWith('**')) return true;

    // Case B: contagem ímpar de ** no texto → token sem fechamento
    // Remove code fences para não contar `` backtick blocks
    final withoutCodeFences = trimmed.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    final boldTokenCount = '**'.allMatches(withoutCodeFences).length;
    if (boldTokenCount.isOdd) return true;

    return false;
  }

  // ── H2: Numeric Range Abrupt End ─────────────────────────────────────────
  //
  // Detecta dosagem ou intervalo numérico terminando em separador.
  // Padrões: "55–" "10-" "5>" "> " ao EOF.
  //
  // Regex: \d+\s*[–\-—>]\s*$
  // ─────────────────────────────────────────────────────────────────────────
  static final RegExp _numericRangeAbruptEnd = RegExp(
    r'\d+\s*[–\-—>]\s*$',
  );

  static bool _hasNumericRangeAbruptEnd(String text) {
    return _numericRangeAbruptEnd.hasMatch(text.trimRight());
  }

  // ── H3: Mid-Numeric / Mid-Unit Cut ───────────────────────────────────────
  //
  // Detecta linha cortada no meio de um número ou unidade clínica.
  // Padrões críticos:
  //   "**55–7"    → bold range incompleto (55– sem upper bound; ou upper=7 sem unidade)
  //   "Velocidade: **55–7"  → exato do mandato Test C
  //   "\d+[–\-]\d+\s*$" sem unidade após número (ex: "55–7" ao EOF sem mg, mL/h etc.)
  //   Qualquer linha terminando em dígito após separador (ex: "mcg: 0.1–0")
  //
  // Abordagem: múltiplas regexes para cobertura exaustiva.
  // ─────────────────────────────────────────────────────────────────────────

  // Bold-range incompleto: **\d+[–-]\d* ao EOF (número aberto dentro de bold)
  static final RegExp _boldRangeCut = RegExp(
    r'\*\*\d+[–\-—]\d*\s*$',
  );

  // Range numerico terminando em dígito sem unidade clínica
  // "55–7" "0.1–3" ao EOF sem sufixo de unidade (mg/h, mL/h, mcg, etc.)
  static final RegExp _numericRangeNoUnit = RegExp(
    r'\d+[–\-—]\d+\s*$',
  );

  // Linha terminando em dígito imediatamente (sem pontuação ou unidade)
  static final RegExp _trailingDigit = RegExp(
    r'\d\s*$',
  );

  static bool _hasMidNumericCut(String text) {
    final trimmed = text.trimRight();

    // H3a: bold range incompleto (ex: "**55–7" ou "**55–")
    if (_boldRangeCut.hasMatch(trimmed)) return true;

    // H3b: range numérico sem unidade ao EOF (ex: "velocidade: 55–7")
    // Distinguir de texto normal que termine em ano/versão como "2024" sem range
    if (_numericRangeNoUnit.hasMatch(trimmed)) {
      // Aplica apenas quando há separador de range (– ou -) — não é número isolado
      return true;
    }

    return false;
  }

  // ── H4: Non-Punctuation Abrupt End ───────────────────────────────────────
  //
  // Detecta texto terminando abruptamente sem pontuação padrão de encerramento.
  // Pontuação esperada ao EOF: . ? ! : ) ] } " '
  //
  // Nota: confidence=medium (mais conservador que H1-H3).
  // Usado como indicador complementar, não suficiente sozinho para confidence=high.
  // ─────────────────────────────────────────────────────────────────────────
  static const Set<String> _closingPunctuation = {
    '.', '?', '!', ':', ')', ']', '}', '"', "'", '»', '…',
  };

  static bool _hasAbruptNonPunctuationEnd(String text) {
    final trimmed = text.trimRight();
    if (trimmed.isEmpty) return false;
    final lastChar = trimmed[trimmed.length - 1];
    // Dígito ao EOF (sem unidade/pontuação) é sinal de truncamento
    if (RegExp(r'\d').hasMatch(lastChar)) return true;
    return !_closingPunctuation.contains(lastChar);
  }

  // ── inspect() — ponto de entrada público ─────────────────────────────────
  //
  // Executa H1→H4 em sequência e retorna o TruncationCheckResult adequado.
  // Ordem de avaliação determina razão primária reportada.
  //
  // Uso:
  //   final result = TruncationInspector.inspect(aiResponseText);
  //   if (result.isTruncated && result.confidenceLevel == TruncationConfidence.high) {
  //     // halt → retry → drop pipeline
  //   }
  // ─────────────────────────────────────────────────────────────────────────
  static TruncationCheckResult inspect(String text) {
    if (text.isEmpty) return TruncationCheckResult.clean;

    // ── H1: Unclosed Markdown Bold ────────────────────────────────────────
    if (_hasUnclosedMarkdownBold(text)) {
      return const TruncationCheckResult(
        isTruncated: true,
        confidenceLevel: TruncationConfidence.high,
        violationReason: 'unclosed_markdown_bold_at_eof',
      );
    }

    // ── H2: Numeric Range Abrupt End ─────────────────────────────────────
    if (_hasNumericRangeAbruptEnd(text)) {
      return const TruncationCheckResult(
        isTruncated: true,
        confidenceLevel: TruncationConfidence.high,
        violationReason: 'numeric_range_abrupt_end_on_separator',
      );
    }

    // ── H3: Mid-Numeric / Mid-Unit Cut ───────────────────────────────────
    if (_hasMidNumericCut(text)) {
      return const TruncationCheckResult(
        isTruncated: true,
        confidenceLevel: TruncationConfidence.high,
        violationReason: 'mid_numeric_or_unit_cut',
      );
    }

    // ── H4: Non-Punctuation Abrupt End ───────────────────────────────────
    if (_hasAbruptNonPunctuationEnd(text)) {
      return const TruncationCheckResult(
        isTruncated: true,
        confidenceLevel: TruncationConfidence.medium,
        violationReason: 'abrupt_non_punctuation_termination',
      );
    }

    return TruncationCheckResult.clean;
  }

  // ── emitTelemetry() — telemetria estruturada de inspeção ─────────────────
  //
  // Formato:
  //   [TRUNCATION_CHECK] requestId=... truncated=... confidence=... reason=...
  //                      repairAttempted=... repairSucceeded=...
  //
  // Deve ser chamado após inspect() e após qualquer operação de repair.
  // ─────────────────────────────────────────────────────────────────────────
  // ignore: avoid_print
  static void emitTelemetry({
    required String requestId,
    required TruncationCheckResult result,
  }) {
    // ignore: avoid_print
    print('[TRUNCATION_CHECK] '
        'requestId=$requestId '
        'truncated=${result.isTruncated} '
        'confidence=${result.confidenceLevel.name} '
        'reason=${result.violationReason ?? "none"} '
        'repairAttempted=${result.didRetry} '
        'repairSucceeded=${result.didFix}');
  }
}
