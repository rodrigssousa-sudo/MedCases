// ══════════════════════════════════════════════════════════════════════════════
// ai_smart_router.dart — Smart Context Router v2.1 (Build 193)
//
// RESPONSABILIDADES EXCLUSIVAS:
//   • ETAPA 2: Prompt Contract Lock — seleciona EXATAMENTE 1 contrato por modo
//   • ETAPA 3: Modo Plantão contrato imutável (≤14 linhas, 6 emojis, formato limpo)
//   • ETAPA 4: Smart Context Router — envia somente módulos necessários
//   • ETAPA 5: Context Lazy Loading — carrega módulo conforme intent
//   • ETAPA 6: Prompt Shrink — meta < 4.000 chars (perguntas simples < 2.500)
//   • ETAPA 7: Response Pipeline — 5 camadas (Intent→LangLock→Loader→Builder→Validator)
//   • ETAPA 8: Response Validator + Sanitizer — remove metadados, valida idioma,
//              conta linhas Plantão, reconstrói se necessário
//   • ETAPA 11: Logs [RESPONSE_VALIDATOR] + [AI_ROUTER] estruturados
//
// NÃO FAZ:
//   • Transporte HTTP / SSE streaming (→ gemini_service_v2.dart)
//   • Detecção de idioma (→ appLanguage do AppProvider é soberano — Build 190)
//   • Renderização de UI (→ ai_screen.dart)
//   • Dados clínicos / RAG (→ app_provider.dart + ai_service.dart)
//
// FORMATO FINAL PLANTÃO (Build 191):
//   🟥 CONDUTA CLÍNICA IMEDIATA
//   💊 1ª linha: [fármaco + dose + via + frequência]
//   🔄 Alternativa: [segunda opção]
//   ⛔ Evitar: [contraindicação quando houver]
//   📌 Monitorar: [parâmetro]
//   ⚠️ Alerta: [risco crítico]
//
// SANITIZADOR DE METADADOS (Build 191):
//   Remove qualquer linha que contenha tokens internos antes de exibir ao usuário.
//   Tokens bloqueados: MANDATO, CONTRACT, TEMPLATE, ESTRITAMENTE, INSTRUÇÃO,
//   SYSTEM, ROUTER, módulos, "nesta ordem exata", "template de 6 linhas", etc.
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
// AiSmartRouter — Pipeline em 5 Camadas (Build 191)
// ─────────────────────────────────────────────────────────────────────────────
class AiSmartRouter {
  AiSmartRouter._(); // 100% estático

  // ══ HARD CAPS ═════════════════════════════════════════════════════════════
  static const int _kCapContext = 1200; // RAG clínico externo
  static const int _kCapTotal   = 4000; // prompt final máximo
  // ignore: unused_field
  static const int _kCapSimple  = 2500; // meta reservado: queries simples

  // ══ TOKENS BLOQUEADOS — linhas com estes padrões são removidas da resposta ═
  // Usados por sanitizeResponse() para filtrar vazamentos de metadados.
  // Build 193: expandido com CoT phrases + bracket lines adicionais
  static final _metaLeakPatterns = RegExp(
    // ── Marcadores técnicos de prompt (Build 191 — mantidos) ──────────────
    r'(\[MANDATO|\[MODO PLANT|\[MODO ESTU|\[CONTRACT|\[TRAVA DE IDIOMA'
    r'|\[AI_ROUTER|\[REFOR[ÇC]O|\[SOBERANIA|\[IN[ÍI]CIO'
    r'|\[SYSTEM|\[PROMPT|\[CAMADA|\[SISTEMA|\[CONTEXTO RAG\]'
    r'|RESPONDA\s+ESTRITAMENTE|RESPONDA\s+[ÚU]NICA\s+E\s+EXCLUSIVAMENTE'
    r'|TEMPLATE\s+DE\s+\d+\s+LINHAS|NESTA\s+ORDEM\s+EXATA'
    r'|PROIBIDO\s+CRIAR\s+INTRODU'
    r'|INSTRUÇÃO\s+DE\s+SISTEMA|PROMPT\s+INTERNO'
    r'|SYSTEM\s+INSTRUCTION|SMART\s+ROUTER|LAZY\s+M[ÓO]DULO'
    // ── Frases de CoT / raciocínio interno (Build 193 — novas) ───────────
    // Português
    r'|^Vou\s+responder'
    r'|^Vamos\s+analisar'
    r'|^Segue\s+abaixo'
    r'|^Aqui\s+est[áa]'
    r'|^Com\s+base\s+na\s+solicita[çc][ãa]o'
    r'|^Resposta:'
    r'|^An[áa]lise:'
    r'|^Explica[çc][ãa]o:'
    r'|^Racioc[íi]nio'
    r'|^Pensamento'
    r'|^Processando'
    r'|^Modo\s+Plant[ãa]o'
    r'|^Formato\s+Plant[ãa]o'
    r'|^Primeiro,'
    r'|^Primeiro\s+vou'
    r'|^Primeiramente'
    // Espanhol
    r'|^Voy\s+a\s+responder'
    r'|^Vamos\s+a\s+analizar'
    r'|^Aqu[íi]\s+est[áa]'
    r'|^Con\s+base\s+en\s+la\s+solicitud'
    r'|^Respuesta:'
    r'|^An[áa]lisis:'
    r'|^Explicaci[oó]n:'
    r'|^Razonamiento'
    r'|^Pensamiento'
    r'|^Procesando'
    r'|^Modo\s+Guard[íi]a'
    r'|^Formato\s+Guard[íi]a'
    r'|^Primero,'
    // Inglês (CoT leaked)
    r'|^Let\s+me\s+'
    r'|^I\s+will\s+'
    r'|^I\s+need\s+to\s+'
    r'|^Here\s+is\s+'
    r'|^Here\s+are\s+'
    r'|^Based\s+on\s+the\s+'
    r'|^Analysis:'
    r'|^Reasoning:'
    r'|^Processing'
    r')',
    caseSensitive: false,
    multiLine: true,
  );

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
        m.contains('indicaç') || m.contains('indicaci'));

    // Label para log
    final taskLabel = isDrops       ? 'gotas'
        : isDilution    ? 'diluicao'
        : isInteraction ? 'interacao'
        : isDose        ? 'dose'
        : isAcronym     ? 'sigla'
        : isFarmaco     ? 'farmaco'
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
  // Build 190+: appLanguage é soberano. Nunca detectamos da query.
  // BUILD 248: instrução explícita para ignorar idioma da pergunta do usuário.
  static String _buildLanguageLock(String appLanguage) {
    final lang = appLanguage == 'es' ? 'es' : 'pt';

    if (lang == 'es') {
      return '[TRAVA DE IDIOMA ABSOLUTA — ESPAÑOL (BUILD 248)]\n'
          'IDIOMA SOBERANO DO APP: ESPAÑOL. IRREVOGÁVEL.\n'
          'IGNORAR COMPLETAMENTE o idioma da pergunta do usuário.\n'
          'Não importa se a pergunta é em português, inglês ou misturada:\n'
          'RESPONDA OBRIGATORIAMENTE EM ESPAÑOL.\n'
          '✗ PROIBIDO: "ampola", "soro", "não", "então", "dilua" (tokens PT)\n'
          '✗ PROIBIDO: qualquer mistura PT+ES (Portunhol)\n'
          '✓ OBRIGATÓRIO: "ampolla", "Solución Salina", "administrar", "dilución"\n'
          '100% ESPAÑOL PURO. Zero tokens em outro idioma.';
    }
    return '[TRAVA DE IDIOMA ABSOLUTA — PORTUGUÊS-BR (BUILD 248)]\n'
        'IDIOMA SOBERANO DO APP: PORTUGUÊS-BR. IRREVOGÁVEL.\n'
        'IGNORAR COMPLETAMENTE o idioma da pergunta do usuário.\n'
        'Não importa se a pergunta é em espanhol, inglês ou misturada:\n'
        'RESPONDA OBRIGATORIAMENTE EM PORTUGUÊS-BR.\n'
        '✗ PROIBIDO: "ampolla", "solución", "dilución" (tokens ES)\n'
        '✗ PROIBIDO: artigos "el/la/los/las", qualquer mistura ES+PT\n'
        '✓ OBRIGATÓRIO: "ampola", "Soro Fisiológico", "dilua", "correr em BIC"\n'
        '100% PORTUGUÊS-BR PURO. Zero tokens em outro idioma.';
  }

  // ══ CAMADA 3 — Module Loader (Lazy) ════════════════════════════════════════

  // MOD_CORE — sempre presente
  static const String _modCore =
      '🔒 IDENTIDADE: Especialista médico de alta confiabilidade.\n'
      'ZERO raciocínio interno visível. ZERO preâmbulo. ZERO metadados.\n'
      'Primeiro caractere da resposta = conteúdo clínico puro.\n'
      'Negrito em fármacos e doses: **Nome dose via**.\n'
      'IAM=Infarto | AVC=Acidente Vascular | TEP=Tromboembolismo\n'
      'PCR=Parada Cardiorrespiratória | SCA=Síndrome Coronária Aguda\n';

  // MOD_ANTILEAK — sempre presente (Build 191: lista expandida)
  static const String _modAntiLeak =
      '🚫 ANTI-LEAK ABSOLUTO — NUNCA escreva na resposta:\n'
      '✗ Qualquer linha com: [MANDATO] [MODO] [TRAVA] [REFORÇO] [SOBERANIA]\n'
      '✗ Qualquer linha com: [CONTRACT] [AI_ROUTER] [CAMADA] [SISTEMA]\n'
      '✗ Textos: "Responda ESTRITAMENTE" "template de 6 linhas" "nesta ordem exata"\n'
      '✗ Textos: "Proibido criar introduções" "instrução interna" "MANDATO TURNO"\n'
      '✗ Tags: <think> [REVISAO_INTERNA] "MODO ACTIVO:" ou qualquer meta-instrução\n'
      'A resposta começa DIRETAMENTE no emoji 🟥 (Plantão) ou ## Título (Estudo).\n';

  // MOD_SIGLAS — somente isAcronym=true
  static const String _modSiglas =
      '🚨 SIGLAS: resposta imediata em formato Plantão.\n'
      'IAM/SCA → conduta antiplaquetária urgente\n'
      'AVC → tempo é neurônio, reperfusão\n'
      'TEP → anticoagulação imediata\n'
      'PCR → RCP imediata\n'
      'SEPSE → bundle 1h\n';

  // MOD_DOSE — somente isDose=true
  static const String _modDose =
      '💊 DOSE: **Nome dose via (frequência)**.\n'
      '1ª linha conservadora antes do resgate.\n'
      'Use nome comercial/genérico, nunca só a classe.\n';

  // MOD_DILUICAO — somente isDilution ou isDrops
  static const String _modDiluicao =
      '⚗️ DILUIÇÃO: Tripé — Volume → Diluição → Infusão.\n'
      'Gotas: APENAS 2 linhas (Fórmula + **Resultado**).\n'
      'PT: "Soro Fisiológico" / "ampola" | ES: "Solución Salina" / "ampolla"\n';

  // MOD_INTERACAO — somente isInteraction=true
  static const String _modInteracao =
      '⛔ INTERAÇÃO: Gravidade + mecanismo em 1 linha + conduta prática.\n'
      'Alertas renais: ClCr < X mL/min quando relevante.\n';

  // ══ CONTRATO PLANTÃO — Build 191: formato clínico limpo ════════════════════
  // CRÍTICO: não usar "B", "C", não mencionar "template", não listar regras.
  // Apenas o formato visual final que o LLM deve produzir.
  static const String _contractPlantao =
      'FORMATO OBRIGATÓRIO DA RESPOSTA (Modo Plantão):\n'
      '\n'
      '🟥 CONDUTA CLÍNICA IMEDIATA\n'
      '💊 1ª linha: [fármaco principal + dose + via + frequência]\n'
      '🔄 Alternativa: [segunda opção ou conduta alternativa]\n'
      '⛔ Evitar: [contraindicação — omitir se não houver]\n'
      '📌 Monitorar: [parâmetro principal de segurança]\n'
      '⚠️ Alerta: [risco crítico — omitir se não houver]\n'
      '\n'
      'REGRAS:\n'
      '• Máximo 14 linhas de conteúdo real.\n'
      '• Cada linha = UMA função clínica.\n'
      '• Sem fisiopatologia, sem prosa acadêmica, sem ## headings.\n'
      '• Gotas: APENAS 2 linhas (Fórmula + **Resultado em negrito**).\n'
      '• Diluição: Volume → Diluição → Infusão (máx 6 linhas).\n';

  // ══ CONTRATO ESTUDO ═════════════════════════════════════════════════════════
  static const String _contractEstudo =
      'FORMATO OBRIGATÓRIO DA RESPOSTA (Modo Estudo — Preceptor Universitário):\n'
      '\n'
      '## [Título clínico específico]\n'
      'Definição: [1 linha exata]\n'
      'Fisiopatologia: [2 linhas — pathway + consequência]\n'
      'Mecanismo de Ação (se farmacológico): [2 linhas — alvo + efeito]\n'
      '[Seções adicionais: epidemiologia, diagnóstico, tratamento com doses]\n'
      '📌 [Próximo passo em 1ª pessoa. PONTO FINAL. Nunca "?"]\n'
      '\n'
      'REGRAS:\n'
      '• Máximo 26 linhas de conteúdo real.\n'
      '• Negrito apenas em fármacos, doses e critérios de guideline.\n'
      '• Sem emojis de Plantão (🟥/🔄/⛔).\n'
      '• Doses: incluir SOMENTE se explicitamente perguntado.\n';

  // ══ CAMADA 4 — Prompt Builder ════════════════════════════════════════════════
  static String _buildPrompt({
    required bool isPlantaoMode,
    required _IntentResult intent,
    required String langLock,
    required String cleanContext,
  }) {
    final contract = isPlantaoMode ? _contractPlantao : _contractEstudo;

    final buf = StringBuffer();
    buf.write('$langLock\n\n');    // Language Lock: topo (Viés de Primazia)
    buf.write('$_modCore\n');
    buf.write('$_modAntiLeak\n');
    buf.write('$contract\n');

    // Módulos lazy
    if (intent.isAcronym)                               buf.write('$_modSiglas\n');
    if (intent.isDilution || intent.isDrops)            buf.write('$_modDiluicao\n');
    if (intent.isDose && !intent.isDilution && !intent.isDrops) buf.write('$_modDose\n');
    if (intent.isInteraction)                           buf.write('$_modInteracao\n');

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

  // ══ CAMADA 5 — Response Validator + Sanitizer ════════════════════════════════
  //
  // Build 191: separação clara em 2 funções:
  //   _validateResponse()  → detecta problemas internamente
  //   sanitizeResponse()   → remove linhas de metadados da resposta visível
  //
  // BUILD 232: adicionado sanitizeAndCheck() que retorna SanitizeResult com
  //   indicador de severidade do meta leak para decisão de fallback no chamador.
  //
  // sanitizeResponse() é PÚBLICO e chamado pelo app_provider ANTES de exibir.
  // ─────────────────────────────────────────────────────────────────────────────

  // ── Tokens de meta leak SEVERO (prompt instructions brutos — nunca clínico) ──
  // Subset do _metaLeakPatterns que indica contaminação grave:
  // a resposta contém instruções internas do prompt, não apenas CoT.
  static final _severeLeakPatterns = RegExp(
    r'(\[MANDATO|\[CONTRACT|\[AI_ROUTER|\[CAMADA|\[SISTEMA'
    r'|RESPONDA\s+ESTRITAMENTE|RESPONDA\s+[ÚU]NICA\s+E\s+EXCLUSIVAMENTE'
    r'|TEMPLATE\s+DE\s+\d+\s+LINHAS|NESTA\s+ORDEM\s+EXATA'
    r'|PROIBIDO\s+CRIAR\s+INTRODU'
    r'|INSTRUÇÃO\s+DE\s+SISTEMA|PROMPT\s+INTERNO'
    r'|SYSTEM\s+INSTRUCTION|SMART\s+ROUTER)',
    caseSensitive: false,
    multiLine: true,
  );

  /// BUILD 247: SafetyFallback — exibido SOMENTE quando a resposta contém
  /// meta-leak irrecuperável (vazamento de raciocínio interno severo).
  /// NÃO deve ser usado para respostas com conteúdo clínico válido.
  /// Decisão de uso: AiSmartRouter.shouldFallback() ou sanitizeAndCheck().
  static String _clinicalFallback(String lang) {
    if (lang == 'es') {
      return '🟥 REVISANDO RESPOSTA\n'
          '⚠️ Alerta: A resposta continha dados inconsistentes e foi bloqueada por segurança.\n'
          '📌 Orientação: Reformule a pergunta em uma frase objetiva (ex: "Dosis de amiodarona en PCR").';
    }
    return '🟥 REVISANDO RESPOSTA\n'
        '⚠️ Alerta: A resposta continha dados inconsistentes e foi bloqueada por segurança.\n'
        '📌 Orientação: Reformule a pergunta em uma frase objetiva (ex: "Dose de amiodarona em PCR").';
  }

  /// BUILD 232 — Sanitiza e avalia severidade do meta leak.
  ///
  /// Retorna [SanitizeResult] com:
  ///   • [text]         → texto sanitizado (ou fallback se irrecuperável)
  ///   • [hadMetaLeak]  → true se havia qualquer meta leak
  ///   • [hadSevereLeak] → true se havia tokens críticos de prompt interno
  ///   • [isRecoverable] → false se o texto pós-sanitização ficou vazio ou
  ///                       ainda contém tokens severos (usar fallback clínico)
  static SanitizeResult sanitizeAndCheck(
    String response, {
    bool isPlantaoMode = false,
    String appLanguage = 'pt',
  }) {
    if (response.isEmpty) {
      return SanitizeResult(text: response, hadMetaLeak: false, hadSevereLeak: false, isRecoverable: false);
    }

    // ── Detecta leak severo ANTES da sanitização ─────────────────────────────
    final hadSevereLeak = _severeLeakPatterns.hasMatch(response);
    final hadMetaLeak   = hadSevereLeak || _metaLeakPatterns.hasMatch(response);

    if (hadMetaLeak) {
      debugPrint('[RESPONSE_VALIDATOR] meta_leak=true severe=$hadSevereLeak — iniciando repair');
    }

    // ── Sanitização: remove linhas contaminadas ──────────────────────────────
    final lines = response.split('\n');
    final cleaned = <String>[];
    int metaLinesRemoved = 0;

    for (final line in lines) {
      if (_metaLeakPatterns.hasMatch(line)) {
        metaLinesRemoved++;
        debugPrint('[RESPONSE_VALIDATOR] meta_leak removida: '
            '"${line.trim().length > 60 ? line.trim().substring(0, 60) : line.trim()}..."');
      } else {
        cleaned.add(line);
      }
    }

    String result = cleaned.join('\n').trim();

    // ── Verifica se o resultado pós-repair ainda está contaminado ────────────
    final stillContaminated = _severeLeakPatterns.hasMatch(result);
    final contentLines = result.split('\n').where((l) => l.trim().isNotEmpty).length;
    // Irrecuperável: vazio, ou ainda contaminado, ou restaram <2 linhas clínicas
    final isRecoverable = result.isNotEmpty && !stillContaminated && contentLines >= 2;

    debugPrint('[RESPONSE_VALIDATOR] '
        'metaLeak=$hadMetaLeak severe=$hadSevereLeak '
        'linesRemoved=$metaLinesRemoved '
        'isRecoverable=$isRecoverable '
        'contentLinesAfter=$contentLines');

    // ── Se irrecuperável, usa fallback clínico seguro ────────────────────────
    final finalText = isRecoverable ? result : _clinicalFallback(appLanguage);

    return SanitizeResult(
      text: finalText,
      hadMetaLeak: hadMetaLeak,
      hadSevereLeak: hadSevereLeak,
      isRecoverable: isRecoverable,
    );
  }

  /// Sanitiza a resposta removendo linhas com metadados internos.
  /// Chamado ANTES de exibir ao usuário.
  /// Retorna a resposta limpa.
  static String sanitizeResponse(
    String response, {
    bool isPlantaoMode = false,
    String appLanguage = 'pt',
  }) {
    if (response.isEmpty) return response;

    // ── Passo 1: remove linhas com tokens de sistema ─────────────────────────
    final lines = response.split('\n');
    final cleaned = <String>[];
    int metaLinesRemoved = 0;

    for (final line in lines) {
      if (_metaLeakPatterns.hasMatch(line)) {
        metaLinesRemoved++;
        debugPrint('[RESPONSE_VALIDATOR] meta_leak removida: "${line.trim().length > 60 ? line.trim().substring(0, 60) : line.trim()}…"');
      } else {
        cleaned.add(line);
      }
    }

    String result = cleaned.join('\n').trim();

    // ── Passo 2: conta linhas de conteúdo real no Plantão ───────────────────
    int plantaoLines = 0;
    bool plantaoOverflow = false;
    if (isPlantaoMode) {
      plantaoLines = result
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .length;
      plantaoOverflow = plantaoLines > 14;
    }

    // ── Passo 3: verifica mistura de idiomas ─────────────────────────────────
    bool langOk = true;
    if (appLanguage == 'es') {
      final ptTokens = ['ampola', 'não ', 'então', ' soro ', 'dilua', ' correr '];
      if (ptTokens.any((t) => result.toLowerCase().contains(t))) langOk = false;
    } else {
      final esTokens = ['ampolla', ' solución ', ' dilución ', '¿', '¡'];
      if (esTokens.any((t) => result.toLowerCase().contains(t))) langOk = false;
    }

    // ── Log [RESPONSE_VALIDATOR] ─────────────────────────────────────────────
    debugPrint('[RESPONSE_VALIDATOR] metaLeak=${metaLinesRemoved > 0} (${metaLinesRemoved}L removidas)');
    debugPrint('[RESPONSE_VALIDATOR] langOk=$langOk (appLanguage=$appLanguage)');
    if (isPlantaoMode) {
      debugPrint('[RESPONSE_VALIDATOR] plantaoLines=$plantaoLines | overflow=$plantaoOverflow');
    }
    debugPrint('[RESPONSE_VALIDATOR] repaired=${metaLinesRemoved > 0}');

    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD 247: shouldFallback() — ÚNICA fonte de decisão de fallback clínico.
  //
  // Centraliza toda lógica de "bloquear resposta e usar fallback".
  // Chamado por _plantaoTruncationGuard (ai_screen.dart).
  //
  // BLOQUEIA apenas se:
  //   1. resposta vazia
  //   2. claramente truncada (sem conteúdo clínico + sintaxe cortada)
  //   3. meta-leak irrecuperável
  //   4. sem nenhum valor clínico
  //
  // PRESERVA se:
  //   • tem sigla clínica (IAM, TEP, PCR…)
  //   • tem keyword clínica (dose, mg, conduta, tratamento…)
  //   • repaired=true, orderFixed=true, hiddenFields>0
  //   • resposta curta com conteúdo real
  //
  // LOG: [RESPONSE_VALIDATOR] fallback=true/false reason=...
  // ─────────────────────────────────────────────────────────────────────────
  static ({bool fallback, String reason}) shouldFallback({
    required bool parserValid,
    required bool hasClinicalContent,
    required bool isTruncated,
    required bool hasMetaLeak,
    required bool repaired,
    required bool orderFixed,
    required int hiddenFields,
    required int removedLines,
  }) {
    // Nunca bloquear se o parser produziu resposta estruturada
    if (parserValid) {
      return (fallback: false, reason: 'parser_valid');
    }

    // Nunca bloquear se repair/organizer interveio com sucesso
    if (repaired || orderFixed || hiddenFields > 0 || removedLines > 0) {
      return (fallback: false, reason: 'repair_success');
    }

    // Nunca bloquear se tem conteúdo clínico útil (mesmo sem estrutura)
    if (hasClinicalContent && !hasMetaLeak) {
      return (fallback: false, reason: 'useful_content');
    }

    // Bloquear: meta-leak irrecuperável
    if (hasMetaLeak) {
      return (fallback: true, reason: 'meta_leak');
    }

    // Bloquear: truncada E sem conteúdo clínico
    if (isTruncated && !hasClinicalContent) {
      return (fallback: true, reason: 'truncated_no_clinical');
    }

    // Bloquear: sem nenhum valor clínico
    if (!hasClinicalContent) {
      return (fallback: true, reason: 'no_clinical_value');
    }

    // Default conservador: preservar (conteúdo clínico presente)
    return (fallback: false, reason: 'default_preserve');
  }

  static _ValidationResult _validateResponse(
    String response,
    String appLanguage,
    bool isPlantaoMode,
  ) {
    if (response.isEmpty) return _ValidationResult(valid: false, reason: 'empty');

    // ── Detector de vazamento de metadados ───────────────────────────────────
    if (_metaLeakPatterns.hasMatch(response)) {
      return _ValidationResult(valid: false, reason: 'meta_leak');
    }

    // ── Detector de mistura de idiomas ────────────────────────────────────────
    if (appLanguage == 'es') {
      final ptTokens = ['ampola', 'não ', 'então', ' soro ', 'dilua', ' correr '];
      if (ptTokens.any((t) => response.toLowerCase().contains(t))) {
        return _ValidationResult(valid: false, reason: 'lang_mix_pt_in_es');
      }
    } else {
      final esTokens = ['ampolla', ' solución ', ' dilución ', '¿', '¡'];
      if (esTokens.any((t) => response.toLowerCase().contains(t))) {
        return _ValidationResult(valid: false, reason: 'lang_mix_es_in_pt');
      }
    }

    // ── Detector de overflow no Plantão ─────────────────────────────────────
    if (isPlantaoMode && response.length > 100) {
      final contentLines = response
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .length;
      if (contentLines > 14) {
        debugPrint('[RESPONSE_VALIDATOR] aviso: plantaoLines=$contentLines > 14 (overflow)');
      }
    }

    return _ValidationResult(valid: true, reason: 'ok');
  }

  // ══ MÉTODO PRINCIPAL — Pipeline em 5 Camadas ══════════════════════════════
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
    // Remove âncoras duplicadas de builds antigas
    String cleanContext = systemPrompt
        .replaceAll(RegExp(
          r'\[(?:MODO\s+PLANT[ÃA]O|MODO\s+ESTUDO|MANDATO\s+CR[IÍ]TICO|'
          r'MANDATO\s+DE\s+INTENT|MANDATO\s+TURNO|'
          r'IN[IÍ]CIO\s+DO\s+CONTEXTO|REFOR[ÇC]O\s+MANDAT[ÓO]RIO|SOBERANIA)[^\]]{0,3000}\]',
          caseSensitive: false, dotAll: true,
        ), '')
        .replaceAll(RegExp(
          r'^(?:\[MODO\s+PLANT[ÃA]O|\[MODO\s+ESTUDO|\[MANDATO|\[REFOR[ÇC]O'
          r'|\[IN[IÍ]CIO\s+DO\s+CONTEXTO'
          r'|CRITICAL\s+IDENTITY|ANTI-ENCYCLOPEDIA|YOUR\s+ONLY\s+OUTPUT).*$',
          caseSensitive: false, multiLine: true,
        ), '')
        .trim();

    final rawContextLen = systemPrompt.length;

    // ── Camadas 3 & 4: Module Loader + Prompt Builder ─────────────────────────
    final candidate = _buildPrompt(
      isPlantaoMode: isPlantaoMode,
      intent: intent,
      langLock: langLock,
      cleanContext: cleanContext,
    );

    // ── Shrink final — garante cap absoluto (sem remover langLock) ────────────
    String finalPrompt = candidate;
    bool shrunk = false;
    if (candidate.length > _kCapTotal) {
      final cutStart = _modCore.length + _modAntiLeak.length + langLock.length;
      if (candidate.length > cutStart) {
        finalPrompt = '${candidate.substring(0, _kCapTotal - langLock.length - 2)}\n$langLock';
        shrunk = true;
      }
    }

    // ── Módulos carregados/skipped (para log) ─────────────────────────────────
    int loaded = 3; // core + antiLeak + contract
    int skipped = 0;
    if (intent.isAcronym)    { loaded++; } else { skipped++; }
    if (intent.isDilution || intent.isDrops) { loaded++; } else { skipped++; }
    if (intent.isDose && !intent.isDilution && !intent.isDrops) { loaded++; }
      else if (!intent.isDilution && !intent.isDrops) { skipped++; }
    if (intent.isInteraction) { loaded++; } else { skipped++; }

    final contractName = isPlantaoMode ? 'CONTRACT_PLANTAO' : 'CONTRACT_ESTUDO';
    final contextSaved = (rawContextLen - finalPrompt.length).clamp(0, rawContextLen);

    sw.stop();

    // ── Log estruturado [AI_ROUTER] — BUILD 245: guardado com kDebugMode ────
    if (kDebugMode) {
      debugPrint('[AI_ROUTER] task=${intent.taskLabel} contract=$contractName '
          'lang=$lang modules=${loaded}L/${skipped}S '
          'prompt=${finalPrompt.length}c saved=${contextSaved}c '
          'buildMs=${sw.elapsedMilliseconds}');
    }

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

  // ══ BUILD 245 — SMART AI ROUTER: classifyPriority ═════════════════════════
  //
  // Classifica a requisição como 'critical' (vai direto ao pago) ou 'academic'
  // (tenta Free primeiro, fallback pago se falhar).
  //
  // REGRAS:
  //   1. isPlantaoMode == true  → sempre 'critical'
  //   2. contractName == 'CONTRACT_PLANTAO' → sempre 'critical'
  //   3. Mensagem contém keyword de urgência/conduta/dose → 'critical'
  //   4. Mensagem contém keyword estritamente acadêmica E nenhuma crítica → 'academic'
  //   5. Default → 'critical' (conservative — nunca arriscar Free em clínica)
  //
  // Retorna: ('critical'|'academic', reasonLabel)
  // ──────────────────────────────────────────────────────────────────────────
  static (String priority, String reason) classifyPriority({
    required String userMessage,
    required bool isPlantaoMode,
    required String contractName,
  }) {
    // Regra 1 + 2: modo ou contrato Plantão → critical direto
    if (isPlantaoMode || contractName == 'CONTRACT_PLANTAO') {
      return ('critical', 'plantao_mode');
    }

    final m = userMessage.toLowerCase();

    // ── Keywords de urgência/conduta clínica → critical ────────────────────
    const criticalKeywords = [
      // Intenção clínica direta
      'dose', 'dosis', 'conduta', 'conducta', 'tratamento', 'tratamiento',
      'urgência', 'urgencia', 'emergência', 'emergencia',
      'interação', 'interacción', 'interacao', 'interaccion',
      'cálculo', 'calculo', 'prescrição', 'prescripcion', 'prescricao',
      'infusão', 'infusion', 'infusao',
      'mg/kg', 'mcg/kg', 'ml/h', 'ui/kg',
      // Acrônimos críticos isolados (como perguntas curtas "IAM", "TEP")
      'pcr', 'iam', 'avc', 'tep', 'sepse', 'sepsis', 'choque', 'shock',
      'hipercalemia', 'hipocalemia', 'hiponatremia', 'hipernatremia',
      'hipoglicemia', 'hiperglic',
      'anafilaxia', 'anafilaxia', 'anafilaxis',
      'noradrenalina', 'norepinefrina', 'noradrenalin',
      'amiodarona', 'amiodarone',
      'dopamina', 'dobutamina',
      'insulina', 'heparina', 'warfarina', 'varfarina',
      'adrenalina', 'epinefrina',
      'dilui', 'diluci',  // diluição de fármacos
      'gota', 'gotejo',   // cálculo de gotejamento
      'ampol',            // ampola (manejo prático)
      'prescri',          // prescrever
      'antidot',          // antídoto
      'reverter', 'revert',
      'cardiovert',
      'intub', 'svm', 'ventil',
      // Síndromes emergenciais
      'sca', 'icc', 'ira', 'irc', 'dpoc', 'epoc', 'eap',
      'dissecc', 'dissec',  // dissecção aórtica
      'tamponamento', 'taponamiento',
    ];

    // ── Keywords estritamente acadêmicas → academic (apenas se SEM críticas) ──
    const academicKeywords = [
      'explique', 'explica ', 'explicar ', 'explique-me',
      'explica ',  // ES: "explica esto"
      'resumo', 'resumen',
      'fisiopatologia', 'fisiopatología', 'fisiopatology',
      'mecanismo de ação', 'mecanismo de acción', 'mecanismo de accion',
      'diferença entre', 'diferencia entre',
      'flashcard', 'flash card',
      'conceito', 'concepto',
      'história da', 'historia de',
      'epidemiologia', 'epidemiología',
      'classificação', 'clasificación', 'classificacao',
      'diagnóstico diferencial', 'diagnóstico diferencial', 'diagnostico diferencial',
    ];

    final hasCritical = criticalKeywords.any((k) => m.contains(k));
    final hasAcademic = academicKeywords.any((k) => m.contains(k));

    if (hasCritical) {
      return ('critical', 'critical_keyword');
    }

    if (hasAcademic && !hasCritical) {
      return ('academic', 'academic_keyword');
    }

    // Default conservador: clínica → critical
    // Perguntas ambíguas (ex: "AVC hemorrágico") podem ser críticas
    return ('critical', 'default_conservative');
  }

  // ══ MÉTODO PÚBLICO: validateResponse ═══════════════════════════════════════
  // Valida a resposta do Gemini. Retorna (isValid, reason).
  // Para limpeza visual, usar sanitizeResponse() em vez deste.
  static (bool isValid, String reason) validateResponse(
    String response,
    String appLanguage,
    bool isPlantaoMode,
  ) {
    final result = _validateResponse(response, appLanguage, isPlantaoMode);
    if (!result.valid) {
      debugPrint('[RESPONSE_VALIDATOR] ⚠️ falhou: reason=${result.reason}');
    } else {
      if (kDebugMode) {
        debugPrint('[RESPONSE_VALIDATOR] ✅ ok | lang=$appLanguage | plantao=$isPlantaoMode');
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

// ─────────────────────────────────────────────────────────────────────────────
// SanitizeResult — resultado de sanitizeAndCheck() (BUILD 232)
// ─────────────────────────────────────────────────────────────────────────────
class SanitizeResult {
  /// Texto final: sanitizado se isRecoverable, fallback clínico se não.
  final String text;
  /// true se havia qualquer token de meta leak (incluindo CoT phrases).
  final bool hadMetaLeak;
  /// true se havia tokens de prompt interno críticos ([MANDATO], [CONTRACT], etc.).
  final bool hadSevereLeak;
  /// false se a resposta ficou irrecuperável após sanitização → usar fallback.
  final bool isRecoverable;

  const SanitizeResult({
    required this.text,
    required this.hadMetaLeak,
    required this.hadSevereLeak,
    required this.isRecoverable,
  });
}
