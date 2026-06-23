// ══════════════════════════════════════════════════════════════════════════════
// ai_prompt_modules.dart — Modular Prompt Engine V2  (Build 231)
//
// ÚNICA FONTE DE VERDADE para engenharia de prompts do MedCases Pro.
//
// RESPONSABILIDADE EXCLUSIVA:
//   • Montar o system_instruction final entregue ao Gemini 2.5 Flash-Lite
//   • Detectar intenção na user message (dose / diluição / interação / sigla)
//   • Selecionar e concatenar módulos relevantes por turno (zero desperdício)
//   • Sanitizar o systemPrompt externo (RAG/contexto clínico) para remover
//     âncoras duplicadas, regras de builds antigas e monolitos residuais
//   • Logar tamanhos de cada módulo para rastreabilidade de latência
//
// NÃO FAZ:
//   • Transporte HTTP / SSE streaming (→ gemini_service_v2.dart)
//   • Decisão de modo / idioma / grounding (→ ai_gateway_service.dart)
//   • Renderização de UI / parsing de markdown (→ ai_screen.dart)
//
// ARQUITETURA DE MÓDULOS:
//   core          →  Identidade, anti-CoT, anti-metadata   (~15 linhas)
//   antiLeak      →  Filtro de cabeçalhos de sistema        (~12 linhas)
//   uiContract    →  Tokens 🟥 ⛔ 📌 para parser Flutter  (~12 linhas)
//   siglasCriticas→  IAM/AVC/TEP/PCR/IC/IRA/FA/SCA/SEPSE  (~20 linhas)
//   plantao       →  Condutas Sala Vermelha (Caso A/B/C)   (~25 linhas)
//   estudo        →  Hierarquia didática preceptor          (~20 linhas)
//   dose          →  Fármacos, ampolas, negrito obrigatório (~10 linhas)
//   diluicao      →  Gotejamento, velocidade de infusão     (~10 linhas)
//   interacoes    →  Contraindicações, segurança grave      (~10 linhas)
//
// MÉTODO PRINCIPAL:
//   PromptModules.build(userMessage, systemPrompt, isPlantaoMode, langLock)
//     → String finalSystemPrompt pronto para system_instruction do Gemini
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

// ── Build 232: Auditoria temporária de tamanho de prompt ─────────────────────
// Remover após diagnóstico. Espelha kPromptSizeAudit de ai_gateway_service.dart.
// ignore: constant_identifier_names
const bool _kPromptSizeAudit = true;

// ─────────────────────────────────────────────────────────────────────────────
// IntentFlags — resultado da análise semântica da user message
// ─────────────────────────────────────────────────────────────────────────────
class IntentFlags {
  final bool isDose;
  final bool isDilution;
  final bool isInteraction;
  final bool isAcronym;
  final String taskLabel; // para log

  const IntentFlags({
    required this.isDose,
    required this.isDilution,
    required this.isInteraction,
    required this.isAcronym,
    required this.taskLabel,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PromptModules — Módulos estáticos de prompt + método de montagem dinâmica
// ─────────────────────────────────────────────────────────────────────────────
class PromptModules {
  PromptModules._(); // utilitário 100% estático

  // ════════════════════════════════════════════════════════════════════════════
  // MÓDULO: core
  // Identidade básica, anti-CoT absoluto, proibição de exibir metadados.
  // Aplicado em TODOS os turnos, independente do modo.
  // ════════════════════════════════════════════════════════════════════════════
  static const String core =
      '🔒 IDENTIDADE E REGRAS ABSOLUTAS (MedCases Pro — Modular V2):\n'
      'Você é um especialista médico de alta confiabilidade (PT-BR / Español).\n'
      '\n'
      '[MEDICAL DOMAIN LOCK]\n'
      'Você é uma IA estritamente médica. É MANDATÓRIO interpretar toda e qualquer sigla, '
      'abreviação ou acrônimo EXCLUSIVAMENTE dentro do contexto clínico, médico e de emergência.\n'
      'IAM  = Infarto Agudo do Miocárdio (Infarto Agudo al Miocardio). NUNCA "Identity and Access Management".\n'
      'TEP  = Tromboembolismo Pulmonar. NUNCA "Typical Effective Protocol" ou termo de TI.\n'
      'AVC  = Acidente Vascular Cerebral. NUNCA outro significado.\n'
      'PCR  = Parada Cardiorrespiratória. NUNCA "Polymerase Chain Reaction" em contexto clínico de emergência.\n'
      'SCA  = Síndrome Coronária Aguda. NUNCA "Source Code Analysis".\n'
      'DPOC = Doença Pulmonar Obstrutiva Crônica. NUNCA "Data Processing and Operations Center".\n'
      'IC   = Insuficiência Cardíaca. NUNCA "Integrated Circuit".\n'
      'IRA  = Insuficiência Renal Aguda. NUNCA "Irish Republican Army" ou acrônimo de TI.\n'
      'FA   = Fibrilação Atrial. NUNCA "Factory Automation".\n'
      'HAS  = Hipertensão Arterial Sistêmica. DM = Diabetes Mellitus. '
      'IRC = Insuficiência Renal Crônica. AVE = Acidente Vascular Encefálico.\n'
      'REGRA ABSOLUTA: Se uma sigla for ambígua entre medicina e qualquer outra área, '
      'assuma SEMPRE o significado médico mais comum na prática de Sala Vermelha ou Clínica Médica. '
      'Contexto médico tem prioridade absoluta sobre qualquer outro domínio.\n'
      '\n'
      'ZERO raciocínio interno visível: proibido <thinking>, scratchpad, chain-of-thought.\n'
      'ZERO metadados: proibido "The user is asking", "El usuario solicita", "I should".\n'
      'ZERO inglês clínico: apenas termos médicos universais (SpO₂, qSOFA, PCR, INR).\n'
      'ZERO saudação repetida: se histórico existe, comece direto no conteúdo clínico.\n'
      'PRIMEIRO CARACTERE = conteúdo clínico puro. Sem preâmbulo, sem introdução.\n'
      'O FORMAT e PROFUNDIDADE são determinados exclusivamente pelo MODO ATIVO.\n'
      '\n'
      '[OUTPUT CONTRACT]\n'
      'Regra de ouro de saída: Antes de finalizar a resposta, valide internamente que o texto '
      'NÃO inicia por nenhum destes caracteres ou termos: '
      '[, #, ##, ###, ####, #####, ######, MODO, PLANTÃO, ESTUDO, SYSTEM, '
      'SOBERANIA, DIRETRIZ, TRAVA, CONTEXTO, CONFIGURAÇÃO.\n'
      'É expressamente proibido imprimir, repetir ou ecoar: nomes de módulos, nomes internos '
      'do sistema, metadados, tags, contratos, headings artificiais, textos entre colchetes, '
      'ou termos como \'MODO PLANTÃO\' e \'MODO ESTUDO\'. Esses elementos pertencem '
      'exclusivamente ao prompt interno e nunca à resposta clínica. '
      'A resposta deve iniciar diretamente pelo conteúdo médico.\n'
      'OBRIGATORIEDADE DE NEGRITO EM FÁRMACOS E DOSES: Toda menção a medicamentos, '
      'princípios ativos, dosagens (ex: 300mg, 30mg), vias de administração '
      '(ex: VO, IV, SC, IM) e esquemas posológicos DEVE ser formatada obrigatoriamente '
      'em negrito puro usando Markdown de asteriscos duplos. '
      'Exemplos: **AAS 300mg VO**, **Tenecteplase 30mg IV em bolus**, **Enoxaparina 1mg/kg SC 12/12h**. '
      'Nunca escreva dose ou fármaco sem o wrap **...** ao redor.\n'
      'PROIBIÇÃO ABSOLUTA DE SUGESTÕES TEXTUAIS: É terminantemente proibido gerar qualquer '
      'linha de sugestão ou texto que contenha o caractere de raio \'⚡\' '
      'ou que termine com o caractere \'>\'. O modelo nunca deve emular botões por texto. '
      'A resposta deve terminar no último parágrafo clínico.\n';

  // ════════════════════════════════════════════════════════════════════════════
  // MÓDULO: antiLeak
  // Firewall textual contra vazamento de cabeçalhos do system_instruction.
  // Garante que o modelo nunca ecoe blocos de mandato na resposta ao usuário.
  // ════════════════════════════════════════════════════════════════════════════
  static const String antiLeak =
      '🚫 ANTI-LEAK DE SISTEMA (PROIBIÇÃO TOTAL):\n'
      'NUNCA escreva na resposta:\n'
      '  ✗ "Confianza Clínica:" / "Confiança Clínica:" / "Clinical Confidence:"\n'
      '  ✗ "Motivo:" / "Motivos:" / "Motivo del modo:" como primeira linha\n'
      '  ✗ "[MANDATO" / "[MODO PLANTÃO" / "[MODO ESTUDO" / "[INÍCIO DO CONTEXTO"\n'
      '  ✗ "[REFORÇO MANDATÓRIO" / "[SOBERANIA" / "[TRAVA DE IDIOMA"\n'
      '  ✗ Qualquer rótulo de modo: "MODO ACTIVO:", "MODO [A]", "CAMADA 1"\n'
      '  ✗ Tags: <think>...</think> / [REVISAO_INTERNA] / [REVISION_INTERNA]\n'
      '  ✗ Nunca escreva: [MODO...], [SYSTEM...], [TRAVA...], [DIRETRIZ...], '
      '[CONTEXTO...], [SOBERANIA...] em qualquer parte da resposta final.\n'
      '  ✗ Nunca imprima headings artificiais como ##, ###, #### quando representarem '
      'estrutura interna do sistema ou metadados de configuração.\n'
      '  ✗ Nunca imprima o caractere \'⚡\' em qualquer parte da resposta.\n'
      '  ✗ Nunca termine uma linha com o caractere \'>\' (marcação antiga de botão sugerido).\n'
      'REGRA DE SIGLA ISOLADA: query de 1-5 chars → abrir 🟥 direto, sem análise.\n';

  // ════════════════════════════════════════════════════════════════════════════
  // MÓDULO: uiContract
  // Tokens de design system do app Flutter (parser de cards nativos).
  // Garante renderização correta dos cards 🟥 ⛔ 📌 na UI.
  // ════════════════════════════════════════════════════════════════════════════
  static const String uiContract =
      '🎨 DESIGN SYSTEM — TOKENS DE CARD (flutter_markdown parser):\n'
      '  🟥 CARD VERMELHO → Conduta/Prescrição principal. Formato: 🟥 FÁRMACO — dose via freq.\n'
      '  ⛔ CARD LARANJA  → Alertas, contraindicações, interações graves.\n'
      '  📌 CARD AZUL     → Ação do usuário em 1ª pessoa. SEM "?". Nunca pergunta da IA.\n'
      '  💊 2ª opção      → Escalonamento ou substituto.\n'
      '  🔄B / 🔄C        → Planos alternativos por alergia/contraindicação.\n'
      'USE **negrito** para fármacos e doses.\n'
      'NÃO use bullets (* item) no Modo Plantão — apenas emojis de card.\n'
      'NÃO use ## headings — use **negrito** para todos os títulos e rótulos.\n';

  // ════════════════════════════════════════════════════════════════════════════
  // MÓDULO: siglasCriticas
  // Mapeamento inequívoco de acrônimos médicos de emergência.
  // Evita interpretação de siglas como termos de TI ou inglês.
  // ════════════════════════════════════════════════════════════════════════════
  static const String siglasCriticas =
      '🚨 SIGLAS CRÍTICAS — INTERPRETAÇÃO OBRIGATÓRIA (sempre médico, nunca TI):\n'
      '  IAM  → INFARTO AGUDO DO MIOCÁRDIO       (🔴 Emergência) — NUNCA "Identity/Access"\n'
      '  AVC  → ACIDENTE VASCULAR CEREBRAL       (🔴 Emergência)\n'
      '  AVE  → ACIDENTE VASCULAR ENCEFÁLICO     (🔴 Emergência)\n'
      '  TEP  → TROMBOEMBOLISMO PULMONAR          (🔴 Emergência)\n'
      '  PCR  → PARADA CARDIORRESPIRATÓRIA        (🔴 Emergência) — NUNCA "Polymerase Chain"\n'
      '  SCA  → SÍNDROME CORONÁRIA AGUDA          (🔴 Emergência) — EXCLUSIVO Cardiologia\n'
      '  SEPSE→ SEPSE / CHOQUE SÉPTICO            (🔴 Emergência)\n'
      '  AVCi → AVC ISQUÊMICO — trombólise se elegível (🔴 Emergência)\n'
      '  AVCh → AVC HEMORRÁGICO — controle PA urgente  (🔴 Emergência)\n'
      '  IC   → INSUFICIÊNCIA CARDÍACA            (🟠 Urgência) — NUNCA "Intensive Care"\n'
      '  ICC  → INSUFICIÊNCIA CARDÍACA CONGESTIVA (🟠 Urgência)\n'
      '  IRA  → INSUFICIÊNCIA RENAL AGUDA         (🟠 Urgência)\n'
      '  FA   → FIBRILAÇÃO ATRIAL                 (🟠 Urgência)\n'
      'Query com apenas sigla → 🟥 conduta imediata direto. NUNCA comentar idioma.\n';

  // ════════════════════════════════════════════════════════════════════════════
  // MÓDULO: plantao
  // Condutas de Sala Vermelha — Modo Emergencista Sênior.
  // Hierarquia: Caso A (conduta escalonada) / B (ampolas) / C (gotas).
  // ════════════════════════════════════════════════════════════════════════════
  static const String plantao =
      'Você está atuando como médico emergencista experiente. '
      'Responda de forma objetiva, prática e segura.\n'
      'Resposta cirúrgica. Dose + via + frequência. Sem textos acadêmicos.\n'
      'LIMITE FÍSICO: MÁXIMO 14 linhas de conteúdo (linhas em branco não contam).\n'
      'IGNORA COMPLETAMENTE: hierarquia didática, prosa acadêmica.\n'
      'PROIBIDO iniciar a resposta com: [, #, ##, MODO, PLANTÃO, SOBERANIA ou qualquer tag de sistema.\n'
      'NUNCA gere o caractere \'⚡\' nem linhas terminadas em \'>\'  na resposta.\n'
      '\n'
      'LAYOUT DE ESCANEAMENTO VERTICAL OBRIGATÓRIO:\n'
      'Sempre que houver mais de uma opção, conduta ou fármaco: QUEBRE A LINHA e use tópicos '
      'limpos com recuo. NUNCA coloque dois fármacos ou condutas na mesma linha sem separar '
      'por quebra de linha. TODOS os fármacos, doses e vias DEVEM estar em **negrito**.\n'
      '\n'
      'CASO A — CONDUTA CLÍNICA (manejo/tratamento): conduta ESCALONADA obrigatória:\n'
      '  🟥 [1ª opção — conservadora/entrada: **fármaco dose via freq**]\n'
      '  💊 [2ª opção — escalonamento/preventivo: **fármaco dose via**]\n'
      '  🔄B Sem a 1ª → **Substituto B dose via**\n'
      '  🔄C Contraindicação → **Substituto C dose via**\n'
      '  ⛔ [Alerta de segurança — 1 linha, omitir se não houver]\n'
      '  📌 [Monitorização em 1ª pessoa. PONTO FINAL.]\n'
      'NUNCA pule para droga de resgate sem citar manejo inicial.\n'
      '\n'
      'CASO B — DILUIÇÃO/AMPOLAS (MÁXIMO 6 linhas):\n'
      '  - Volume: Aspire X mL (Y ampolas).\n'
      '  - Diluição: Dilua em X mL de [Soro Fisiológico/Solución Salina].\n'
      '  - Infusão: Administrar a X mL/h por Y horas.\n'
      '\n'
      'CASO C — GOTEJAMENTO (EXATAMENTE 2 linhas):\n'
      '  Fórmula: (Volume mL / Tempo min) × Fator de gotejo\n'
      '  **Resultado: [X] gotas/min**\n'
      '\n'
      'TABELA: KCl 19,1% → 1 mL=2,5 mEq | KCl 10% → 1 mL=1,34 mEq\n'
      '        MgSO4 50% → 1 mL=0,4 g   | NaCl 20% → 1 mL=3,4 mEq\n';

  // ════════════════════════════════════════════════════════════════════════════
  // MÓDULO: estudo
  // Hierarquia didática de preceptor universitário — Modo Estudos.
  // Seções com contagem matemática exata de linhas por tipo.
  // ════════════════════════════════════════════════════════════════════════════
  static const String estudo =
      'Você está atuando como preceptor universitário sênior. '
      'Responda com prosa acadêmica densa, voz ativa e evidências nível 1.\n'
      'LIMITE FÍSICO: entre 6 e 30 linhas de conteúdo (linhas em branco não contam).\n'
      'IGNORA COMPLETAMENTE: templates flashcard, emojis 🟥/🔄B/🔄C, layout de Plantão.\n'
      'PROIBIDO iniciar a resposta com: [, #, ##, ###, MODO, ESTUDO, SOBERANIA ou qualquer tag de sistema.\n'
      'NUNCA gere o caractere \'⚡\' nem linhas terminadas em \'>\' na resposta de estudo.\n'
      'PRIMEIRO ELEMENTO obrigatório: **Nome do Tema** (em negrito puro). NUNCA ## ou 🟥.\n'
      '\n'
      'HIERARQUIA DIDÁTICA OBRIGATÓRIA (use negrito puro, sem ##):\n'
      '**[Título clínico específico]**\n'
      '**Definição:** [EXATAMENTE 1 linha — definição precisa e objetiva]\n'
      '**Fisiopatologia:** [LINHA 1 — pathway inicial | LINHA 2 — consequência]\n'
      '**Mecanismo de Ação** (se farmacológico): [LINHA 1 — alvo molecular | LINHA 2 — efeito]\n'
      '\n'
      'Rótulos adicionais permitidos (negrito puro apenas):\n'
      '**Indicações:** | **Diagnóstico:** | **Tratamento:** | **Contraindicações:**\n'
      '**Interações:** | **Efeitos adversos:** | **Pontos de prova:** | **Caso clínico:**\n'
      '📌 [Próximo passo em 1ª pessoa. PONTO FINAL. NUNCA "?"]\n'
      '\n'
      'REGRA DE OURO DO ESTUDO: Sem emojis clínicos (🟥/🔄B/⛔), sem layout de Plantão, '
      'sem headings ## ou ###, sem colchetes de sistema. '
      'Todo destaque visual DEVE ocorrer APENAS por Markdown bold (**Texto**).\n'
      'Citar guideline quando relevante. Jamais repetir conteúdo já explicado no histórico.\n';

  // ════════════════════════════════════════════════════════════════════════════
  // MÓDULO: dose
  // Regras de formatação de fármacos, doses e negrito obrigatório.
  // Injetado quando intent isDose=true.
  // ════════════════════════════════════════════════════════════════════════════
  static const String dose =
      '💊 REGRAS DE DOSE E FÁRMACOS:\n'
      'Sempre **NEGRITO MAIÚSCULAS** para fármaco + dose: **MORFINA 4 MG IV**.\n'
      'Nunca classes farmacológicas: proibido "Betabloqueador", "IECA" — use o NOME.\n'
      'Formato obrigatório: ✅ **NomeFármaco**: Dose via (frequência/carga).\n'
      'Para cada fármaco: indicação entre parênteses. Ex: ✅ **Metoprolol** (FC): 5 mg IV.\n'
      'Tratamento escalonado: 1ª escolha segura antes do resgate.\n';

  // ════════════════════════════════════════════════════════════════════════════
  // MÓDULO: diluicao
  // Regras de velocidade de infusão, gotejamento e preparo de ampolas.
  // Injetado quando intent isDilution=true.
  // ════════════════════════════════════════════════════════════════════════════
  static const String diluicao =
      '⚗️ REGRAS DE DILUIÇÃO E GOTEJAMENTO:\n'
      'Tripé obrigatório para ampolas: Volume → Diluição → Velocidade de infusão.\n'
      'Gotejamento: apenas Fórmula + **Resultado em negrito** (2 linhas exatas).\n'
      'Idioma dos termos de infusão:\n'
      '  PT: "Soro Fisiológico", "ampola", "correr em BIC", "mL/h"\n'
      '  ES: "Solución Salina", "ampolla", "administrar en BIC", "mL/h"\n'
      'Sempre confirme: volume total, concentração final e tempo de infusão.\n';

  // ════════════════════════════════════════════════════════════════════════════
  // MÓDULO: interacoes
  // Alertas de segurança, contraindicações absolutas e efeitos graves.
  // Injetado quando intent isInteraction=true.
  // ════════════════════════════════════════════════════════════════════════════
  static const String interacoes =
      '⛔ REGRAS DE INTERAÇÕES E SEGURANÇA:\n'
      'Contraindicações absolutas → ⛔ com texto claro em 1 linha.\n'
      'Interações graves → citar o mecanismo (QT, CYP3A4, plaquetas, etc.).\n'
      'Alertas renais/hepáticos → incluir limiar de clearance (ClCr < X mL/min).\n'
      'Risco de vida iminente → > 🔴 ALERTA CRÍTICO: [efeito fatal ou contraindicação abs]\n'
      'Priorizar segurança antes de eficácia na ordenação dos alertas.\n';

  // ════════════════════════════════════════════════════════════════════════════
  // _detectIntent — Detector de intenção por palavras-chave rápidas
  //
  // Análise léxica leve (sem RegEx) na user message.
  // Retorna IntentFlags com booleanos e label para log.
  // ════════════════════════════════════════════════════════════════════════════
  static IntentFlags _detectIntent(String userMessage) {
    final m = userMessage.toLowerCase();

    // isDose: pergunta sobre doses, fármaco, prescrição, mg
    final isDose = m.contains('dose') || m.contains('dosis') ||
        m.contains('dose de') || m.contains(' mg') || m.contains(' mcg') ||
        m.contains('prescrever') || m.contains('prescribir') ||
        m.contains('medicamento') || m.contains('fármaco') ||
        m.contains('farmacos') || m.contains('ampola') || m.contains('ampolla');

    // isDilution: pergunta sobre diluição, gotejamento, infusão
    final isDilution = m.contains('dilui') || m.contains('diluci') ||
        m.contains('gota') || m.contains('gote') ||
        m.contains('infus') || m.contains('bic') ||
        m.contains('ml/h') || m.contains('prepar') ||
        m.contains('gotejo') || m.contains('gotejamento');

    // isInteraction: pergunta sobre interações, contraindicações, efeitos
    final isInteraction = m.contains('interaç') || m.contains('interacci') ||
        m.contains('contraindicaç') || m.contains('contraindicaci') ||
        m.contains('efeito adverso') || m.contains('efecto adverso') ||
        m.contains('reação adversa') || m.contains('reacción adversa') ||
        m.contains('segurança') || m.contains('seguridad');

    // isAcronym: query de 1-6 chars que pode ser sigla médica
    final trimmed = userMessage.trim();
    final isAcronym = trimmed.length <= 6 &&
        RegExp(r'^[A-Za-zÀ-ÿ]+$').hasMatch(trimmed);

    // label para log (prioridade: dilution > dose > interaction > acronym > geral)
    final taskLabel = isDilution
        ? 'diluicao'
        : isDose
            ? 'dose'
            : isInteraction
                ? 'interacao'
                : isAcronym
                    ? 'sigla'
                    : 'geral';

    return IntentFlags(
      isDose: isDose,
      isDilution: isDilution,
      isInteraction: isInteraction,
      isAcronym: isAcronym,
      taskLabel: taskLabel,
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // _sanitizeExternalPrompt — Remove monolitos e âncoras duplicadas do RAG
  //
  // O systemPrompt externo (montado pelo AiService) contém contexto clínico
  // legítimo (RAG, seções clínicas do paciente, etc.) MAS pode carregar
  // resquícios de builds antigas: âncoras de modo duplicadas, mandatos, etc.
  //
  // DESCARTA (monolitos e resquícios):
  //   • Blocos [MODO PLANTÃO...] / [MODO ESTUDO...] duplicados
  //   • [MANDATO CRÍTICO...] / [INÍCIO DO CONTEXTO...] wrappers
  //   • [REFORÇO MANDATÓRIO...] / [SOBERANIA...] blocos
  //   • Strings de builds antigas ("Build 124", "IRREVOGÁVEL", "ANTI-ENCYCLOPEDIA")
  //
  // PRESERVA INTENCIONALMENTE:
  //   • [TRAVA DE IDIOMA...] → bloco legítimo injetado pelo ai_gateway_service.dart
  //     via _buildLanguageLock(). Remove-lo aqui quebraria o Language Lock (Pilar 3).
  //   • Todo texto clínico que NÃO seja metadado de sistema.
  //
  // ARQUITETURA (Build 231):
  //   ai_gateway_service.dart injeta languageLock → finalSystemPrompt
  //   PromptModules.build() recebe systemPrompt (que contém languageLock)
  //   _sanitizeExternalPrompt() preserva [TRAVA DE IDIOMA...] intacto
  //   resultado: langLock flui até o Gemini como última instrução (Recency Bias)
  // ════════════════════════════════════════════════════════════════════════════
  static String _sanitizeExternalPrompt(String raw) {
    if (raw.isEmpty) return '';
    String s = raw;

    // Remove blocos de âncora de modo (colchete + conteúdo até fechamento)
    // NOTA: TRAVA DE IDIOMA foi removida intencionalmente desta regex (Build 231)
    s = s.replaceAll(
      RegExp(
        r'\[(?:MODO\s+PLANT[ÃA]O|MODO\s+ESTUDO|MANDATO\s+CR[IÍ]TICO|'
        r'MANDATO\s+DE\s+INTENT|'
        r'IN[IÍ]CIO\s+DO\s+CONTEXTO|REFOR[ÇC]O\s+MANDAT[ÓO]RIO|'
        r'SOBERANIA|MONOP[ÓO]LIO\s+DE\s+SA[IÍ]DA)[^\]]{0,3000}\]',
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );

    // Remove linhas que começam com cabeçalhos de âncora em texto plano
    // NOTA: \[TRAVA removido intencionalmente — preservar Language Lock (Build 231)
    s = s.replaceAll(
      RegExp(
        r'^(?:\[MODO\s+PLANT[ÃA]O|\[MODO\s+ESTUDO|\[MANDATO|\[REFOR[ÇC]O'
        r'|\[IN[IÍ]CIO\s+DO\s+CONTEXTO'
        r'|CRITICAL\s+IDENTITY\s+\(Build'
        r'|ANTI-ENCYCLOPEDIA\s+RULE'
        r'|YOUR\s+ONLY\s+OUTPUT\s+is\s+drug).*$',
        caseSensitive: false,
        multiLine: true,
      ),
      '',
    );

    // Remove referências explícitas a builds antigas que criam conflito
    s = s.replaceAll(
      RegExp(r'Build\s+1[0-2]\d\s*[—\-–]?\s*IRREVOG[ÁA]VEL', caseSensitive: false),
      '',
    );

    return s.trim();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // build — Método principal de montagem dinâmica do prompt final
  //
  // Fluxo:
  //   1. Detecta intenção na userMessage (isDose / isDilution / etc.)
  //   2. Sanitiza o systemPrompt externo (remove monolitos)
  //   3. Seleciona e concatena módulos por modo + intenção
  //   4. Aplica language lock (última instrução — Viés de Recência)
  //   5. Verifica limite de 8000 chars; descarta módulos não-essenciais se exceder
  //   6. Loga tamanhos para diagnóstico de latência
  //
  // Parâmetros:
  //   userMessage     → mensagem atual do usuário (para detecção de intenção)
  //   systemPrompt    → contexto RAG/clínico externo do AiService
  //   isPlantaoMode   → true = Plantão / false = Estudo
  //   languageLock    → bloco de trava PT/ES já montado pelo ai_gateway_service
  //
  // Retorna:
  //   String → system_instruction final pronta para envio ao Gemini
  // ════════════════════════════════════════════════════════════════════════════
  static String build({
    required String userMessage,
    required String systemPrompt,
    required bool isPlantaoMode,
    String languageLock = '',
  }) {
    // ── 1. Detectar intenção ────────────────────────────────────────────────
    final intent = _detectIntent(userMessage);

    // ── 2. Sanitizar contexto externo ───────────────────────────────────────
    final cleanContext = _sanitizeExternalPrompt(systemPrompt);

    // ── 3. Selecionar módulos base ──────────────────────────────────────────
    final modeModule = isPlantaoMode ? plantao : estudo;

    // ── 4. Selecionar módulos de tarefa (apenas os relevantes para o turno) ─
    final taskModules = StringBuffer();
    if (intent.isDilution) taskModules.write('\n$diluicao');
    if (intent.isDose && !intent.isDilution) taskModules.write('\n$dose');
    if (intent.isInteraction) taskModules.write('\n$interacoes');
    if (intent.isAcronym) taskModules.write('\n$siglasCriticas');

    // Siglas críticas também no Plantão quando não é sigla isolada
    // (garante mapeamento correto de IAM/SCA mesmo em perguntas compostas)
    if (!intent.isAcronym && isPlantaoMode) {
      taskModules.write('\n$siglasCriticas');
    }

    // ── 5. Montar prompt candidato ──────────────────────────────────────────
    final contextSection = cleanContext.isNotEmpty
        ? '\n\n[CONTEXTO CLÍNICO RAG]\n$cleanContext'
        : '';

    final langSection = languageLock.isNotEmpty ? '\n$languageLock' : '';

    String candidate = core
        + '\n'
        + antiLeak
        + '\n'
        + uiContract
        + '\n'
        + modeModule
        + taskModules.toString()
        + contextSection
        + langSection;

    // ── 6. Guardrail de tamanho: 8000 chars máximo ──────────────────────────
    // Se exceder (anomalia de histórico/RAG muito longo), descarta módulos
    // não-essenciais nesta ordem: siglasCriticas, uiContract, módulos de tarefa.
    if (candidate.length > 8000) {
      // Context truncado a 2000 chars para caber no guardrail
      final truncatedContext = cleanContext.length > 2000
          ? '\n\n[CONTEXTO CLÍNICO RAG]\n${cleanContext.substring(0, 2000)}...'
          : contextSection;

      candidate = core
          + '\n'
          + antiLeak
          + '\n'
          + modeModule
          + (intent.isDilution ? '\n$diluicao' : '')
          + (intent.isDose && !intent.isDilution ? '\n$dose' : '')
          + truncatedContext
          + langSection;

      if (kDebugMode || _kPromptSizeAudit) {
        debugPrint('[AI_PROMPT_SIZE] ⚠️ GUARDRAIL: prompt excedeu 8000 chars → módulos não-essenciais descartados');
      }
    }

    // ── 7. Log de diagnóstico (Build 232: PM_SIZE audit sempre visível) ──────
    if (kDebugMode || _kPromptSizeAudit) {
      final modeLabel = isPlantaoMode ? 'plantao' : 'estudo';

      debugPrint('[PM_SIZE] ══════════════════════════════════════');
      debugPrint('[PM_SIZE] incomingSystemPrompt=${systemPrompt.length} chars');
      debugPrint('[PM_SIZE] cleanContextAfterSanitize=${cleanContext.length} chars');
      debugPrint('[PM_SIZE] core=${core.length} chars');
      debugPrint('[PM_SIZE] antiLeak=${antiLeak.length} chars');
      debugPrint('[PM_SIZE] uiContract=${uiContract.length} chars');
      debugPrint('[PM_SIZE] modeModule($modeLabel)=${modeModule.length} chars');
      debugPrint('[PM_SIZE] taskModules(${intent.taskLabel})=${taskModules.length} chars');
      debugPrint('[PM_SIZE] contextSection=${contextSection.length} chars');
      debugPrint('[PM_SIZE] languageLock(param)=${languageLock.length} chars');
      debugPrint('[PM_SIZE] finalPromptToGemini=${candidate.length} chars');
      debugPrint('[PM_TASK] dose=${intent.isDose} diluicao=${intent.isDilution} interacao=${intent.isInteraction} sigla=${intent.isAcronym}');
      debugPrint('[PM_MODE] $modeLabel');
      debugPrint('[PM_SIZE] ══════════════════════════════════════');

      // Logs legados (kDebugMode only)
      if (kDebugMode) {
        debugPrint('[AI_PROMPT_SIZE] core=${core.length}c antiLeak=${antiLeak.length}c ui=${uiContract.length}c mode($modeLabel)=${modeModule.length}c task(${intent.taskLabel})=${taskModules.length}c ctx=${contextSection.length}c lang=${languageLock.length}c total=${candidate.length}c');
        debugPrint('[AI_MODE] ${modeLabel.toUpperCase()}');
        debugPrint('[AI_TASK] ${intent.taskLabel}');
      }
    }

    return candidate;
  }
}
