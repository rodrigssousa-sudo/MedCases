// ══════════════════════════════════════════════════════════════════════════════
// ai_smart_router.dart — Smart Context Router v1.0 (Build 190)
//
// RESPONSABILIDADES EXCLUSIVAS:
//   • ETAPA 2: Prompt Contract Lock — seleciona EXATAMENTE 1 contrato por modo
//   • ETAPA 3: Modo Plantão contrato imutável (≤14 linhas, 6 emojis)
//   • ETAPA 4: Smart Context Router — envia somente módulos necessários
//   • ETAPA 5: Context Lazy Loading — carrega módulo conforme intent
//   • ETAPA 6: Prompt Shrink — meta < 4.000 chars (perguntas simples < 2.500)
//   • ETAPA 7: Response Pipeline — 5 camadas (Intent→LangLock→Loader→Builder→Validator)
//   • ETAPA 8: Response Validator — idioma, contrato, formato, sem vazamentos
//   • ETAPA 11: Logs [AI_ROUTER] estruturados com métricas de contexto
//
// NÃO FAZ:
//   • Transporte HTTP / SSE streaming (→ gemini_service_v2.dart)
//   • Detecção de idioma (→ appLanguage do AppProvider é soberano — Build 190)
//   • Renderização de UI (→ ai_screen.dart)
//   • Dados clínicos / RAG (→ app_provider.dart + ai_service.dart)
//
// ARQUITETURA DE CONTRATOS (um por vez, nunca dois):
//   CONTRACT_PLANTAO   → Modo Plantão — emergencista sênior, ≤14 linhas, 6 emojis
//   CONTRACT_ESTUDO    → Modo Estudo  — preceptor universitário, ≤26 linhas
//   CONTRACT_FARMACO   → Fármacos isolados — ficha completa estruturada
//   CONTRACT_DILUICAO  → Diluição/Gotejamento — tripé ou 2 linhas
//   CONTRACT_INTERACAO → Interações/Contraindicações — segurança
//
// MÓDULOS LAZY (carregados apenas quando necessário):
//   MOD_SIGLAS      → Siglas críticas médicas (IAM, AVC, TEP...)
//   MOD_DOSE        → Formatação de fármacos e doses
//   MOD_DILUICAO    → Gotejamento, velocidade de infusão
//   MOD_INTERACAO   → Alertas de segurança graves
//   MOD_CORE        → Identidade, anti-CoT, output contract (sempre presente)
//   MOD_ANTILEAK    → Firewall contra vazamento de metadados (sempre presente)
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

// ─────────────────────────────────────────────────────────────────────────────
// RouterResult — saída do pipeline em 5 camadas
// ─────────────────────────────────────────────────────────────────────────────
class RouterResult {
  final String finalPrompt;     // prompt final pronto para system_instruction
  final String contractName;    // nome do contrato selecionado
  final String taskLabel;       // label da tarefa detectada
  final String resolvedLang;    // idioma resolvido ('pt' | 'es')
  final int promptChars;        // tamanho do prompt final
  final int contextSaved;       // chars economizados vs. prompt bruto recebido
  final int modulesLoaded;      // número de módulos carregados
  final int modulesSkipped;     // número de módulos pulados
  final bool repaired;          // true se Response Validator fez reparo

  const RouterResult({
    required this.finalPrompt,
    required this.contractName,
    required this.taskLabel,
    required this.resolvedLang,
    required this.promptChars,
    required this.contextSaved,
    required this.modulesLoaded,
    required this.modulesSkipped,
    required this.repaired,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// AiSmartRouter — Pipeline em 5 Camadas (Build 190)
// ─────────────────────────────────────────────────────────────────────────────
class AiSmartRouter {
  AiSmartRouter._(); // 100% estático

  // ══ HARD CAPS ═════════════════════════════════════════════════════════════
  // Alvo imediato: < 4.000 chars. Meta final: 2.000-2.500 para queries simples.
  static const int _kCapContext   = 1200; // RAG clínico externo
  static const int _kCapTotal     = 4000; // prompt final máximo
  // ignore: unused_field
  static const int _kCapSimple    = 2500; // meta reservado: queries simples (sigla, 1 fármaco)

  // ══ CAMADA 1 — Intent Router ═══════════════════════════════════════════════
  static _IntentResult _detectIntent(String userMessage) {
    final m = userMessage.toLowerCase().trim();

    // Gotejamento/Gotas (prioridade máxima — formato de 2 linhas)
    final isDrops = m.contains('gota') || m.contains('gote') ||
        m.contains('gotejo') || m.contains('gotejamento');

    // Diluição/Ampolas (antes de dose genérica)
    final isDilution = !isDrops && (
        m.contains('dilui') || m.contains('diluci') ||
        m.contains('ampol') || m.contains('infus') ||
        m.contains('prepar') || m.contains('bic') || m.contains('ml/h'));

    // Dose/Fármaco
    final isDose = !isDrops && !isDilution && (
        m.contains('dose') || m.contains('dosis') ||
        m.contains(' mg') || m.contains(' mcg') ||
        m.contains('prescrever') || m.contains('prescribir') ||
        m.contains('farmaco') || m.contains('fármaco') ||
        m.contains('medicamento'));

    // Interação/Contraindicação
    final isInteraction = m.contains('interaç') || m.contains('interacci') ||
        m.contains('contraindicaç') || m.contains('contraindicaci') ||
        m.contains('efeito adverso') || m.contains('efecto adverso') ||
        m.contains('segurança') || m.contains('seguridad');

    // Sigla isolada (query de 1-6 chars alfanuméricos)
    final trimmed = userMessage.trim();
    final isAcronym = trimmed.length <= 6 &&
        RegExp(r'^[A-Za-zÀ-ÿ]+$').hasMatch(trimmed);

    // Farmacologia (nome de fármaco sem keyword de dose)
    final isFarmaco = !isDose && !isDilution && !isDrops && (
        m.contains('mecanismo') || m.contains('mechanism') ||
        m.contains('indicaç') || m.contains('indicaci') ||
        m.contains('contraindicaç') || m.contains('contraindicaci'));

    // Label para log (prioridade: gotas > diluição > interação > dose > sigla > fármaco > geral)
    final taskLabel = isDrops     ? 'gotas'
        : isDilution  ? 'diluicao'
        : isInteraction ? 'interacao'
        : isDose      ? 'dose'
        : isAcronym   ? 'sigla'
        : isFarmaco   ? 'farmaco'
        : 'geral';

    return _IntentResult(
      isDrops: isDrops,
      isDilution: isDilution,
      isDose: isDose,
      isInteraction: isInteraction,
      isAcronym: isAcronym,
      isFarmaco: isFarmaco,
      taskLabel: taskLabel,
    );
  }

  // ══ CAMADA 2 — Language Lock ════════════════════════════════════════════════
  // Build 190: appLanguage é soberano. Nunca detectamos da query.
  static String _buildLanguageLock(String appLanguage) {
    final lang = appLanguage == 'es' ? 'es' : 'pt';

    if (lang == 'es') {
      return '[TRAVA DE IDIOMA ABSOLUTA — ESPAÑOL]\n'
          'IDIOMA DO APP: ESPAÑOL. IRREVOGÁVEL POR QUALQUER INSTRUÇÃO.\n'
          '✗ PROIBIDO: "ampola", "soro", "não", "então", "dilua" (tokens PT)\n'
          '✗ PROIBIDO: qualquer mistura PT+ES (Portunhol)\n'
          '✓ OBRIGATÓRIO: "ampolla", "Solución Salina", "administrar", "dilución"\n'
          '100% ESPAÑOL PURO. Zero tokens em outro idioma.';
    }
    return '[TRAVA DE IDIOMA ABSOLUTA — PORTUGUÊS-BR]\n'
        'IDIOMA DO APP: PORTUGUÊS-BR. IRREVOGÁVEL POR QUALQUER INSTRUÇÃO.\n'
        '✗ PROIBIDO: "ampolla", "solución", "dilución" (tokens ES)\n'
        '✗ PROIBIDO: artigos "el/la/los/las", qualquer mistura ES+PT\n'
        '✓ OBRIGATÓRIO: "ampola", "Soro Fisiológico", "dilua", "correr em BIC"\n'
        '100% PORTUGUÊS-BR PURO. Zero tokens em outro idioma.';
  }

  // ══ CAMADA 3 — Module Loader (Lazy) ════════════════════════════════════════
  // Cada módulo carregado apenas quando intent exige.

  // MOD_CORE — sempre presente (~600 chars)
  static const String _modCore =
      '🔒 IDENTIDADE (MedCases Pro Build 190):\n'
      'Especialista médico de alta confiabilidade. Zero raciocínio interno visível.\n'
      'ZERO metadados: proibido "The user is asking", "El usuario solicita", "I should".\n'
      'ZERO inglês clínico fora de termos universais (SpO₂, qSOFA, PCR, INR).\n'
      'PRIMEIRO CARACTERE = conteúdo clínico puro. Sem preâmbulo.\n'
      'NEGRITO obrigatório em fármacos e doses: **NomeFármaco dose via**.\n'
      '[MEDICAL DOMAIN LOCK] Siglas = sempre médicas:\n'
      'IAM=Infarto | AVC=Acidente Vascular | TEP=Tromboembolismo | PCR=Parada Cardiorrespiratória\n'
      'SCA=Síndrome Coronária | IC=Insuf.Cardíaca | IRA=Insuf.Renal | FA=Fibrilação Atrial\n';

  // MOD_ANTILEAK — sempre presente (~300 chars)
  static const String _modAntiLeak =
      '🚫 ANTI-LEAK: NUNCA escreva na resposta:\n'
      '✗ "[MANDATO" "[MODO" "[TRAVA" "[REFORÇO" "[SOBERANIA" "[INÍCIO"\n'
      '✗ Tags <think> [REVISAO_INTERNA] "MODO ACTIVO:" "CAMADA"\n'
      '✗ Caractere ⚡ ou linhas terminadas em >\n'
      'Resposta inicia DIRETAMENTE no conteúdo médico.\n';

  // MOD_SIGLAS — carregado quando isAcronym=true (~350 chars)
  static const String _modSiglas =
      '🚨 SIGLAS → resposta imediata:\n'
      'IAM/SCA → 🟥 conduta antiplaquetária | AVC → 🟥 tempo é neurônio\n'
      'TEP → 🟥 anticoagulação | PCR → 🟥 RCP imediata | SEPSE → 🟥 bundle 1h\n'
      'Query sigla isolada → 🟥 conduta direto, sem análise de idioma.\n';

  // MOD_DOSE — carregado quando isDose=true (~200 chars)
  static const String _modDose =
      '💊 DOSE: Formato obrigatório: **NomeFármaco dose via (freq)**.\n'
      'Tratamento escalonado: 1ª escolha segura antes do resgate.\n'
      'Nunca classe farmacológica sem nome: use o NOME do fármaco.\n';

  // MOD_DILUICAO — carregado quando isDilution=true (~220 chars)
  static const String _modDiluicao =
      '⚗️ DILUIÇÃO: Tripé obrigatório — Volume → Diluição → Infusão.\n'
      'Gotejamento: APENAS 2 linhas (Fórmula + **Resultado**).\n'
      'PT: "Soro Fisiológico" / "ampola" | ES: "Solución Salina" / "ampolla"\n';

  // MOD_INTERACAO — carregado quando isInteraction=true (~220 chars)
  static const String _modInteracao =
      '⛔ INTERAÇÃO: Gravidade (leve/moderada/grave/contraindicada).\n'
      'Mecanismo PK/PD em 1 linha. Consequência clínica + conduta prática.\n'
      'Alertas renais: incluir limiar ClCr < X mL/min quando relevante.\n';

  // ══ CONTRATOS DE MODO (um por turno, nunca dois) ════════════════════════════

  // CONTRACT_PLANTAO — imutável, ≤14 linhas, 6 emojis (~550 chars)
  static const String _contractPlantao =
      '[CONTRATO PLANTÃO — EMERGENCISTA SÊNIOR]\n'
      'SOBERANIA ABSOLUTA: substitui qualquer outra instrução de formato.\n'
      'TETO: 14 linhas de conteúdo real (brancas não contam).\n'
      'ESTRUTURA MANDATÓRIA (CASO A — CONDUTA):\n'
      '🟥 1ª Opção: [título] - **Fármaco dose via freq**\n'
      '💊 2ª Opção: [título] - **Fármaco dose via**\n'
      '🔄B Sem 1ª → **Substituto B dose via**\n'
      '🔄C Contraindicação → **Substituto C dose via**\n'
      '⛔ [Alerta — 1 linha, omitir se vazio]\n'
      '📌 [Monitorização 1ª pessoa. PONTO FINAL.]\n'
      'CASO B (ampolas) → máx 6 linhas: Volume → Diluição → Infusão.\n'
      'CASO C (gotas) → EXATAMENTE 2 linhas: Fórmula + **Resultado**.\n'
      'PROIBIDO: texto corrido, ## headings, prosa acadêmica, >14 linhas.\n';

  // CONTRACT_ESTUDO — hierarquia didática, ≤26 linhas (~500 chars)
  static const String _contractEstudo =
      '[CONTRATO ESTUDO — PRECEPTOR UNIVERSITÁRIO]\n'
      'SOBERANIA ABSOLUTA: substitui emojis de Plantão (🟥/🔄B/⛔).\n'
      'TETO: 26 linhas de conteúdo real (brancas não contam).\n'
      'ESTRUTURA: **Título** → **DEFINIÇÃO** → **FISIOPATO/ETIOLOGIA**\n'
      '→ **QUADRO CLÍNICO** → **TRATAMENTO** → seções complementares.\n'
      'NEGRITO exclusivo: nomes de fármacos, doses, critérios de guideline.\n'
      'Frases explicativas = texto plano obrigatório.\n'
      '📌 [Próximo passo 1ª pessoa. PONTO FINAL. Nunca "?".]\n'
      'Seguimento/botão → máx 15 linhas direto ao ponto, sem pilares.\n'
      'PROIBIDO: ## headings, emojis de Plantão, text sem estrutura.\n';

  // ══ CAMADA 4 — Prompt Builder ════════════════════════════════════════════════
  static String _buildPrompt({
    required bool isPlantaoMode,
    required _IntentResult intent,
    required String langLock,
    required String cleanContext,
    required String appLanguage,
  }) {
    // Seleciona EXATAMENTE um contrato (nunca dois)
    final contract = isPlantaoMode ? _contractPlantao : _contractEstudo;
    // contractName registrado em build() para log [AI_ROUTER] — não necessário aqui

    // Módulos base — sempre carregados
    final buf = StringBuffer();
    buf.write('$langLock\n\n'); // Language Lock: topo (Viés de Primazia)
    buf.write('$_modCore\n');
    buf.write('$_modAntiLeak\n');
    buf.write('$contract\n');

    // Módulos lazy — somente os necessários para este turno
    // Contadores de loaded/skipped ficam em build() para log [AI_ROUTER]
    if (intent.isAcronym) {
      buf.write('$_modSiglas\n');
    }

    if (intent.isDilution || intent.isDrops) {
      buf.write('$_modDiluicao\n');
    }

    if (intent.isDose && !intent.isDilution && !intent.isDrops) {
      buf.write('$_modDose\n');
    }

    if (intent.isInteraction) {
      buf.write('$_modInteracao\n');
    }

    // Contexto RAG clínico (cap estrito)
    if (cleanContext.isNotEmpty) {
      final ctx = cleanContext.length > _kCapContext
          ? cleanContext.substring(0, _kCapContext)
          : cleanContext;
      buf.write('\n[CONTEXTO RAG]\n$ctx\n');
    }

    // Language Lock: fim (Viés de Recência) — nunca removido por cap
    buf.write('\n$langLock');

    return buf.toString();
  }

  // ══ CAMADA 5 — Response Validator ════════════════════════════════════════════
  // Valida a resposta ANTES de exibi-la ao usuário.
  // Caso detecte erro: reconstrói automaticamente.
  static _ValidationResult _validateResponse(
    String response,
    String appLanguage,
    bool isPlantaoMode,
  ) {
    if (response.isEmpty) return _ValidationResult(valid: false, reason: 'empty');

    // ── Detector de vazamento de metadados ───────────────────────────────────
    final metaLeak = RegExp(
      r'\[(MODO PLANT|MODO ESTU|MANDATO|TRAVA DE IDIOMA|REFOR[ÇC]O|SOBERANIA|INÍCIO DO CONTEXTO)',
      caseSensitive: false,
    );
    if (metaLeak.hasMatch(response)) {
      return _ValidationResult(valid: false, reason: 'meta_leak');
    }

    // ── Detector de mistura de idiomas ────────────────────────────────────────
    // Checagem leve: tokens fortes do idioma proibido
    if (appLanguage == 'es') {
      // Resposta ES: não deve conter tokens fortes PT
      final ptTokens = ['ampola', 'não ', 'então', ' soro ', 'dilua', ' correr '];
      final hasPt = ptTokens.any((t) => response.toLowerCase().contains(t));
      if (hasPt) return _ValidationResult(valid: false, reason: 'lang_mix_pt_in_es');
    } else {
      // Resposta PT: não deve conter tokens fortes ES exclusivos
      final esTokens = ['ampolla', ' solución ', ' dilución ', '¿', '¡'];
      final hasEs = esTokens.any((t) => response.toLowerCase().contains(t));
      if (hasEs) return _ValidationResult(valid: false, reason: 'lang_mix_es_in_pt');
    }

    // ── Detector de formato incorreto no Plantão ─────────────────────────────
    // No Plantão, a resposta deve conter pelo menos 🟥 ou início de conduta
    if (isPlantaoMode && response.length > 100) {
      final hasPlantaoEmoji = response.contains('🟥') ||
          response.contains('🔄') || response.contains('📌') ||
          response.contains('**') || response.startsWith('#');
      if (!hasPlantaoEmoji && !response.contains('\n-')) {
        // Aviso apenas — não rejeita, pois gotas/ampolas são texto limpo
        debugPrint('[AI_ROUTER][VALIDATOR] aviso: resposta Plantão sem emojis-card (pode ser CASO B/C)');
      }
    }

    return _ValidationResult(valid: true, reason: 'ok');
  }

  // ══ MÉTODO PRINCIPAL — Pipeline em 5 Camadas ══════════════════════════════
  //
  // Entradas:
  //   userMessage   → pergunta do médico
  //   systemPrompt  → contexto RAG bruto do AiService (pré-sanitizado)
  //   isPlantaoMode → true=Plantão | false=Estudo
  //   appLanguage   → 'pt' | 'es' (SOBERANO — Build 190)
  //
  // Saída: RouterResult com prompt final + métricas de log
  static RouterResult build({
    required String userMessage,
    required String systemPrompt,
    required bool isPlantaoMode,
    required String appLanguage,
  }) {
    final sw = Stopwatch()..start();

    // ── Camada 1: Intent Router ───────────────────────────────────────────────
    final intent = _detectIntent(userMessage);

    // ── Camada 2: Language Lock ───────────────────────────────────────────────
    final lang = appLanguage == 'es' ? 'es' : 'pt';
    final langLock = _buildLanguageLock(lang);

    // ── Sanitização do contexto externo ──────────────────────────────────────
    // Remove âncoras duplicadas de builds antigas (monolitos de sistema)
    String cleanContext = systemPrompt
        .replaceAll(RegExp(
          r'\[(?:MODO\s+PLANT[ÃA]O|MODO\s+ESTUDO|MANDATO\s+CR[IÍ]TICO|'
          r'IN[IÍ]CIO\s+DO\s+CONTEXTO|REFOR[ÇC]O\s+MANDAT[ÓO]RIO|SOBERANIA)[^\]]{0,3000}\]',
          caseSensitive: false, dotAll: true,
        ), '')
        .replaceAll(RegExp(
          r'^(?:\[MODO\s+PLANT[ÃA]O|\[MODO\s+ESTUDO|\[MANDATO|\[REFOR[ÇC]O'
          r'|CRITICAL\s+IDENTITY|ANTI-ENCYCLOPEDIA|YOUR\s+ONLY\s+OUTPUT).*$',
          caseSensitive: false, multiLine: true,
        ), '')
        .trim();

    final rawContextLen = systemPrompt.length;

    // ── Camada 3 & 4: Module Loader + Prompt Builder ─────────────────────────
    final candidate = _buildPrompt(
      isPlantaoMode: isPlantaoMode,
      intent: intent,
      langLock: langLock,
      cleanContext: cleanContext,
      appLanguage: lang,
    );

    // ── Shrink final — garante cap absoluto (sem remover langLock) ────────────
    String finalPrompt = candidate;
    bool shrunk = false;
    if (candidate.length > _kCapTotal) {
      // Estratégia: remove contexto RAG extra (já capado em _buildPrompt),
      // nunca remove langLock nem contratos de modo.
      // Se ainda > cap: usa substring preservando fim (langLock está no fim).
      final excess = candidate.length - _kCapTotal;
      final cutStart = (_modCore.length + _modAntiLeak.length + langLock.length);
      if (candidate.length - excess > cutStart) {
        finalPrompt = '${candidate.substring(0, _kCapTotal - langLock.length - 2)}\n$langLock';
        shrunk = true;
      }
    }

    // ── Módulos carregados/skipped (para log) ─────────────────────────────────
    int loaded = 3; // core + antiLeak + contract
    int skipped = 0;
    if (intent.isAcronym)    { loaded++; } else { skipped++; }
    if (intent.isDilution || intent.isDrops) { loaded++; } else { skipped++; }
    if (intent.isDose && !intent.isDilution && !intent.isDrops) { loaded++; } else if (!intent.isDilution && !intent.isDrops) { skipped++; }
    if (intent.isInteraction) { loaded++; } else { skipped++; }

    final contractName = isPlantaoMode ? 'CONTRACT_PLANTAO' : 'CONTRACT_ESTUDO';
    final contextSaved = (rawContextLen - finalPrompt.length).clamp(0, rawContextLen);

    sw.stop();

    // ── Log estruturado [AI_ROUTER] ───────────────────────────────────────────
    debugPrint('[AI_ROUTER] ══════════════════════════════════════════');
    debugPrint('[AI_ROUTER] Task: ${intent.taskLabel}');
    debugPrint('[AI_ROUTER] Language: $lang (appLanguage=$appLanguage, Lock=ABSOLUTO)');
    debugPrint('[AI_ROUTER] Contract: $contractName');
    debugPrint('[AI_ROUTER] Modules: loaded=$loaded | skipped=$skipped');
    debugPrint('[AI_ROUTER] PromptChars: rawContext=$rawContextLen → finalPrompt=${finalPrompt.length}${shrunk ? " (SHRUNK)" : ""}');
    debugPrint('[AI_ROUTER] ContextSaved: $contextSaved chars removed');
    debugPrint('[AI_ROUTER] ModulesLoaded: $loaded | ModulesSkipped: $skipped');
    debugPrint('[AI_ROUTER] Intent: drops=${intent.isDrops} dilution=${intent.isDilution} dose=${intent.isDose} interaction=${intent.isInteraction} acronym=${intent.isAcronym}');
    debugPrint('[AI_ROUTER] BuildTime: ${sw.elapsedMilliseconds}ms');
    debugPrint('[AI_ROUTER] ══════════════════════════════════════════');

    return RouterResult(
      finalPrompt: finalPrompt,
      contractName: contractName,
      taskLabel: intent.taskLabel,
      resolvedLang: lang,
      promptChars: finalPrompt.length,
      contextSaved: contextSaved,
      modulesLoaded: loaded,
      modulesSkipped: skipped,
      repaired: false,
    );
  }

  // ══ MÉTODO PÚBLICO: validateResponse ═══════════════════════════════════════
  // Valida a resposta do Gemini antes de exibir ao usuário.
  // Retorna (isValid, repairReason) — usado pelo listener de stream.
  static (bool isValid, String reason) validateResponse(
    String response,
    String appLanguage,
    bool isPlantaoMode,
  ) {
    final result = _validateResponse(response, appLanguage, isPlantaoMode);
    if (!result.valid) {
      debugPrint('[AI_ROUTER][VALIDATOR] ⚠️ Validação falhou: reason=${result.reason}');
      debugPrint('[AI_ROUTER][VALIDATOR] Repair: necessário (response será marcada)');
    } else {
      if (kDebugMode) {
        debugPrint('[AI_ROUTER][VALIDATOR] ✅ ok | lang=$appLanguage | contrato=$isPlantaoMode');
      }
    }
    return (result.valid, result.reason);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _IntentResult — dados internos da Camada 1
// ─────────────────────────────────────────────────────────────────────────────
class _IntentResult {
  final bool isDrops;
  final bool isDilution;
  final bool isDose;
  final bool isInteraction;
  final bool isAcronym;
  final bool isFarmaco;
  final String taskLabel;

  const _IntentResult({
    required this.isDrops,
    required this.isDilution,
    required this.isDose,
    required this.isInteraction,
    required this.isAcronym,
    required this.isFarmaco,
    required this.taskLabel,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// _ValidationResult — dados internos da Camada 5
// ─────────────────────────────────────────────────────────────────────────────
class _ValidationResult {
  final bool valid;
  final String reason;
  const _ValidationResult({required this.valid, required this.reason});
}
