import 'dart:collection';

// ══════════════════════════════════════════════════════════════════════════════
// external_tool_link_engine.dart — Deep Link Router v1.5 (MICRO-BUILD 462E-A.5.1)
//
// MOTOR 100% LOCAL — DETERMINÍSTICO — SEM IA — SEM REDE — SEM RAG
//
// Responsabilidade exclusiva:
//   • Detectar termo técnico clínico em lastUserMessage + lastAiResponse.
//   • Mapear para uma das 10 abas de medcasescalcu.com.
//   • Gerar URL limpa com lang (1º param) + tab + q (NUNCA dados do paciente).
//   • Retornar label localizado (PT-BR / ES) para o botão _ExternalToolButton.
//
// MICRO-BUILD 462E-A.5 — POSITIVE-PATH INTENT CONVERGENCE + TRUNCATION FAIL-CLOSED:
//   • ExternalToolDecision: fábrica imutável e canônica de decisões de roteamento.
//   • decisionKey: cache por requestId+intent+drugs → idempotência durante rebuilds.
//   • resolveExternalToolIntent() refatorado: matriz de prioridade mutuamente exclusiva.
//   • Bloco B (dilution) NUNCA consume tokens de infusão (bomba de infusão → C).
//   • Bloco C (infusion) promovido a alta prioridade; absorve bomba, velocidade, mg/h.
//   • Bloco E (drugInformation) adicionado para mecanismo, indicações, etc.
//   • [EXT_TOOL_DECISION] telemetria: emitida SOMENTE na primeira computação.
//   • [EXT_TOOL_PAYLOAD_READY] e [EXT_TOOL_OPENED_BY_USER] como telemetria isolada.
//
// MICRO-BUILD 462E-A.4 — COMPLETE EXT_TOOL INPUT SOVEREIGNTY (mantido):
//   • ExternalToolIntent enum: representa a intenção SOBERANA da entrada do usuário.
//   • resolveExternalToolIntent(): executa EXCLUSIVAMENTE contra originalUserInput.
//   • Total Embargo Gate em build(): se intent == ExternalToolIntent.none →
//     retorno null imediato, ANTES de qualquer avaliação do texto AI.
//   • Step 11 (Build 280 — fármaco da bolha AI) é desativado quando intent==none.
//   • [EXT_TOOL_GATE] telemetry emitida na sequência de interceptação de roteamento.
//
// PROIBIÇÃO ABSOLUTA:
//   • O texto da IA (generatedText, finalText, sanitizedResponse) é MATEMATICAMENTE
//     proibido de estabelecer, mudar, ou inicializar estados de ferramentas,
//     seleções de tab, ou parâmetros de fármaco.
//   • O texto AI SOMENTE pode preencher placeholders dentro de um tipo de ferramenta
//     que foi PRÉ-AUTORIZADO e inicializado pelo check soberano de entrada.
//
// Segurança absoluta:
//   • Apenas termos técnicos isolados (nome do fármaco, score, calculadora).
//   • NUNCA inclui: nome do paciente, idade, dados vitais, diagnóstico completo.
//   • URL máxima: base + lang + tab + 1-2 query params de máx 40 chars cada.
//
// Rotas disponíveis em medcasescalcu.com (v1.1 — com ?lang=pt|es obrigatório):
//   ?lang=pt|es&tab=farmacos&q=<nome>
//   ?lang=pt|es&tab=interacoes&drug1=<d1>&drug2=<d2>
//   ?lang=pt|es&tab=scores&q=<nome>
//   ?lang=pt|es&tab=calculadoras&q=<nome>
//   ?lang=pt|es&tab=eletrolitos&q=<nome>
//   ?lang=pt|es&tab=infusao&q=<nome>
//   ?lang=pt|es&tab=hemodinamica&q=<nome>
//   ?lang=pt|es&tab=fluidos
//   ?lang=pt|es&tab=pediatria
//   ?lang=pt|es&tab=gestante
//
// Resolução de lang (em ordem de prioridade):
//   1. currentLanguage == 'es*' → 'es'
//   2. currentLanguage == 'pt*' → 'pt'
//   3. currentLanguage vazio/nulo/inválido → detectar ES no texto combinado
//   4. fallback final → 'pt'
// ══════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
// CalculatorContext — Build 223: identificador de contexto clínico
// A decisão acontece NO PIPELINE, nunca na UI.
// Expansível: adicionar novo valor sem quebrar chamadas existentes.
// Nota: usa 'dflt' (não 'default') — 'default' é palavra reservada no Dart.
// ─────────────────────────────────────────────────────────────────────────────
enum CalculatorContext {
  drug,         // Fármaco específico (ceftriaxona, amiodarona, etc.)
  electrolytes, // Eletrólitos genérico (cloro, sem contexto específico)
  potassium,    // Potássio / Hipocalemia / Hipercalemia
  sodium,       // Sódio / Hiponatremia / Hipernatremia
  calcium,      // Cálcio / Hipocalcemia / Hipercalcemia
  magnesium,    // Magnésio / Hipomagnesemia
  phosphorus,   // Fósforo / Hipofosfatemia
  glucose,      // Glicose / CAD / EHH / Hipoglicemia / Insulina EV
  insulin,      // Insulina (infusão contínua / protocolo)
  acid_base,    // Equilíbrio ácido-base (ânion gap, BE, bicarbonato)
  renal,        // Função renal / IRA / IRC / ajuste de dose
  clcr,         // Clearance de creatinina (Cockcroft-Gault / CKD-EPI)
  vasoactive,   // Drogas vasoativas / hemodinâmica
  antibiotics,  // Antibióticos (sem interação específica)
  infusion,     // Cálculo de infusão EV (mcg/kg/min → mL/h)
  pediatric,    // Módulo pediátrico
  weight,       // Peso / IMC / dose/kg / superfície corporal
  fluid,        // Fluidos / reposição volêmica
  heparin,      // Heparina / anticoagulação
  nutrition,    // Nutrição parenteral / enteral
  dflt,         // Geral / sem contexto específico identificado
}

// ─────────────────────────────────────────────────────────────────────────────
// ExternalToolIntent — MICRO-BUILD 462E-A.4 / 462E-A.5: Sovereign Intent Enum
//
// Representa a intenção SOBERANA da entrada original do usuário.
// Resolvido EXCLUSIVAMENTE por resolveExternalToolIntent(originalUserInput).
// O texto da IA (lastAiResponse) é matematicamente proibido de influenciar
// este valor.
//
// Hierarquia de prioridade (ordem de avaliação em resolveExternalToolIntent v1.4):
//   A. drugInteraction  → palavras-chave explícitas de interação PT/ES
//   B. dilution (STRICT) → APENAS diluir/reconstituir/volume/concentração final
//                          NÃO consome tokens de infusão (bomba de infusão → C)
//   C. infusion (HIGH)   → bomba de infus[aã]o, velocidade, mg/h, mL/h, titular
//   D. dosage           → dose, posologia, ajuste renal PT/ES
//   E. drugInformation  → mecanismo, indicações, contraindicações, efeitos adversos
//   F. none             → nenhuma intenção explícita detectada → EMBARGO TOTAL
// ─────────────────────────────────────────────────────────────────────────────
enum ExternalToolIntent {
  none,            // Nenhuma intenção explícita → embargo total de ferramentas
  drugInteraction, // Interação entre dois fármacos (explícito PT/ES)
  dilution,        // Diluição / reconstituição / volume final APENAS (PT/ES)
  infusion,        // Infusão EV / velocidade / bomba (alta prioridade PT/ES)
  drugInformation, // Informação geral: mecanismo, indicações, efeitos adversos
  dosage,          // Dose / posologia / ajuste renal (explícito PT/ES)
}

// ─────────────────────────────────────────────────────────────────────────────
// ExternalToolDecision — MICRO-BUILD 462E-A.5: Immutable Canonical Decision Factory
//
// Encapsula o resultado determinístico do roteamento em um objeto imutável.
// Garante que PLANTAO_ANALYSIS, BUILD306 e EXT_TOOL compartilhem UMA ÚNICA
// computação — nunca recalculam independentemente.
//
// Idempotência: cache por decisionKey em ExternalToolLinkEngine._decisionCache.
// Se o mesmo decisionKey re-executa durante widget rebuild, bypassa e retorna
// o estado cacheado. Side-effects disparam EXATAMENTE UMA VEZ.
//
// Target Sovereignty Rule:
//   • primaryDrug e secondaryDrug extraídos EXCLUSIVAMENTE de originalUserInput.
//   • Se o texto AI introduz fármaco adjacente (ex: input pede Noradrenalina,
//     output menciona Vasopressina), os parâmetros ficam congelados no input.
//
// Telemetria isolada por ação:
//   • [EXT_TOOL_DECISION]     → cálculo roda UMA VEZ
//   • [EXT_TOOL_PAYLOAD_READY] → loop de pintura do widget
//   • [EXT_TOOL_OPENED_BY_USER] → tap físico do usuário APENAS
// ─────────────────────────────────────────────────────────────────────────────
class ExternalToolDecision {
  final String requestId;
  final ExternalToolIntent intent;
  final String primaryDrug;
  final String? secondaryDrug;
  final String targetTab;
  final String source; // Always "original_user_input"

  const ExternalToolDecision({
    required this.requestId,
    required this.intent,
    required this.primaryDrug,
    this.secondaryDrug,
    required this.targetTab,
    this.source = 'original_user_input',
  });

  /// Chave única de idempotência: combinação de requestId, intent, primaryDrug e
  /// secondaryDrug. Mesma chave = mesma decisão → bypassa recalculação.
  String get decisionKey =>
      '${requestId}_${intent.name}_${primaryDrug}_${secondaryDrug ?? "none"}';

  // ── MICRO-BUILD 462E-A.5.1: toRouterTask() ──────────────────────────────
  //
  // Converte esta decisão canônica para uma label de task do router clínico.
  // Usado pelo authority conditional ladder em sendAiMessage():
  //   if (canonicalDecision.intent != ExternalToolIntent.none) {
  //     task = canonicalDecision.toRouterTask();
  //   }
  //
  // Mapeamento direto intent → taskLabel (determinístico, zero-rede):
  //   drugInteraction → 'interacao_medicamentosa'
  //   dilution        → 'diluicao_ev'
  //   infusion        → 'infusao_ev'
  //   dosage          → 'dose_farmaco'
  //   drugInformation → 'informacao_farmaco'
  //   none            → '' (nunca deve ser chamado com none)
  // ─────────────────────────────────────────────────────────────────────────
  String toRouterTask() {
    switch (intent) {
      case ExternalToolIntent.drugInteraction:
        return 'interacao_medicamentosa';
      case ExternalToolIntent.dilution:
        return 'diluicao_ev';
      case ExternalToolIntent.infusion:
        return 'infusao_ev';
      case ExternalToolIntent.dosage:
        return 'dose_farmaco';
      case ExternalToolIntent.drugInformation:
        return 'informacao_farmaco';
      case ExternalToolIntent.none:
        return '';
    }
  }
}

const String _kBase = 'https://medcasescalcu.com/';

// ─────────────────────────────────────────────────────────────────────────────
// Output model
// ─────────────────────────────────────────────────────────────────────────────
class ExternalToolLink {
  final String label;                       // PT/ES button label shown to user
  final String url;                         // full https://medcasescalcu.com/?lang=pt|es&tab=...&q=...
  final CalculatorContext calculatorContext; // Build 223: contexto clínico (pipeline-level, nunca UI)

  const ExternalToolLink({
    required this.label,
    required this.url,
    this.calculatorContext = CalculatorContext.dflt,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Engine — all static, zero-state (except _decisionCache), zero-network
// ─────────────────────────────────────────────────────────────────────────────
class ExternalToolLinkEngine {
  ExternalToolLinkEngine._();

  // ── MICRO-BUILD 462E-A.5: Idempotency Cache ──────────────────────────────
  //
  // Cache de decisões por decisionKey.
  // Garante que side-effects (telemetria [EXT_TOOL_DECISION], tab selection,
  // drug parameter binding) disparem EXATAMENTE UMA VEZ por requestId+intent.
  //
  // Ciclo de vida: o cache é de escopo estático (persiste durante a sessão).
  // Widget rebuilds com o mesmo decisionKey retornam o resultado cacheado
  // sem re-executar o pipeline de roteamento.
  // ─────────────────────────────────────────────────────────────────────────
  // ── MICRO-BUILD 462E-A.5.1: Bounded LinkedHashMap Cache ────────────────────
  //
  // LinkedHashMap mantém ordem de inserção → permite evicção LRU-style
  // ao atingir _maxDecisionCacheEntries (200 entradas).
  // Proteção contra memory leak em sessões longas ou múltiplos requests.
  // ─────────────────────────────────────────────────────────────────────────
  static final LinkedHashMap<String, ExternalToolDecision> _decisionCache =
      LinkedHashMap<String, ExternalToolDecision>();
  static const int _maxDecisionCacheEntries = 200;

  /// Registra uma decisão no cache e emite telemetria [EXT_TOOL_DECISION].
  /// Somente emite a telemetria se a chave ainda não estava no cache (primeira
  /// computação). Side-effects posteriores com a mesma chave são silenciados.
  static ExternalToolDecision _cacheDecision(ExternalToolDecision decision) {
    final key = decision.decisionKey;
    if (_decisionCache.containsKey(key)) {
      // Cache hit: retorna estado existente sem re-executar side-effects.
      return _decisionCache[key]!;
    }
    // Cache miss: primeira computação — emite telemetria e armazena.
    _decisionCache[key] = decision;
    // ignore: avoid_print
    print('[EXT_TOOL_DECISION] requestId=${decision.requestId} '
        'intent=${decision.intent.name} '
        'primaryDrug=${decision.primaryDrug} '
        'secondaryDrug=${decision.secondaryDrug ?? "none"} '
        'targetTab=${decision.targetTab} '
        'source=${decision.source} '
        'decisionKey=$key '
        'computedOnce=true');
    return decision;
  }

  /// Emite telemetria de renderização do card (widget paint loop).
  /// Deve ser chamado dentro do widget build — NUNCA confundir com [EXT_TOOL_DECISION].
  // ignore: avoid_print
  static void emitCardRendered(String decisionKey) {
    // ignore: avoid_print
    print('[EXT_TOOL_PAYLOAD_READY] decisionKey=$decisionKey');
  }

  /// Emite telemetria de tap físico do usuário na ferramenta externa.
  /// Deve ser chamado SOMENTE no handler onTap — NUNCA no build.
  // ignore: avoid_print
  static void emitOpenedByUser(String decisionKey) {
    // ignore: avoid_print
    print('[EXT_TOOL_OPENED_BY_USER] decisionKey=$decisionKey');
  }

  // ── MICRO-BUILD 462E-A.5.1: resolveDecision() — Single-Execution Factory ──
  //
  // Ponto de entrada canônico para computação de decisão de roteamento.
  // DEVE ser chamado EXATAMENTE UMA VEZ por requestId, no início de
  // sendAiMessage() antes de qualquer despacho para subsistemas downstream.
  //
  // Regras:
  //   • Cache hit (decisionKey já presente) → retorna estado cacheado, zero side-effects.
  //   • Cache miss → computa via resolveExternalToolIntent(), constrói ExternalToolDecision,
  //     armazena via _cacheDecision(), emite [EXT_TOOL_DECISION] telemetria (UMA VEZ).
  //   • Evicção LRU: quando cache ≥ 200 entradas, remove a entrada mais antiga (FIFO).
  //   • NUNCA re-invoca resolveExternalToolIntent() se o requestId já foi processado.
  //
  // Returns null quando intent == ExternalToolIntent.none (embargo total).
  // ─────────────────────────────────────────────────────────────────────────
  static ExternalToolDecision? resolveDecision(
    String requestId,
    String userInput,
  ) {
    final intent = resolveExternalToolIntent(userInput);
    if (intent == ExternalToolIntent.none) return null;

    // Extrair primaryDrug a partir do userInput (delegado ao build() engine)
    // Para o cache key, usamos o intent sem drug (lookup simplificado por requestId)
    // O drug-level será resolvido pelo build() call-site downstream.
    // decisionKey parcial (requestId+intent) para lookup de idempotência aqui.
    final partialKey = '${requestId}_${intent.name}';
    if (_decisionCache.containsKey(partialKey)) {
      return _decisionCache[partialKey];
    }

    // Evicção LRU: remove a entrada mais antiga ao atingir o limite.
    if (_decisionCache.length >= _maxDecisionCacheEntries) {
      final oldestKey = _decisionCache.keys.first;
      _decisionCache.remove(oldestKey);
      // ignore: avoid_print
      print('[EXT_TOOL_CACHE] EVICT oldest=$oldestKey size=${_decisionCache.length}');
    }

    // Mapear intent para targetTab canônico
    final targetTab = _intentToTab(intent);

    final decision = ExternalToolDecision(
      requestId:   requestId,
      intent:      intent,
      primaryDrug: '', // Resolvido pelo build() com acesso a lastAiResponse
      targetTab:   targetTab,
      source:      'original_user_input',
    );

    _decisionCache[partialKey] = decision;
    // ignore: avoid_print
    print('[EXT_TOOL_DECISION][RESOLVE] requestId=$requestId '
        'intent=${intent.name} '
        'targetTab=$targetTab '
        'partialKey=$partialKey '
        'cacheSize=${_decisionCache.length} '
        'computedOnce=true');
    return decision;
  }

  /// Mapeia ExternalToolIntent para a aba canônica de destino.
  static String _intentToTab(ExternalToolIntent intent) {
    switch (intent) {
      case ExternalToolIntent.drugInteraction:
        return 'interacoes';
      case ExternalToolIntent.dilution:
        return 'farmacos';
      case ExternalToolIntent.infusion:
        return 'infusao';
      case ExternalToolIntent.dosage:
        return 'farmacos';
      case ExternalToolIntent.drugInformation:
        return 'farmacos';
      case ExternalToolIntent.none:
        return '';
    }
  }

  // ── MICRO-BUILD 462E-A.5.1: releaseDecision() — Lifecycle Release ──────────
  //
  // Remove uma entrada específica do cache ao atingir estado terminal.
  // INVOCAR em: COMPLETED, CANCELLED, FAILED, TIMEOUT.
  // NÃO invocar em: session swap (requests em voo ainda precisam do cache).
  //
  // Aceita tanto o decisionKey completo (de ExternalToolDecision.decisionKey)
  // quanto o partialKey (requestId_intent) usado internamente por resolveDecision().
  // ─────────────────────────────────────────────────────────────────────────
  static void releaseDecision(String decisionKey) {
    final removed = _decisionCache.remove(decisionKey);
    final didEvict = removed != null;
    // ignore: avoid_print
    print('[EXT_TOOL_CACHE][RELEASE] key=$decisionKey '
        'found=$didEvict '
        'cacheSize=${_decisionCache.length}');
  }

  // ── MICRO-BUILD 462E-A.5.3.2: releaseByRequestId() — Bulk Lifecycle Release ─
  //
  // Flushes ALL cache entries whose key starts with '${requestId}_'.
  // Covers the case where canonicalDecision is null at terminal time (the
  // partial key was stored by resolveDecision but the caller no longer holds
  // a reference to the ExternalToolDecision object).
  //
  // Emits a single consolidated telemetry line with removed count.
  // ─────────────────────────────────────────────────────────────────────────
  static void releaseByRequestId(String requestId) {
    final prefix = '${requestId}_';
    final keys = _decisionCache.keys
        .where((key) => key.startsWith(prefix))
        .toList(growable: false);

    if (keys.isEmpty) {
      // ignore: avoid_print
      print('[EXT_TOOL_CACHE][RELEASE_BY_REQUEST] requestId=$requestId '
          'found=false removed=0 cacheSize=${_decisionCache.length}');
      return;
    }

    for (final key in keys) {
      _decisionCache.remove(key);
    }

    // ignore: avoid_print
    print('[EXT_TOOL_CACHE][RELEASE_BY_REQUEST] requestId=$requestId '
        'found=true removed=${keys.length} cacheSize=${_decisionCache.length}');
  }

  // ── MICRO-BUILD 462E-A.5.3.2: releaseCanonicalDecision() — Unified Gateway ──
  //
  // Single lifecycle gateway used by ALL terminal call-sites in app_provider.dart.
  //
  // Contract:
  //   • decision != null → release via exact decisionKey (decision.decisionKey
  //     is NEVER the correct key; the stored key is the partialKey used by
  //     resolveDecision — so we derive it as '${requestId}_${intent.name}').
  //   • decision == null → flush all keys matching '${requestId}_' prefix
  //     via releaseByRequestId() (safe even if cache was never populated).
  //
  // This eliminates all manual string concat at the 20 call-sites and
  // provides a deterministic, single-point telemetry path.
  // ─────────────────────────────────────────────────────────────────────────
  static void releaseCanonicalDecision({
    required String requestId,
    ExternalToolDecision? decision,
  }) {
    if (decision != null) {
      // The cache stored partialKey = '${requestId}_${intent.name}'.
      // We derive it the same way resolveDecision() does.
      final partialKey = '${requestId}_${decision.intent.name}';
      releaseDecision(partialKey);
      return;
    }
    releaseByRequestId(requestId);
  }

  // ── MICRO-BUILD 462E-A.5.1: clearDecisionCache() — Deep Cleanup ────────────
  //
  // Limpeza completa do cache. Executar SOMENTE em:
  //   • logout do usuário
  //   • troca de usuário ativo
  //   • securityWipe explícito
  //
  // NÃO executar em: session swap, troca de modo (Plantão↔Estudo),
  // restart de stream, ou retry de request — esses caminhos devem usar
  // releaseDecision() por entrada individual.
  // ─────────────────────────────────────────────────────────────────────────
  // BUILD 463-A.1.1: clearDecisionCache() → clearAllDecisions() unified sweep.
  // Legacy alias preserved for test call-sites that still reference the old name.
  static void clearDecisionCache() =>
      clearAllDecisions(reason: 'lifecycle_deep_clean');

  /// BUILD 463-A.1.1: Explicit global cache sweep invoked on authMismatch and logout.
  /// Eradicates all decision state left by the previous identity context so it
  /// cannot bleed into the next user's session.
  static void clearAllDecisions({required String reason}) {
    final int removedCount = _decisionCache.length;
    _decisionCache.clear();
    // ignore: avoid_print
    print('[EXT_TOOL_CACHE][CLEAR_ALL] reason=$reason removed=$removedCount cacheSize=${_decisionCache.length}');
  }

  /// Returns current number of entries in the decision cache (for test assertions).
  static int get decisionCacheSize => _decisionCache.length;

  // ── BUILD 462E-A.3: Input Sovereignty — Deterministic Intent Matchers ──────
  //
  // PARADIGMA DE SOBERANIA DE ENTRADA:
  //   • O estado da aplicação (intent, ferramentas externas, tabs) é governado
  //     EXCLUSIVAMENTE pela entrada original do usuário (lastUserMessage).
  //   • O texto gerado pela IA (lastAiResponse) é matematicamente proibido de
  //     mutar intenções ou disparar ferramentas automáticas no Step 1.
  //   • 2+ fármacos mencionados no texto de um caso clínico sem palavras-chave
  //     explícitas de interação NÃO devem disparar o botão de interação.
  //
  // REGRA CHAVE:
  //   Step 1 (interação entre dois fármacos) → gated por hasExplicitInteractionIntent()
  //   Step 11 (fármaco único da resposta AI) → Build 280 intencional, mantido.
  // ─────────────────────────────────────────────────────────────────────────────

  /// Retorna true se [userInput] contém palavras-chave EXPLÍCITAS de intenção
  /// de interação medicamentosa em PT-BR ou ES.
  ///
  /// 14 padrões cobrindo formas canônicas e variantes ortográficas:
  ///   PT: interação entre, interage com, pode usar junto, pode associar,
  ///       é seguro combinar, contraindicação entre, há interação
  ///   ES: interacción entre, interactúa con, se puede usar junto,
  ///       se puede asociar, es seguro combinar, contraindicación entre,
  ///       hay interacción
  ///
  /// Apenas [userInput] é aceito — NUNCA o texto da resposta AI.
  static bool hasExplicitInteractionIntent(String userInput) {
    final normalized = userInput.toLowerCase().trim();
    const patterns = <String>[
      r'\bintera[cç][aã]o entre\b',
      r'\binteracci[oó]n entre\b',
      r'\binterage com\b',
      r'\binteract[uú]a con\b',
      r'\bpode usar junto\b',
      r'\bse puede usar junto\b',
      r'\bpode associar\b',
      r'\bse puede asociar\b',
      r'(?:^|\s)[eé] seguro combinar',
      r'\bes seguro combinar\b',
      r'\bcontraindica[cç][aã]o entre\b',
      r'\bcontraindicaci[oó]n entre\b',
      r'\bh[aá] intera[cç][aã]o\b',
      r'\bhay interacci[oó]n\b',
    ];
    return patterns.any(
      (p) => RegExp(p, caseSensitive: false).hasMatch(normalized),
    );
  }

  /// Retorna true se [userInput] contém palavras-chave EXPLÍCITAS de intenção
  /// de diluição / reconstituição em PT-BR ou ES.
  ///
  /// MICRO-BUILD 462E-A.5 — RESTRIÇÃO ESTRITA:
  ///   • 'bomba de infusão' / 'bomba de infusión' REMOVIDOS deste método.
  ///   • Esses tokens pertencem a hasExplicitInfusionIntent() / bloco C de
  ///     resolveExternalToolIntent() e NUNCA devem ser capturados como dilution.
  ///   • Dilution = exclusivamente preparação física: diluir, reconstituir,
  ///     volume final, concentração final.
  ///
  /// 5 clusters semânticos (reduzidos de 6): diluir, reconstituir,
  /// volume final, concentração final — formas PT e ES.
  ///
  /// Apenas [userInput] é aceito — NUNCA o texto da resposta AI.
  static bool hasExplicitDilutionIntent(String userInput) {
    final normalized = userInput.toLowerCase().trim();
    return RegExp(
      r'\b('
      r'diluir|dilui[cç][aã]o|diluci[oó]n|'
      r'reconstituir|reconstitui[cç][aã]o|reconstituci[oó]n|'
      r'volume final|volumen final|'
      r'concentra[cç][aã]o final|concentraci[oó]n final'
      r')\b',
      caseSensitive: false,
    ).hasMatch(normalized);
  }

  // ── BUILD 462E-A.5: Sovereign Intent Resolver — Mutually Exclusive Priority Matrix ──
  //
  // Executa EXCLUSIVAMENTE contra originalUserInput (lastUserMessage).
  // NUNCA aceita texto de IA como input — proibição absoluta arquitetural.
  //
  // Matriz de prioridade MUTUAMENTE EXCLUSIVA (sem fallback ambíguo):
  //   A. drugInteraction  → interação entre fármacos PT/ES
  //   B. dilution (STRICT) → SOMENTE: diluir, diluição/dilución,
  //                          reconstituir/reconstituição/reconstitución,
  //                          volume final/volumen final,
  //                          concentração final/concentración final.
  //                          ⚠️ NÃO inclui bomba de infusão → vai para C.
  //   C. infusion (ALTA PRIORIDADE) → bomba de infus[aã]o, bomba de infusi[oó]n,
  //                          infusão, infusión, velocidade, titular, titulação,
  //                          mcg/kg/min, mg/h, mL/h.
  //   D. dosage           → dose, dosagem, dosificación, posologia, posología,
  //                          ajuste renal.
  //   E. drugInformation  → mecanismo, indicações, contraindicações,
  //                          efeitos adversos, presentación.
  //   fallback            → ExternalToolIntent.none (embargo total)
  //
  // Nota sobre Unicode: \b não funciona com 'é' no início de palavra em Dart
  // (é não-ASCII → \b falha). Padrão corrigido: (?:^|\s)[eé] seguro combinar
  //
  // Test A invariante: "bomba de infusão" DEVE resolver para infusion (NUNCA dilution).
  // ─────────────────────────────────────────────────────────────────────────
  static ExternalToolIntent resolveExternalToolIntent(String userInput) {
    final normalized = userInput.toLowerCase().trim();

    // ── A. INTERACTION PATTERNS (PT/ES) ─────────────────────────────────────
    final hasInteraction = <RegExp>[
      RegExp(r'\bintera[cç][aã]o entre\b'),
      RegExp(r'\binteracci[oó]n entre\b'),
      RegExp(r'\binterage com\b'),
      RegExp(r'\binteract[uú]a con\b'),
      RegExp(r'\bpode(m)? usar junto\b'),
      RegExp(r'\bse puede usar junto\b'),
      RegExp(r'\bpode associar\b'),
      RegExp(r'\bse puede asociar\b'),
      RegExp(r'(?:^|\s)[eé] seguro combinar'),   // fix: é não-ASCII, \b falha
      RegExp(r'\bes seguro combinar\b'),
      RegExp(r'\bcontraindica[cç][aã]o entre\b'),
      RegExp(r'\bcontraindicaci[oó]n entre\b'),
      RegExp(r'\bh[aá] intera[cç][aã]o\b'),
      RegExp(r'\bhay interacci[oó]n\b'),
    ].any((p) => p.hasMatch(normalized));

    if (hasInteraction) return ExternalToolIntent.drugInteraction;

    // ── B. DILUTION PATTERNS — STRICT (PT/ES) ───────────────────────────────
    //
    // ⚠️ RESTRIÇÃO CRÍTICA 462E-A.5:
    //   • Este bloco NÃO inclui 'bomba de infus[aã]o' / 'bomba de infusi[oó]n'.
    //   • Esses tokens pertencem EXCLUSIVAMENTE ao bloco C (infusion).
    //   • 'concentra[cç][aã]o final' e 'concentraci[oó]n final' são permitidos
    //     (concentração de diluição específica) mas 'concentra[cç][aã]o' genérico
    //     foi removido para evitar colisão com contextos de infusão.
    // ─────────────────────────────────────────────────────────────────────────
    final hasDilution = RegExp(
      r'\b('
      r'diluir|dilui[cç][aã]o|diluci[oó]n|'
      r'reconstituir|reconstitui[cç][aã]o|reconstituci[oó]n|'
      r'volume final|volumen final|'
      r'concentra[cç][aã]o final|concentraci[oó]n final'
      r')\b',
      caseSensitive: false,
    ).hasMatch(normalized);

    if (hasDilution) return ExternalToolIntent.dilution;

    // ── C. INFUSION PATTERNS — HIGH PRIORITY (PT/ES) ────────────────────────
    //
    // Alta prioridade: captura todos os tokens procedurais de administração EV.
    // ⚠️ ABSORVE 'bomba de infus[aã]o' que foi REMOVIDO do bloco B.
    // Novos tokens 462E-A.5: velocidade, mg/h, mL/h.
    // ─────────────────────────────────────────────────────────────────────────
    final hasInfusion = <RegExp>[
      RegExp(r'\bbomba de infus[aã]o\b'),        // 462E-A.5: movido de B para C
      RegExp(r'\bbomba de infusi[oó]n\b'),        // 462E-A.5: movido de B para C
      RegExp(r'\binfus[aã]o\b'),
      RegExp(r'\binfusi[oó]n\b'),
      RegExp(r'\bvelocidade\b'),                  // 462E-A.5: adicionado
      RegExp(r'\bmg/h\b'),                        // 462E-A.5: adicionado
      RegExp(r'\bml/h\b'),                        // 462E-A.5: adicionado (case-insensitive)
      RegExp(r'\bmcg/kg/min\b'),
      RegExp(r'\btitular\b'),
      RegExp(r'\btitula[cç][aã]o\b'),
      RegExp(r'\btitulaci[oó]n\b'),
      RegExp(r'\bpreparar infus[aã]o\b'),
      RegExp(r'\bcomo administrar em bomba\b'),
    ].any((p) => p.hasMatch(normalized));

    if (hasInfusion) return ExternalToolIntent.infusion;

    // ── D. DOSAGE PATTERNS (PT/ES) ───────────────────────────────────────────
    final hasDosage = <RegExp>[
      RegExp(r'\bdose\b'),
      RegExp(r'\bdosagem\b'),
      RegExp(r'\bdosificaci[oó]n\b'),
      RegExp(r'\bposologia\b'),
      RegExp(r'\bposolog[ií]a\b'),
      RegExp(r'\bajuste renal\b'),
    ].any((p) => p.hasMatch(normalized));

    if (hasDosage) return ExternalToolIntent.dosage;

    // ── E. DRUG INFORMATION PATTERNS (PT/ES) ─────────────────────────────────
    //
    // 462E-A.5: Bloco E adicionado — informações gerais sobre o medicamento.
    // Separado de dosage para permitir roteamento semântico distinto no futuro.
    // ─────────────────────────────────────────────────────────────────────────
    final hasDrugInfoKeyword = <RegExp>[
      RegExp(r'\bmecanismo\b'),
      RegExp(r'\bindica[cç][õo]es\b'),
      RegExp(r'\bindica[cç][aã]o\b'),
      RegExp(r'\bcontraindica[cç][õo]es\b'),
      RegExp(r'\bcontraindica[cç][aã]o\b'),
      RegExp(r'\befeitos adversos\b'),
      RegExp(r'\bapresenta[cç][aã]o\b'),
      RegExp(r'\bpresentaci[oó]n\b'),
      RegExp(r'\binforma[cç][oõ]es sobre o medicamento\b'),
    ].any((p) => p.hasMatch(normalized));

    // Termos farmacológicos genéricos dentro de um caso clínico não
    // autorizam ferramenta externa sem um fármaco explícito na pergunta.
    final hasExplicitDrugTarget = _detectSingleDrug(normalized) != null;

    if (hasDrugInfoKeyword && hasExplicitDrugTarget) {
      return ExternalToolIntent.drugInformation;
    }

    return ExternalToolIntent.none;
  }

  /// Returns an [ExternalToolLink] if a relevant external tool is detected,
  /// or null if no match found.
  ///
  /// [requestId], [transactionId], [attemptId] — optional correlated telemetry
  /// fields for [EXT_TOOL_GATE] log lines (MICRO-BUILD 462E-A.5.3.7.3.1).
  /// Pass empty strings when not available (e.g., UI-layer widget rebuilds).
  static ExternalToolLink? build({
    required String lastUserMessage,
    required String lastAiResponse,
    required bool isPlantaoMode,
    required String currentLanguage,
    String activeThreadTopic = '', // BUILD 249: active thread topic for stale-detection guard
    String requestId    = '',      // MICRO-BUILD 462E-A.5.3.7.3.1: correlated telemetry
    String transactionId = '',     // MICRO-BUILD 462E-A.5.3.7.3.1: correlated telemetry
    String attemptId    = '',      // MICRO-BUILD 462E-A.5.3.7.3.1: correlated telemetry
  }) {
    // ── Resolve lang (priority: explicit > text-detect > fallback pt) ──────
    final String lang = _resolveLang(currentLanguage, lastUserMessage, lastAiResponse);
    final bool isEs = lang == 'es';

    // ══════════════════════════════════════════════════════════════════════════
    // MICRO-BUILD 462E-A.4 — TOTAL EMBARGO GATE
    //
    // resolveExternalToolIntent() executa EXCLUSIVAMENTE contra lastUserMessage.
    // Se intent == ExternalToolIntent.none:
    //   → retorno null IMEDIATO (nenhum chunk de aiOutput é avaliado)
    //   → Step 11 (Build 280 — fármaco da bolha AI) é DESATIVADO completamente
    //   → Nenhuma mutação de: externalToolType, targetTab, taskLabel,
    //     drugTarget, drug1, drug2, dilutionTarget, infusionTarget
    //
    // O texto AI SOMENTE pode preencher parâmetros dentro de um tipo de
    // ferramenta PRÉ-AUTORIZADO pelo check soberano abaixo.
    // ══════════════════════════════════════════════════════════════════════════
    final ExternalToolIntent intent =
        resolveExternalToolIntent(lastUserMessage);
    final bool intentAllowed = intent != ExternalToolIntent.none;

    // ── [EXT_TOOL_GATE] Telemetry ─────────────────────────────────────────
    // MICRO-BUILD 462E-A.5.3.7.3.1 [PILLAR 3]: Full correlated telemetry.
    // requestId/transactionId/attemptId are empty when called from UI layer
    // (widget rebuild); populated when called from the canonical pipeline.
    // ignore: avoid_print
    print('[EXT_TOOL_GATE] '
        'requestId=${requestId.isEmpty ? "ui_layer" : requestId} '
        'parentRequestId=${requestId.isEmpty ? "ui_layer" : requestId} '
        'transactionId=${transactionId.isEmpty ? "ui_layer" : transactionId} '
        'attemptId=${attemptId.isEmpty ? "ui_layer" : attemptId} '
        'phase=resolving '
        'callSite=external_tool_link_engine_build '
        'allowed=$intentAllowed '
        'reason=${intentAllowed ? "explicit_input_intent" : "no_explicit_intent"}');

    if (!intentAllowed) {
      // EMBARGO TOTAL: retorno null antes de qualquer avaliação do texto AI.
      // Step 11 (fármaco da bolha AI) está incluído neste embargo.
      return null;
    }

    // Combine user + AI text for detection (lowercase, no diacritics normalization)
    // Nota: `combined` somente é computado quando intent != none (pós-gate).
    final String combined =
        '${lastUserMessage.toLowerCase()} ${lastAiResponse.toLowerCase()}';

    // ── 1. Interações medicamentosas (dois fármacos detectados) ────────────
    //
    // BUILD 462E-A.3 — INPUT SOVEREIGNTY GATE (preservado):
    //   Step 1 SÓ dispara quando hasExplicitInteractionIntent=true.
    //   BUILD 462E-A.4: Gate adicional via resolveExternalToolIntent() acima
    //   garante que chegamos aqui SOMENTE com intent != none.
    //   Dupla proteção: embargo total (462E-A.4) + gate específico (462E-A.3).
    final interacao = hasExplicitInteractionIntent(lastUserMessage)
        ? _detectDrugInteraction(combined)
        : null;
    if (interacao != null) {
      // ORDEM 29 V2: labels DINÂMICAS — nomes clínicos reais, nunca strings fixas.
      final d1 = interacao.$1;  // _TermMatch com .display e .param
      final d2 = interacao.$2;  // _TermMatch com .display e .param
      final label = isEs
          ? '🚨 Interacción: ${d1.display} + ${d2.display}'
          : '🚨 Interação: ${d1.display} + ${d2.display}';
      _log(lang: lang, tab: 'interacoes',
          extra: 'drug1=${d1.param} drug2=${d2.param} ctx=drug');
      return ExternalToolLink(
        label: label,
        url: _url(lang: lang, tab: 'interacoes',
            extra: 'drug1=${_enc(d1.param)}&drug2=${_enc(d2.param)}'),
        calculatorContext: CalculatorContext.drug,
      );
    }

    // ── 2. Scores / Escalas clínicas ──────────────────────────────────────
    final score = _detectScore(combined);
    if (score != null) {
      final label = '📊 Abrir ${score.display}';
      _log(lang: lang, tab: 'scores', extra: 'q=${score.param} ctx=dflt');
      return ExternalToolLink(
        label: label,
        url: _url(lang: lang, tab: 'scores', q: score.param),
        calculatorContext: CalculatorContext.dflt,
      );
    }

    // ── 3. Calculadoras clínicas ───────────────────────────────────────────
    final calcu = _detectCalculadora(combined);
    if (calcu != null) {
      final calcCtx = _calcContext(calcu.param);
      final label = '🧮 Calcular ${calcu.display}';
      _log(lang: lang, tab: 'calculadoras', extra: 'q=${calcu.param} ctx=$calcCtx');
      return ExternalToolLink(
        label: label,
        url: _url(lang: lang, tab: 'calculadoras', q: calcu.param),
        calculatorContext: calcCtx,
      );
    }

    // ── 4. Eletrólitos ────────────────────────────────────────────────────
    final eletro = _detectEletrolito(combined);
    if (eletro != null) {
      final eletroCtx = _eletroliContext(eletro.param);
      final label = isEs
          ? '⚗️ Abrir ${eletro.display} (electrolitos)'
          : '⚗️ Abrir ${eletro.display} (eletrólitos)';
      _log(lang: lang, tab: 'eletrolitos', extra: 'q=${eletro.param} ctx=$eletroCtx');
      return ExternalToolLink(
        label: label,
        url: _url(lang: lang, tab: 'eletrolitos', q: eletro.param),
        calculatorContext: eletroCtx,
      );
    }

    // ── 5. Infusão / Drogas vasoativas ────────────────────────────────────
    final infusao = _detectInfusao(combined);
    if (infusao != null) {
      final label = isEs
          ? '💉 Calcular infusión: ${infusao.display}'
          : '💉 Calcular infusão: ${infusao.display}';
      _log(lang: lang, tab: 'infusao', extra: 'q=${infusao.param} ctx=infusion');
      return ExternalToolLink(
        label: label,
        url: _url(lang: lang, tab: 'infusao', q: infusao.param),
        calculatorContext: CalculatorContext.infusion,
      );
    }

    // ── 6. Hemodinâmica ───────────────────────────────────────────────────
    final hemodi = _detectHemodinamica(combined);
    if (hemodi != null) {
      final label = isEs ? '❤️ Abrir hemodinámica' : '❤️ Abrir hemodinâmica';
      _log(lang: lang, tab: 'hemodinamica', extra: 'q=${hemodi.param} ctx=vasoactive');
      return ExternalToolLink(
        label: label,
        url: _url(lang: lang, tab: 'hemodinamica', q: hemodi.param),
        calculatorContext: CalculatorContext.vasoactive,
      );
    }

    // ── 7. Fluidos / Reposição volêmica ───────────────────────────────────
    if (_detectFluidos(combined)) {
      final label = isEs ? '🩺 Fluidos y volumen' : '🩺 Fluidos e volume';
      _log(lang: lang, tab: 'fluidos', extra: 'ctx=fluid');
      return ExternalToolLink(
        label: label,
        url: _url(lang: lang, tab: 'fluidos'),
        calculatorContext: CalculatorContext.fluid,
      );
    }

    // ── 8. Fármaco isolado — PRIORIDADE sobre Pediatria ───────────────────
    // Build 188: fármaco específico na query do usuário tem prioridade absoluta
    // sobre pediatria genérica. "ceftriaxona dose" → tab farmacos, nunca pediatria.
    // Detectamos no userMessage (não no combined) para não confundir com resposta AI.
    final drugUserMsg = _detectSingleDrug(lastUserMessage.toLowerCase());
    if (drugUserMsg != null) {
      final drugCtxUser = _drugContext(drugUserMsg.param);
      // ORDEM 29 V2: label contextual baseada no CalculatorContext do fármaco.
      final label = _buildDrugLabel(drugUserMsg.display, drugCtxUser, isEs);
      _log(lang: lang, tab: 'farmacos', extra: 'q=${drugUserMsg.param} ctx=$drugCtxUser');
      return ExternalToolLink(
        label: label,
        url: _url(lang: lang, tab: 'farmacos', q: drugUserMsg.param),
        calculatorContext: drugCtxUser,
      );
    }

    // ── 9. Pediatria — só quando sem fármaco específico na user msg ────────
    // Build 188: _detectPediatria agora exige termos pediátricos EXPLÍCITOS
    // no lastUserMessage (não na resposta AI — evita falso positivo quando
    // a resposta menciona "dose pediátrica" como seção complementar).
    if (_detectPediatria(lastUserMessage.toLowerCase())) {
      final label = isEs ? '👶 Módulo pediatría' : '👶 Módulo pediatria';
      _log(lang: lang, tab: 'pediatria', extra: 'ctx=pediatric');
      return ExternalToolLink(
        label: label,
        url: _url(lang: lang, tab: 'pediatria'),
        calculatorContext: CalculatorContext.pediatric,
      );
    }

    // ── 10. Gestante / Obstetrícia ─────────────────────────────────────────
    if (_detectGestante(combined)) {
      final label = isEs ? '🤰 Módulo gestante' : '🤰 Módulo gestante';
      _log(lang: lang, tab: 'gestante', extra: 'ctx=dflt');
      return ExternalToolLink(
        label: label,
        url: _url(lang: lang, tab: 'gestante'),
        calculatorContext: CalculatorContext.dflt,
      );
    }

    // ── 11. Fármaco isolado via texto da última bolha AI ─────────────────
    // ORDEM 55 M2: LIBERAÇÃO ABSOLUTA DOS BOTÕES — texto da resposta AI é soberano.
    //
    // MICRO-BUILD 462E-A.4 — GOVERNANÇA PELO EMBARGO GATE:
    //   Este step somente é alcançado quando intent != ExternalToolIntent.none
    //   (i.e., o Total Embargo Gate no topo de build() foi aprovado).
    //   Caso contrário (intent == none), o retorno null no embargo gate acima
    //   impede que qualquer texto da IA seja processado — Step 11 incluído.
    //
    // REGRA Build 280 (mantida quando intent != none):
    //   • Detectamos o fármaco EXCLUSIVAMENTE no texto da última mensagem AI
    //     (lastAiResponse), NÃO no combined.
    //   • Se o fármaco aparece na bolha AI e intent != none → botão aparece.
    //   • Proteção anti-zombie implícita: step 8 já consumiu fármacos da user msg;
    //     step 11 só chega aqui para fármacos presentes na resposta AI.
    //
    // Exemplo com soberania ativa:
    //   Input: "analise o caso" → intent=none → embargo total → Step 11 NUNCA executa.
    //   Input: "qual a dose da noradrenalina?" → intent=dosage → Step 11 pode executar.
    final drug = _detectSingleDrug(lastAiResponse.toLowerCase());
    if (drug != null) {
      final drugCtx = _drugContext(drug.param);
      // ORDEM 29 V2: label contextual baseada no CalculatorContext do fármaco.
      final label = _buildDrugLabel(drug.display, drugCtx, isEs);
      // ignore: avoid_print
      print('[EXT_TOOL_CONTEXT][Build280] source=ai_response_text '
          'q=${drug.param} intent=${intent.name}');
      _log(lang: lang, tab: 'farmacos', extra: 'q=${drug.param} ctx=$drugCtx');
      return ExternalToolLink(
        label: label,
        url: _url(lang: lang, tab: 'farmacos', q: drug.param),
        calculatorContext: drugCtx,
      );
    }

    return null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // _resolveLang — BUILD 248: IDIOMA SOBERANO = currentLanguage (AppProvider.lang)
  //
  // O idioma do ExternalToolLink DEVE ser o idioma configurado no app,
  // não o idioma detectado no texto da pergunta ou resposta.
  //
  // currentLanguage vem de AppProvider.lang → sempre 'pt' ou 'es'.
  // Detecção de texto removida (BUILD 248) — violava Language Lock absoluto.
  //
  // Prioridade: currentLanguage ('pt'|'es') → fallback 'pt'
  // ───────────────────────────────────────────────────────────────────────────
  static String _resolveLang(
      String currentLanguage, String userMsg, String aiMsg) {
    final raw = currentLanguage.trim().toLowerCase();
    // 1. Explícito: aceita 'es', 'es-*', 'es_*'
    if (raw.startsWith('es')) return 'es';
    // 2. Explícito: aceita 'pt', 'pt-*', 'pt_*'
    if (raw.startsWith('pt')) return 'pt';
    // 3. BUILD 248: fallback seguro 'pt' — NÃO detectar idioma pelo texto.
    // currentLanguage deve sempre vir de AppProvider.lang.
    // Se chegar vazio aqui, é erro de chamada — mas nunca usamos texto como proxy.
    return 'pt';
  }
  // BUILD 248: _looksSpanish() removida — detecção de idioma pelo texto
  // violava o Language Lock absoluto (appLanguage é soberano).
  // Mantida abaixo apenas como tombstone para não quebrar git blame.
  // ignore: unused_element
  static bool _looksSpanish(String text) => false;

  // ───────────────────────────────────────────────────────────────────────────
  // _url — constrói URL com lang como PRIMEIRO param obrigatório
  // Formato: https://medcasescalcu.com/?lang=pt|es&tab=X[&q=Y | &extra]
  // ───────────────────────────────────────────────────────────────────────────
  static String _url({
    required String lang,
    required String tab,
    String? q,
    String? extra,
  }) {
    final buf = StringBuffer('$_kBase?lang=$lang&tab=$tab');
    if (q != null && q.isNotEmpty) buf.write('&q=${_enc(q)}');
    if (extra != null && extra.isNotEmpty) buf.write('&$extra');
    return buf.toString();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // _log — safe diagnostic log (nunca loga dados do paciente)
  // Formato: [EXT_TOOL][Build280] lang=pt tab=farmacos q=ceftriaxona ctx=drug
  // Build 280 (ORDEM 55 M2): LIBERAÇÃO ABSOLUTA — step 11 usa lastAiResponse only.
  // Build 270: ZOMBIE_AMIODARONA_EXTERMINATED — plantao_bypass_stale DELETED
  // ───────────────────────────────────────────────────────────────────────────
  // ignore: avoid_print
  static void _log({required String lang, required String tab, required String extra}) {
    // ignore: avoid_print
    print('[EXT_TOOL][Build280] lang=$lang tab=$tab${extra.isNotEmpty ? " $extra" : ""}');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // _calcContext — mapeia param de calculadora → CalculatorContext (Build 223)
  // Decisão determinística: nunca regex, nunca UI, nunca texto renderizado.
  // ───────────────────────────────────────────────────────────────────────────
  static CalculatorContext _calcContext(String param) {
    switch (param) {
      case 'clcr':
      case 'tfg':
      case 'dose-renal':      return CalculatorContext.clcr;
      case 'anion-gap':
      case 'be':
      case 'bicarbonato':
      case 'regra-de-22':     return CalculatorContext.acid_base;
      case 'imc':
      case 'peso-ideal':      return CalculatorContext.weight;
      case 'osmolaridade':
      case 'water-deficit':   return CalculatorContext.renal;
      case 'sodio-corrigido': return CalculatorContext.sodium;
      case 'calcio-corrigido': return CalculatorContext.calcium;
      default:                return CalculatorContext.dflt;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // _eletroliContext — mapeia param de eletrólito → CalculatorContext (Build 223)
  // ───────────────────────────────────────────────────────────────────────────
  static CalculatorContext _eletroliContext(String param) {
    switch (param) {
      case 'potassio':  return CalculatorContext.potassium;
      case 'sodio':     return CalculatorContext.sodium;
      case 'calcio':    return CalculatorContext.calcium;
      case 'magnesio':  return CalculatorContext.magnesium;
      case 'fosforo':   return CalculatorContext.phosphorus;
      case 'cloro':     return CalculatorContext.electrolytes;
      default:          return CalculatorContext.electrolytes;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // _drugContext — mapeia param de fármaco → CalculatorContext (Build 223)
  // Prioridade: fármaco específico (insulina/heparina/antibiótico/vasoativo) > drug
  // ───────────────────────────────────────────────────────────────────────────
  static CalculatorContext _drugContext(String param) {
    // Insulina / Glicose
    if (param == 'insulina' || param == 'metformina') {
      return CalculatorContext.glucose;
    }
    // Heparina / anticoagulação
    if (const [
      'heparina', 'rivaroxabana', 'apixabana', 'dabigatrana', 'warfarina',
    ].contains(param)) {
      return CalculatorContext.heparin;
    }
    // Antibióticos
    if (const [
      'ceftriaxona', 'piperacilina-tazobactam', 'meropenem', 'vancomicina',
      'ciprofloxacino', 'amoxicilina-clavulanato', 'azitromicina', 'metronidazol',
      'doxiciclina', 'cefazolina', 'fluconazol', 'anfotericina', 'linezolida',
      'colistina', 'levofloxacino', 'ertapenem', 'imipenem', 'rifampicina',
      'ceftazidima',
    ].contains(param)) {
      return CalculatorContext.antibiotics;
    }
    // Vasoativos / sedação EV
    if (const [
      'norepinefrina', 'dopamina', 'dobutamina', 'vasopressina',
      'nitroprussiato', 'nitroglicerina', 'adrenalina',
    ].contains(param)) {
      return CalculatorContext.vasoactive;
    }
    // Sedação/analgesia EV (sem tab infusao, mas contexto infusion)
    if (const [
      'midazolam', 'propofol', 'dexmedetomidina', 'fentanil',
      'ketamina', 'morfina',
    ].contains(param)) {
      return CalculatorContext.infusion;
    }
    // Geral
    return CalculatorContext.drug;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // _enc — URL encoding helper: technical term only, max 40 chars, lowercase
  // ───────────────────────────────────────────────────────────────────────────
  static String _enc(String term) {
    final safe = term.trim().toLowerCase().replaceAll(' ', '-');
    final capped = safe.length > 40 ? safe.substring(0, 40) : safe;
    return Uri.encodeQueryComponent(capped);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // _TermMatch — lightweight named pair for (param, display)
  // ───────────────────────────────────────────────────────────────────────────
  static _TermMatch? _matchFirst(String text, List<_TermMatch> table) {
    for (final entry in table) {
      for (final kw in entry.keywords) {
        if (text.contains(kw)) return entry;
      }
    }
    return null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DRUG INTERACTION — detects 2 drugs from combined text
  // ORDEM 29 V2: retorna (_TermMatch, _TermMatch)? para preservar .display
  // (nomes clínicos reais para labels dinâmicas — ex: "Sertralina", "Linezolida")
  // ───────────────────────────────────────────────────────────────────────────
  static (_TermMatch, _TermMatch)? _detectDrugInteraction(String text) {
    final List<_TermMatch> drugs = _kDrugs;
    final List<_TermMatch> found = [];
    for (final d in drugs) {
      for (final kw in d.keywords) {
        if (text.contains(kw)) {
          if (!found.any((f) => f.param == d.param)) found.add(d);
          break;
        }
      }
      if (found.length >= 2) break;
    }
    if (found.length >= 2) return (found[0], found[1]);
    return null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // _buildDrugLabel — ORDEM 29 V2: label contextual por CalculatorContext
  // Elimina o padrão genérico "💊 Abrir X na base" — cada contexto clínico
  // gera uma label com emoji e verbo de ação específico.
  // Determinístico: nunca regex, nunca network, nunca UI.
  // ───────────────────────────────────────────────────────────────────────────
  static String _buildDrugLabel(
      String display, CalculatorContext ctx, bool isEs) {
    switch (ctx) {
      case CalculatorContext.antibiotics:
        // Antibióticos → ajuste de dose renal é a ação clínica mais frequente
        return isEs
            ? '⚠️ Ajuste Renal: $display'
            : '⚠️ Ajuste Renal: $display';
      case CalculatorContext.vasoactive:
        // Vasoativos → titulação de dose em mcg/kg/min
        return isEs
            ? '📈 Titulación: $display'
            : '📈 Titulação: $display';
      case CalculatorContext.infusion:
        // Sedação/analgesia EV → cálculo de infusão contínua
        return isEs
            ? '💉 Infusión: $display'
            : '💉 Infusão: $display';
      case CalculatorContext.heparin:
        // Anticoagulantes → protocolo de anticoagulação
        return isEs
            ? '📋 Protocolo: $display'
            : '📋 Protocolo: $display';
      case CalculatorContext.glucose:
        // Insulina / Metformina → protocolo glicêmico
        return isEs
            ? '📋 Protocolo Glicêmico: $display'
            : '📋 Protocolo Glicêmico: $display';
      case CalculatorContext.drug:
      default:
        // Fármaco geral → acesso à base de dados clínica
        return isEs
            ? '💊 Base: $display'
            : '💊 Base: $display';
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SINGLE DRUG
  // ───────────────────────────────────────────────────────────────────────────
  static _TermMatch? _detectSingleDrug(String text) =>
      _matchFirst(text, _kDrugs);

  // ───────────────────────────────────────────────────────────────────────────
  // SCORES
  // ───────────────────────────────────────────────────────────────────────────
  static _TermMatch? _detectScore(String text) =>
      _matchFirst(text, _kScores);

  // ───────────────────────────────────────────────────────────────────────────
  // CALCULADORAS
  // ───────────────────────────────────────────────────────────────────────────
  static _TermMatch? _detectCalculadora(String text) =>
      _matchFirst(text, _kCalculadoras);

  // ───────────────────────────────────────────────────────────────────────────
  // ELETRÓLITOS
  // ───────────────────────────────────────────────────────────────────────────
  static _TermMatch? _detectEletrolito(String text) =>
      _matchFirst(text, _kEletrolitos);

  // ───────────────────────────────────────────────────────────────────────────
  // INFUSÃO
  // ───────────────────────────────────────────────────────────────────────────
  static _TermMatch? _detectInfusao(String text) =>
      _matchFirst(text, _kInfusao);

  // ───────────────────────────────────────────────────────────────────────────
  // HEMODINÂMICA
  // ───────────────────────────────────────────────────────────────────────────
  static _TermMatch? _detectHemodinamica(String text) =>
      _matchFirst(text, _kHemodinamica);

  // ───────────────────────────────────────────────────────────────────────────
  // FLUIDOS — keywords genéricos de reposição volêmica
  // ───────────────────────────────────────────────────────────────────────────
  static bool _detectFluidos(String text) {
    const kws = [
      'cristaloide', 'coloide', 'soro fisiol', 'solução salina',
      'reposição vol', 'reposição hídrica', 'expansão vol',
      'ringer lactato', 'albumina 4%', 'albumina 20%',
      'fluidoterapia', 'hidratação venosa', 'fluidoterapy',
      'bolus de soro', 'ressuscitação vol', 'resucitación vol',
      'balance hídrico', 'balanço hídrico', 'balanço hídrico',
    ];
    for (final kw in kws) {
      if (text.contains(kw)) return true;
    }
    return false;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PEDIATRIA — Build 188: exige termos pediátricos EXPLÍCITOS no texto do
  // usuário. Removido 'dose pediátrica' e 'laringite' (falsos positivos).
  // Esta função agora é chamada APENAS com lastUserMessage (não combined)
  // para evitar que a resposta AI contendo "dose pediátrica" como seção
  // complementar dispare o módulo pediatria indevidamente.
  // ───────────────────────────────────────────────────────────────────────────
  static bool _detectPediatria(String text) {
    const kws = [
      // Termos explicitamente pediátricos (sem ambiguidade)
      'pediatri',          // pediatria, pediátrico, pediatric
      'neonato', 'neonat', // neonato, neonatal
      'recém-nascido', 'recien nacido', 'recem-nascido',
      'lactente', 'lactant',
      'criança', 'crianca',
      'niño', 'niña', 'niños',
      'pediátric', 'pediatric',  // pediátrico, pediatrico
      'bronquiolit',             // bronquiolite — patologia pediátrica primária
      'croup', 'garrotillo',     // laringotraqueobronquite viral pediátrica
      'laringotraqueit',         // mais específico que 'laringite'
      'pals ',                   // pediatric advanced life support
      'peso em kg crianca', 'kg/dia crianca',
      'dose para crianca', 'dose para bebe',
      'dosis neonatal', 'dosis pediatrica',
      'dosis para nino', 'dosis en ninos',
    ];
    for (final kw in kws) {
      if (text.contains(kw)) return true;
    }
    return false;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // GESTANTE / OBSTETRÍCIA
  // ───────────────────────────────────────────────────────────────────────────
  static bool _detectGestante(String text) {
    const kws = [
      'gestante', 'gestação', 'gravidez', 'grávida',
      'embarazo', 'embarazada', 'gestación',
      'pré-eclâmpsia', 'preeclampsia', 'eclâmpsia', 'eclampsia',
      'hellp', 'pprom', 'rotura prematura', 'trabalho de parto',
      'parto prematuro', 'parto pretérmino', 'obstetri',
      'sulfato de magnésio', 'sulfato de magnesio',
      'betametasona gestante', 'corticoide fetal',
    ];
    for (final kw in kws) {
      if (text.contains(kw)) return true;
    }
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TermMatch — internal data class
// ─────────────────────────────────────────────────────────────────────────────
class _TermMatch {
  final String param;    // URL query value (lowercase, no accent)
  final String display;  // Human-readable button label segment
  final List<String> keywords; // All trigger substrings (lowercase)

  const _TermMatch({
    required this.param,
    required this.display,
    required this.keywords,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// KNOWLEDGE TABLES — curated, exhaustive, deterministic
// ═════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
// DRUGS — ordered by clinical frequency in ER/ICU/Ward
// Each entry: param (URL slug) · display (label) · keywords (trigger list)
// ─────────────────────────────────────────────────────────────────────────────
const List<_TermMatch> _kDrugs = [
  // Antibióticos
  _TermMatch(param: 'ceftriaxona', display: 'Ceftriaxona',
      keywords: ['ceftriaxona', 'ceftriaxone', 'rocefin']),
  _TermMatch(param: 'piperacilina-tazobactam', display: 'Pip-Tazo',
      keywords: ['piperacilina', 'piperacillin', 'tazobactam', 'pip-tazo', 'tazocin']),
  _TermMatch(param: 'meropenem', display: 'Meropenem',
      keywords: ['meropenem', 'meronem']),
  _TermMatch(param: 'vancomicina', display: 'Vancomicina',
      keywords: ['vancomicina', 'vancomycin', 'vancocin']),
  _TermMatch(param: 'ciprofloxacino', display: 'Ciprofloxacino',
      keywords: ['ciprofloxacino', 'ciprofloxacin', 'cipro']),
  _TermMatch(param: 'amoxicilina-clavulanato', display: 'Amoxicilina-Clavulanato',
      keywords: ['amoxicilina-clavulan', 'amoxicillin-clav', 'clavulanato', 'augmentin']),
  _TermMatch(param: 'azitromicina', display: 'Azitromicina',
      keywords: ['azitromicina', 'azithromycin', 'zitromax']),
  _TermMatch(param: 'metronidazol', display: 'Metronidazol',
      keywords: ['metronidazol', 'metronidazole', 'flagyl']),
  _TermMatch(param: 'doxiciclina', display: 'Doxiciclina',
      keywords: ['doxiciclina', 'doxycycline']),
  _TermMatch(param: 'cefazolina', display: 'Cefazolina',
      keywords: ['cefazolina', 'cefazolin']),
  _TermMatch(param: 'fluconazol', display: 'Fluconazol',
      keywords: ['fluconazol', 'fluconazole', 'diflucan']),
  _TermMatch(param: 'anfotericina', display: 'Anfotericina',
      keywords: ['anfotericina', 'amphotericin']),
  _TermMatch(param: 'linezolida', display: 'Linezolida',
      keywords: ['linezolida', 'linezolid', 'zyvox']),
  _TermMatch(param: 'colistina', display: 'Colistina',
      keywords: ['colistina', 'colistin', 'polimixina']),
  _TermMatch(param: 'levofloxacino', display: 'Levofloxacino',
      keywords: ['levofloxacino', 'levofloxacin', 'tavanic']),
  _TermMatch(param: 'ertapenem', display: 'Ertapenem',
      keywords: ['ertapenem', 'invanz']),
  _TermMatch(param: 'imipenem', display: 'Imipenem',
      keywords: ['imipenem', 'cilastatin']),
  _TermMatch(param: 'rifampicina', display: 'Rifampicina',
      keywords: ['rifampicina', 'rifampin', 'rifampicin']),
  _TermMatch(param: 'ceftazidima', display: 'Ceftazidima',
      keywords: ['ceftazidima', 'ceftazidime', 'fortaz']),

  // Cardiovasculares / Vasoativos (sem ser infusão dedicada)
  _TermMatch(param: 'amiodarona', display: 'Amiodarona',
      keywords: ['amiodarona', 'amiodarone', 'cordarone']),
  _TermMatch(param: 'adenosina', display: 'Adenosina',
      keywords: ['adenosina', 'adenosine']),
  _TermMatch(param: 'atropina', display: 'Atropina',
      keywords: ['atropina', 'atropine']),
  _TermMatch(param: 'lidocaina', display: 'Lidocaína',
      keywords: ['lidocaína', 'lidocaina', 'lidocaine', 'xilocaína']),
  _TermMatch(param: 'metoprolol', display: 'Metoprolol',
      keywords: ['metoprolol', 'seloken']),
  _TermMatch(param: 'carvedilol', display: 'Carvedilol',
      keywords: ['carvedilol']),
  _TermMatch(param: 'atenolol', display: 'Atenolol',
      keywords: ['atenolol']),
  _TermMatch(param: 'enalapril', display: 'Enalapril',
      keywords: ['enalapril', 'vasotec']),
  _TermMatch(param: 'ramipril', display: 'Ramipril',
      keywords: ['ramipril', 'triatec']),
  _TermMatch(param: 'losartana', display: 'Losartana',
      keywords: ['losartana', 'losartan', 'cozaar']),
  _TermMatch(param: 'anlodipino', display: 'Anlodipino',
      keywords: ['anlodipino', 'amlodipine', 'amlodipino', 'norvasc']),
  _TermMatch(param: 'digoxina', display: 'Digoxina',
      keywords: ['digoxina', 'digoxin', 'lanoxin']),
  _TermMatch(param: 'furosemida', display: 'Furosemida',
      keywords: ['furosemida', 'furosemide', 'lasix']),
  _TermMatch(param: 'espironolactona', display: 'Espironolactona',
      keywords: ['espironolactona', 'spironolactone', 'aldactone']),
  _TermMatch(param: 'nitroprussiato', display: 'Nitroprussiato',
      keywords: ['nitroprussiato', 'nitroprusside', 'nipride']),
  _TermMatch(param: 'nitroglicerina', display: 'Nitroglicerina',
      keywords: ['nitroglicerina', 'nitroglycerin', 'tridil']),
  _TermMatch(param: 'captopril', display: 'Captopril',
      keywords: ['captopril', 'capoten']),

  // Anticoagulantes / Antiagregantes
  _TermMatch(param: 'heparina', display: 'Heparina',
      keywords: ['heparina', 'heparin', 'hbpm', 'enoxaparina', 'enoxaparin']),
  _TermMatch(param: 'rivaroxabana', display: 'Rivaroxabana',
      keywords: ['rivaroxabana', 'rivaroxaban', 'xarelto']),
  _TermMatch(param: 'apixabana', display: 'Apixabana',
      keywords: ['apixabana', 'apixaban', 'eliquis']),
  _TermMatch(param: 'dabigatrana', display: 'Dabigatrana',
      keywords: ['dabigatrana', 'dabigatran', 'pradaxa']),
  _TermMatch(param: 'warfarina', display: 'Warfarina',
      keywords: ['warfarina', 'warfarin', 'coumadin']),
  _TermMatch(param: 'ticagrelor', display: 'Ticagrelor',
      keywords: ['ticagrelor', 'brilinta']),
  _TermMatch(param: 'clopidogrel', display: 'Clopidogrel',
      keywords: ['clopidogrel', 'plavix']),
  _TermMatch(param: 'aas', display: 'AAS',
      keywords: ['ácido acetilsalicílico', 'aspirina', ' aas ', 'aspirin']),

  // Neurologia / Psiquiatria — anticonvulsivantes
  _TermMatch(param: 'fenitoina', display: 'Fenitoína',
      keywords: ['fenitoína', 'fenitoina', 'phenytoin', 'dilantin']),
  _TermMatch(param: 'valproato', display: 'Valproato',
      keywords: ['valproato', 'valproic', 'depakene', 'depakote']),
  _TermMatch(param: 'levetiracetam', display: 'Levetiracetam',
      keywords: ['levetiracetam', 'keppra']),
  _TermMatch(param: 'carbamazepina', display: 'Carbamazepina',
      keywords: ['carbamazepina', 'carbamazepine', 'tegretol']),
  _TermMatch(param: 'lamotrigina', display: 'Lamotrigina',
      keywords: ['lamotrigina', 'lamotrigine', 'lamictal']),
  _TermMatch(param: 'clonazepam', display: 'Clonazepam',
      keywords: ['clonazepam', 'rivotril']),
  // Ansiolíticos / Hipnóticos / Sedativos
  _TermMatch(param: 'midazolam', display: 'Midazolam',
      keywords: ['midazolam', 'dormicum', 'versed']),
  _TermMatch(param: 'diazepam', display: 'Diazepam',
      keywords: ['diazepam', 'valium']),
  _TermMatch(param: 'lorazepam', display: 'Lorazepam',
      keywords: ['lorazepam', 'ativan']),
  _TermMatch(param: 'alprazolam', display: 'Alprazolam',
      keywords: ['alprazolam', 'xanax']),
  // Antipsicóticos
  _TermMatch(param: 'haloperidol', display: 'Haloperidol',
      keywords: ['haloperidol', 'haldol']),
  _TermMatch(param: 'quetiapina', display: 'Quetiapina',
      keywords: ['quetiapina', 'quetiapine', 'seroquel']),
  _TermMatch(param: 'olanzapina', display: 'Olanzapina',
      keywords: ['olanzapina', 'olanzapine', 'zyprexa']),
  _TermMatch(param: 'risperidona', display: 'Risperidona',
      keywords: ['risperidona', 'risperidone', 'risperdal']),
  _TermMatch(param: 'aripiprazol', display: 'Aripiprazol',
      keywords: ['aripiprazol', 'aripiprazole', 'abilify']),
  _TermMatch(param: 'clozapina', display: 'Clozapina',
      keywords: ['clozapina', 'clozapine', 'clozaril']),
  // BUILD 270: SSRI / SNRI / Antidepressivos — ausentes anteriormente causavam
  // que queries (ex: "sertralina") não fossem capturadas em step 8,
  // fazendo step 11 pegar amiodarona da resposta AI (zombie injection).
  _TermMatch(param: 'sertralina', display: 'Sertralina',
      keywords: ['sertralina', 'sertraline', 'zoloft']),
  _TermMatch(param: 'fluoxetina', display: 'Fluoxetina',
      keywords: ['fluoxetina', 'fluoxetine', 'prozac']),
  _TermMatch(param: 'escitalopram', display: 'Escitalopram',
      keywords: ['escitalopram', 'lexapro', 'cipralex']),
  _TermMatch(param: 'citalopram', display: 'Citalopram',
      keywords: ['citalopram', 'celexa']),
  _TermMatch(param: 'paroxetina', display: 'Paroxetina',
      keywords: ['paroxetina', 'paroxetine', 'paxil', 'aropax']),
  _TermMatch(param: 'venlafaxina', display: 'Venlafaxina',
      keywords: ['venlafaxina', 'venlafaxine', 'effexor']),
  _TermMatch(param: 'duloxetina', display: 'Duloxetina',
      keywords: ['duloxetina', 'duloxetine', 'cymbalta']),
  _TermMatch(param: 'mirtazapina', display: 'Mirtazapina',
      keywords: ['mirtazapina', 'mirtazapine', 'remeron']),
  _TermMatch(param: 'bupropiona', display: 'Bupropiona',
      keywords: ['bupropiona', 'bupropion', 'wellbutrin', 'zyban']),
  _TermMatch(param: 'amitriptilina', display: 'Amitriptilina',
      keywords: ['amitriptilina', 'amitriptyline', 'tryptanol']),
  _TermMatch(param: 'nortriptilina', display: 'Nortriptilina',
      keywords: ['nortriptilina', 'nortriptyline', 'pamelor']),
  _TermMatch(param: 'clomipramina', display: 'Clomipramina',
      keywords: ['clomipramina', 'clomipramine', 'anafranil']),
  _TermMatch(param: 'trazodona', display: 'Trazodona',
      keywords: ['trazodona', 'trazodone', 'desyrel']),
  _TermMatch(param: 'desvenlafaxina', display: 'Desvenlafaxina',
      keywords: ['desvenlafaxina', 'desvenlafaxine', 'pristiq']),
  _TermMatch(param: 'lítio', display: 'Lítio',
      keywords: ['lítio', 'litio', 'lithium', 'carbolithium']),

  // Analgesia / Sedação
  _TermMatch(param: 'morfina', display: 'Morfina',
      keywords: ['morfina', 'morphine']),
  _TermMatch(param: 'fentanil', display: 'Fentanil',
      keywords: ['fentanil', 'fentanyl', 'duragesic']),
  _TermMatch(param: 'ketamina', display: 'Ketamina',
      keywords: ['ketamina', 'ketamine', 'cetamina']),
  _TermMatch(param: 'propofol', display: 'Propofol',
      keywords: ['propofol', 'diprivan']),
  _TermMatch(param: 'dexmedetomidina', display: 'Dexmedetomidina',
      keywords: ['dexmedetomidina', 'dexmedetomidine', 'precedex']),
  _TermMatch(param: 'tramadol', display: 'Tramadol',
      keywords: ['tramadol', 'tramal', 'ultram']),

  // Endócrino / Metabólico
  _TermMatch(param: 'insulina', display: 'Insulina',
      keywords: ['insulina', 'insulin']),
  _TermMatch(param: 'metformina', display: 'Metformina',
      keywords: ['metformina', 'metformin', 'glifage']),
  _TermMatch(param: 'hidrocortisona', display: 'Hidrocortisona',
      keywords: ['hidrocortisona', 'hydrocortisone', 'solu-cortef']),
  _TermMatch(param: 'dexametasona', display: 'Dexametasona',
      keywords: ['dexametasona', 'dexamethasone', 'decadron']),
  _TermMatch(param: 'metilprednisolona', display: 'Metilprednisolona',
      keywords: ['metilprednisolona', 'methylprednisolone', 'solu-medrol']),
  _TermMatch(param: 'levotiroxina', display: 'Levotiroxina',
      keywords: ['levotiroxina', 'levothyroxine', 'synthroid']),

  // Respiratório / Broncodilatadores
  _TermMatch(param: 'salbutamol', display: 'Salbutamol',
      keywords: ['salbutamol', 'albuterol', 'ventolin', 'fenoterol']),
  _TermMatch(param: 'ipratropio', display: 'Ipratrópio',
      keywords: ['ipratropio', 'ipratropium', 'atrovent']),
  _TermMatch(param: 'aminofilina', display: 'Aminofilina',
      keywords: ['aminofilina', 'aminophylline']),
  _TermMatch(param: 'adrenalina', display: 'Adrenalina',
      keywords: ['adrenalina', 'epinefrina', 'epinephrine', 'adrenaline']),

  // Outros frequentes
  _TermMatch(param: 'ranitidina', display: 'Ranitidina',
      keywords: ['ranitidina', 'ranitidine', 'zantac']),
  _TermMatch(param: 'omeprazol', display: 'Omeprazol',
      keywords: ['omeprazol', 'omeprazole', 'prilosec']),
  _TermMatch(param: 'pantoprazol', display: 'Pantoprazol',
      keywords: ['pantoprazol', 'pantoprazole', 'protonix']),
  _TermMatch(param: 'ondansetrona', display: 'Ondansetrona',
      keywords: ['ondansetrona', 'ondansetron', 'zofran']),
  _TermMatch(param: 'metoclopramida', display: 'Metoclopramida',
      keywords: ['metoclopramida', 'metoclopramide', 'plasil']),
  _TermMatch(param: 'dipirona', display: 'Dipirona',
      keywords: ['dipirona', 'metamizol', 'novalgina']),
  _TermMatch(param: 'paracetamol', display: 'Paracetamol',
      keywords: ['paracetamol', 'acetaminophen', 'tylenol']),
  _TermMatch(param: 'ibuprofeno', display: 'Ibuprofeno',
      keywords: ['ibuprofeno', 'ibuprofen', 'advil']),
  _TermMatch(param: 'diclofenaco', display: 'Diclofenaco',
      keywords: ['diclofenaco', 'diclofenac', 'cataflam']),
  _TermMatch(param: 'n-acetilcisteina', display: 'N-Acetilcisteína',
      keywords: ['n-acetilcisteína', 'acetilcisteína', 'acetylcysteine', 'nac antídoto']),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCORES clínicos
// ─────────────────────────────────────────────────────────────────────────────
const List<_TermMatch> _kScores = [
  _TermMatch(param: 'sofa', display: 'SOFA',
      keywords: ['sofa score', 'escore sofa', 'sequential organ', 'sofa:']),
  _TermMatch(param: 'qsofa', display: 'qSOFA',
      keywords: ['qsofa', 'quick sofa']),
  _TermMatch(param: 'apache', display: 'APACHE II',
      keywords: ['apache ii', 'apache 2', 'apache score']),
  _TermMatch(param: 'saps', display: 'SAPS',
      keywords: ['saps ii', 'saps iii', 'saps score']),
  _TermMatch(param: 'wells-tep', display: 'Wells TEP',
      keywords: ['wells tep', 'wells tromboembolism', 'wells pulmonar', 'escore de wells', 'score de wells']),
  _TermMatch(param: 'wells-tvp', display: 'Wells TVP',
      keywords: ['wells tvp', 'wells tvd', 'wells trombose venosa']),
  _TermMatch(param: 'grace', display: 'GRACE',
      keywords: ['grace score', 'escore grace', 'grace acs']),
  _TermMatch(param: 'timi', display: 'TIMI',
      keywords: ['timi score', 'escore timi', 'timi risk']),
  _TermMatch(param: 'heart', display: 'HEART Score',
      keywords: ['heart score', 'escore heart']),
  _TermMatch(param: 'glasgow', display: 'Glasgow',
      keywords: ['glasgow', 'gcs ', 'gcs score', 'escala de glasgow', 'escala glasgow']),
  _TermMatch(param: 'nihss', display: 'NIHSS',
      keywords: ['nihss', 'nih stroke scale', 'escore nihss']),
  _TermMatch(param: 'rankin', display: 'Rankin',
      keywords: ['rankin', 'modified rankin', 'escala rankin']),
  _TermMatch(param: 'hunt-hess', display: 'Hunt-Hess',
      keywords: ['hunt-hess', 'hunt e hess', 'hunt hess']),
  _TermMatch(param: 'curb-65', display: 'CURB-65',
      keywords: ['curb-65', 'curb65', 'escore curb']),
  _TermMatch(param: 'psi-port', display: 'PSI/PORT',
      keywords: ['psi score', 'port score', 'pneumonia severity']),
  _TermMatch(param: 'ranson', display: 'Ranson',
      keywords: ['ranson', 'criterios de ranson', 'critérios de ranson']),
  _TermMatch(param: 'bisap', display: 'BISAP',
      keywords: ['bisap']),
  _TermMatch(param: 'meld', display: 'MELD',
      keywords: ['meld', 'meld score', 'meld-na']),
  _TermMatch(param: 'child-pugh', display: 'Child-Pugh',
      keywords: ['child-pugh', 'child pugh', 'child turcotte']),
  _TermMatch(param: 'chads2-vasc', display: 'CHA₂DS₂-VASc',
      keywords: ['chads2', 'cha2ds2', 'chadsvasc', 'escore de chads']),
  _TermMatch(param: 'has-bled', display: 'HAS-BLED',
      keywords: ['has-bled', 'hasbled', 'escore has-bled']),
  _TermMatch(param: 'trauma-score', display: 'Trauma Score',
      keywords: ['revised trauma score', 'iss score', 'injury severity']),
  _TermMatch(param: 'abcd2', display: 'ABCD²',
      keywords: ['abcd2', 'escore abcd']),
  _TermMatch(param: 'pecarn', display: 'PECARN',
      keywords: ['pecarn']),
  _TermMatch(param: 'sepsis-3', display: 'Sepsis-3',
      keywords: ['sepsis-3', 'sepse-3', 'critérios sepsis 3']),
];

// ─────────────────────────────────────────────────────────────────────────────
// CALCULADORAS clínicas
// ─────────────────────────────────────────────────────────────────────────────
const List<_TermMatch> _kCalculadoras = [
  _TermMatch(param: 'clcr', display: 'ClCr (Cockcroft-Gault)',
      keywords: ['clcr', 'clearance de creatinina', 'cockcroft', 'creatinine clearance',
                 'depuração de creatinina', 'depuracion creatinina']),
  _TermMatch(param: 'tfg', display: 'TFG (CKD-EPI)',
      keywords: ['tfg', 'taxa de filtração glomerular', 'ckd-epi', 'egfr', 'filtrado glomerular']),
  _TermMatch(param: 'imc', display: 'IMC',
      keywords: ['imc', 'índice de massa corporal', 'índice de masa corporal', 'bmi']),
  _TermMatch(param: 'peso-ideal', display: 'Peso Ideal',
      keywords: ['peso ideal', 'peso magro', 'peso corrigido', 'ideal body weight']),
  _TermMatch(param: 'dose-renal', display: 'Ajuste Renal',
      keywords: ['ajuste renal', 'ajuste de dose renal', 'insuficiência renal dose',
                 'dose em insuficiência renal']),
  _TermMatch(param: 'osmolaridade', display: 'Osmolaridade',
      keywords: ['osmolaridade', 'osmolalidade', 'osmolarity', 'gap osmolar']),
  _TermMatch(param: 'anion-gap', display: 'Ânion Gap',
      keywords: ['ânion gap', 'anion gap', 'gap aniônico', 'delta ratio']),
  _TermMatch(param: 'be', display: 'Base Excess',
      keywords: ['base excess', 'excesso de base', 'déficit de base']),
  _TermMatch(param: 'bicarbonato', display: 'Bicarbonato',
      keywords: ['repor bicarbonato', 'reposição de bicarbonato', 'bicarbonate deficit']),
  _TermMatch(param: 'sodio-corrigido', display: 'Na⁺ Corrigido',
      keywords: ['sódio corrigido', 'sodio corregido', 'na+ corrigido', 'natremia corrigida']),
  _TermMatch(param: 'calcio-corrigido', display: 'Ca²⁺ Corrigido',
      keywords: ['cálcio corrigido', 'calcio corregido', 'ca2+ corrigido']),
  _TermMatch(param: 'regra-de-22', display: 'Regra de 22',
      keywords: ['regra de 22', 'regra dos 22', 'compensação respiratória']),
  _TermMatch(param: 'water-deficit', display: 'Déficit Hídrico',
      keywords: ['déficit hídrico', 'water deficit', 'deficit de agua libre']),
];

// ─────────────────────────────────────────────────────────────────────────────
// ELETRÓLITOS
// ─────────────────────────────────────────────────────────────────────────────
const List<_TermMatch> _kEletrolitos = [
  _TermMatch(param: 'potassio', display: 'Potássio',
      keywords: ['hipocalemia', 'hipercalemia', 'hypokale', 'hyperkale',
                 'potássio', 'potasio', 'kalemia', 'k+', 'reposição de potássio']),
  _TermMatch(param: 'sodio', display: 'Sódio',
      keywords: ['hiponatremia', 'hipernatremia', 'hyponatremia', 'hypernatremia',
                 'sódio', 'sodio', 'natremia', 'disnatremia', 'correção de sódio']),
  _TermMatch(param: 'calcio', display: 'Cálcio',
      keywords: ['hipocalcemia', 'hipercalcemia', 'hypocalcemia', 'hypercalcemia',
                 'cálcio', 'calcio', 'calciemia']),
  _TermMatch(param: 'magnesio', display: 'Magnésio',
      keywords: ['hipomagnesemia', 'hipermagnesemia', 'hypomagnesemia',
                 'magnésio', 'magnesio', 'magnesemia', 'mg2+']),
  _TermMatch(param: 'fosforo', display: 'Fósforo',
      keywords: ['hipofosfatemia', 'hiperfosfatemia', 'hypophosphatemia',
                 'fósforo', 'fosforo', 'fosfatemia']),
  _TermMatch(param: 'cloro', display: 'Cloro',
      keywords: ['hipocloremia', 'hipercloremia', 'cloro', 'cloremia', 'cloreto']),
];

// ─────────────────────────────────────────────────────────────────────────────
// INFUSÃO contínua / Drogas vasoativas e sedação
// ─────────────────────────────────────────────────────────────────────────────
const List<_TermMatch> _kInfusao = [
  _TermMatch(param: 'norepinefrina', display: 'Norepinefrina',
      keywords: ['norepinefrina', 'noradrenalin', 'norepinephrine', 'noradrenalina', 'levophed']),
  _TermMatch(param: 'dopamina', display: 'Dopamina',
      keywords: ['dopamina', 'dopamine']),
  _TermMatch(param: 'dobutamina', display: 'Dobutamina',
      keywords: ['dobutamina', 'dobutamine', 'dobutrex']),
  _TermMatch(param: 'vasopressina', display: 'Vasopressina',
      keywords: ['vasopressina', 'vasopressin', 'pitressin']),
  _TermMatch(param: 'epinefrina-infusao', display: 'Epinefrina (infusão)',
      keywords: ['epinefrina infusão', 'adrenalina infusão', 'epinephrine infusion']),
  _TermMatch(param: 'midazolam-infusao', display: 'Midazolam (infusão)',
      keywords: ['midazolam infusão', 'midazolam contínuo', 'midazolam drip']),
  _TermMatch(param: 'propofol-infusao', display: 'Propofol (infusão)',
      keywords: ['propofol infusão', 'propofol contínuo', 'propofol drip']),
  _TermMatch(param: 'fentanil-infusao', display: 'Fentanil (infusão)',
      keywords: ['fentanil infusão', 'fentanil contínuo', 'fentanyl drip']),
  _TermMatch(param: 'amiodarona-infusao', display: 'Amiodarona (infusão)',
      keywords: ['amiodarona infusão', 'amiodarone infusion', 'amiodarona ev contínuo']),
  _TermMatch(param: 'heparina-infusao', display: 'Heparina (infusão)',
      keywords: ['heparina infusão', 'heparina contínua', 'heparin infusion', 'heparina ev']),
  _TermMatch(param: 'insulina-infusao', display: 'Insulina (infusão)',
      keywords: ['insulina infusão', 'insulina contínua', 'insulin drip', 'protocolo insulina']),
  _TermMatch(param: 'nitroprussiato-infusao', display: 'Nitroprussiato (infusão)',
      keywords: ['nitroprussiato infusão', 'nitroprussiato ev', 'nitroprusside infusion']),
  _TermMatch(param: 'nitroglicerina-infusao', display: 'Nitroglicerina (infusão)',
      keywords: ['nitroglicerina infusão', 'nitroglicerina ev', 'nitroglycerin drip']),
  _TermMatch(param: 'ketamina-infusao', display: 'Ketamina (infusão)',
      keywords: ['ketamina infusão', 'ketamina contínua', 'ketamine drip']),
  _TermMatch(param: 'dexmedetomidina-infusao', display: 'Dexmedetomidina (infusão)',
      keywords: ['dexmedetomidina infusão', 'precedex infusão', 'dexmedetomidine infusion']),
];

// ─────────────────────────────────────────────────────────────────────────────
// HEMODINÂMICA
// ─────────────────────────────────────────────────────────────────────────────
const List<_TermMatch> _kHemodinamica = [
  _TermMatch(param: 'pam', display: 'PAM',
      keywords: ['pressão arterial média', 'pam ', 'mean arterial pressure', 'map ']),
  _TermMatch(param: 'fc', display: 'Frequência Cardíaca',
      keywords: ['frequência cardíaca', 'frecuencia cardiaca', 'heart rate', 'fc ']),
  _TermMatch(param: 'dc', display: 'Débito Cardíaco',
      keywords: ['débito cardíaco', 'gasto cardíaco', 'cardiac output', 'dc ']),
  _TermMatch(param: 'svr', display: 'RVS',
      keywords: ['resistência vascular sistêmica', 'rvs', 'svr', 'systemic vascular resistance']),
  _TermMatch(param: 'pvr', display: 'RVP',
      keywords: ['resistência vascular pulmonar', 'rvp', 'pvr', 'pulmonary vascular resistance']),
  _TermMatch(param: 'vpp', display: 'VPP',
      keywords: ['variação de pressão de pulso', 'vpp ', 'pulse pressure variation', 'ppv']),
  _TermMatch(param: 'pvci', display: 'VCI / PVC',
      keywords: ['veia cava inferior', 'pressão venosa central', 'pvc ', 'cvp ', 'vci ', 'ivc ']),
  _TermMatch(param: 'shock-index', display: 'Índice de Choque',
      keywords: ['índice de choque', 'shock index', 'indice de choque']),
  _TermMatch(param: 'svo2', display: 'SvO₂',
      keywords: ['svo2', 'saturação venosa', 'satvenosa', 'mixed venous']),
  _TermMatch(param: 'lactato', display: 'Lactato',
      keywords: ['lactato', 'lactat', 'lactatemia', 'lactic acid']),
];
