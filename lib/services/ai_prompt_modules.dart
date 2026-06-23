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
      'OBRIGATORIEDADE DE NEGRITO EM FÁRMACOS E DOSES: Toda e qualquer menção a medicamentos, '
      'princípios ativos, dosagens (ex: 300mg, 30mg), vias de administração '
      '(ex: VO, IV, SC, IM) e esquemas posológicos DEVE ser formatada obrigatoriamente '
      'em negrito puro usando a sintaxe Markdown de asteriscos duplos. '
      'Exemplos: **AAS 300mg VO**, **Tenecteplase 30mg IV em bolus**, **Enoxaparina 1mg/kg SC 12/12h**. '
      'Isso se aplica a AMBOS OS MODOS (Plantão e Estudo) de forma incondicional. '
      'Nunca escreva dose ou fármaco sem o wrap **...** ao redor.\n'
      'RESTRIÇÃO DE DESTAQUE VISUAL: É terminantemente proibido aplicar negrito (**...**) '
      'em linhas inteiras, frases explicativas ou tópicos completos. '
      'O wrap de asteriscos duplos deve ser aplicado EXCLUSIVAMENTE sobre: '
      'nomes de fármacos de primeira linha, suas dosagens, vias de administração '
      '(ex: **AAS 300mg VO**) e condutas imediatas cruciais (ex: **Angioplastia Primária**). '
      'Textos de apoio, explicações fisiopatológicas, monitorizações e frases secundárias '
      'devem permanecer obrigatoriamente em texto plano, sem formatação de negrito.\n'
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
      // PERSONALIDADE: Médico emergencista de Sala Vermelha — checklist de emergência.
      // PROIBIDO: texto corrido, prosa acadêmica, headings ##, misturar condutas na mesma linha.
      // OBRIGATÓRIO: tópicos estruturados com recuo (-), negrito em TODO fármaco/dose/via.
      'Você é um médico emergencista de Sala Vermelha. '
      'Sua única missão: conduta rápida, precisa e escaneável.\n'
      'TETO ABSOLUTO: 14 linhas de conteúdo (linhas em branco não contam).\n'
      'PROIBIDO: texto corrido, dois fármacos na mesma linha, prosa acadêmica, '
      'headings ##, tags de sistema, caractere \'⚡\', linhas terminadas em \'>\'.\n'
      '\n'
      'PERSONALIDADE DE SAÍDA — ESCANEAMENTO VERTICAL OBRIGATÓRIO:\n'
      'Cada opção, conduta ou fármaco = 1 linha própria com recuo de traço (-).\n'
      'NEGRITO EXCLUSIVO: aplique **negrito** APENAS no nome do fármaco + dose + via. '
      'Texto de apoio, condições entre parênteses, monitorizações e alertas = texto plano.\n'
      '\n'
      'ESTRUTURA MANDATÓRIA (CASO A — CONDUTA):\n'
      '  🟥 1ª Opção: [título curto]\n'
      '  - **Fármaco dose via freq**\n'
      '  - **Fármaco alternativo dose via** (condição)\n'
      '  💊 2ª Opção: [título curto]\n'
      '  - **Fármaco dose via**\n'
      '  - **Fármaco complementar dose via**\n'
      '  🔄B Sem 1ª → **Substituto B dose via**\n'
      '  🔄C Contraindicação → **Substituto C dose via**\n'
      '  ⛔ [Alerta de segurança — 1 linha, omitir se não houver]\n'
      '  📌 [Monitorização em 1ª pessoa. PONTO FINAL.]\n'
      'NUNCA pule para droga de resgate sem citar manejo inicial.\n'
      '\n'
      'CASO B — DILUIÇÃO/AMPOLAS (MÁXIMO 6 linhas):\n'
      '  - Volume: Aspire **X mL (Y ampolas)**.\n'
      '  - Diluição: Dilua em **X mL** de [Soro Fisiológico/Solución Salina].\n'
      '  - Infusão: Administrar a **X mL/h** por Y horas.\n'
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
  // Teto de 40 linhas: proteção de TPM em contas gratuitas (Build 1557).
  // ════════════════════════════════════════════════════════════════════════════
  static const String estudo =
      // PERSONALIDADE: Enciclopédia Médica Estruturada — tratado acadêmico de alta escaneabilidade.
      // PROIBIDO: ## headings, emojis de Plantão (🟥/🔄B/⛔), texto sem estrutura de pilares.
      // OBRIGATÓRIO: 4 pilares iniciais em negrito puro, bullet points, negrito isolado.
      '[CONTRATO DE SEGUIMENTO E SEGUNDA INTERAÇÃO]\n'
      'Se a mensagem do usuário for um desdobramento ou clique de botão dinâmico:\n'
      '1. Proibido renderizar os 4 pilares estruturais macros (Definição, Fisiopatologia, etc.).\n'
      '2. Responda DIRETAMENTE ao questionamento, sem introduções.\n'
      '3. TETO MÁXIMO DE SEGUIMENTO: Limite a resposta a no máximo 12 a 15 linhas.\n'
      '\n'
      'Você é um tratado médico acadêmico aprofundado e denso, projetado para alta escaneabilidade. '
      'Responda com rigor científico, voz ativa e evidências nível 1.\n'
      'TETO ABSOLUTO: 26 linhas de conteúdo (linhas em branco não contam).\n'
      'PROIBIDO: ## headings, emojis de Plantão (🟥/🔄B/⛔/💊), texto corrido sem estrutura, '
      'tags de sistema, caractere \'⚡\', linhas terminadas em \'>\'.\n'
      'NUNCA misture a estrutura visual do Modo Plantão neste modo.\n'
      '\n'
      'ESTRUTURA OBRIGATÓRIA — 4 PILARES INICIAIS (sempre presentes, nesta ordem):\n'
      '**[Título clínico específico do tema]**\n'
      '\n'
      '**DEFINIÇÃO**\n'
      '[Texto dissertativo preciso — 1 a 3 linhas. Texto plano, sem negrito em frases.]\n'
      '\n'
      '**FISIOPATO/ETIOLOGIA**\n'
      '[Texto dissertativo — pathway, mecanismo, causa raiz. Texto plano.]\n'
      '\n'
      '**QUADRO CLÍNICO**\n'
      '[Sinais, sintomas e achados — use bullet points (-) para ≥2 itens. Texto plano.]\n'
      '\n'
      '**TRATAMENTO**\n'
      '[Conduta em bullet points (-). Apenas **fármaco + dose + via** em negrito. '
      'Explicações e condições = texto plano.]\n'
      '\n'
      'SEÇÕES COMPLEMENTARES (usar conforme pertinência da pergunta):\n'
      'Toda informação complementar deve vir em tópicos/bullet points claros (-). '
      'NEGRITO EXCLUSIVO: aplique **negrito** apenas em nomes de fármacos, doses, '
      'critérios de guideline e condutas imediatas. '
      'Frases explicativas, fisiopatologia e monitorização = texto plano obrigatório.\n'
      'Rótulos adicionais permitidos (negrito puro):\n'
      '**Diagnóstico:** | **Contraindicações:** | **Interações:** | **Efeitos adversos:**\n'
      '**Pontos de prova:** | **Caso clínico:** | **Mecanismo de Ação:**\n'
      '📌 [Próximo passo em 1ª pessoa. PONTO FINAL. NUNCA "?"]\n'
      '\n'
      'REGRA DE OURO DO ESTUDO: Negrito APENAS em fármacos, doses e termos diagnósticos chave. '
      'Frases inteiras, tópicos completos e explicações = texto plano sem formatação. '
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

    // ── 6. Guardrail de tamanho — Build 1556: PRIORIDADE DE DESCARTE INVERTIDA ─
    //
    // REGRA ABSOLUTA (Code Freeze):
    //   NUNCA descartar: core, antiLeak, uiContract, modeModule (plantao/estudo),
    //   taskModules (dose/diluicao/interacoes), langSection.
    //   Esses módulos definem o comportamento estrutural do app — sem eles a IA
    //   perde diretrizes e devolve uma única linha vazia para qualquer query.
    //
    // ORDEM DE TRUNCAMENTO (contextSection é a única variável em tamanho):
    //   PASSO 1: Truncar contextSection progressivamente (48k → 4000 → 2000 → 0).
    //   PASSO 2: Só se ainda exceder após contextSection=0, remover siglasCriticas
    //            do taskModules (módulo menos crítico para conduta).
    //   PASSO 3: Módulos estruturais (core/antiLeak/uiContract/modeModule) são INTOCÁVEIS.
    //
    // Motivação: contextSection é o único componente que pode crescer sem limite
    // (RAG clínico pode chegar a 48k chars). Os módulos de instrução são < 6k chars total.
    if (candidate.length > 8000) {
      // Calcular orçamento disponível para o contexto RAG
      final structuralBase = core.length
          + 1  // '\n'
          + antiLeak.length
          + 1  // '\n'
          + uiContract.length
          + 1  // '\n'
          + modeModule.length
          + taskModules.length
          + langSection.length;

      // Budget restante para contextSection (mínimo 0)
      final ctxBudget = (8000 - structuralBase).clamp(0, 8000);

      String truncatedContext;
      if (ctxBudget == 0) {
        // Nenhum espaço para contexto RAG — descarta contextSection por completo
        truncatedContext = '';
        if (kDebugMode || _kPromptSizeAudit) {
          debugPrint('[AI_PROMPT_SIZE] ⚠️ GUARDRAIL L3: contextSection=0 (structural modules preserved)');
        }
      } else if (cleanContext.length > ctxBudget) {
        // Trunca contextSection ao budget disponível — módulos estruturais intactos
        truncatedContext = '\n\n[CONTEXTO CLÍNICO RAG — TRUNCADO]\n'
            '${cleanContext.substring(0, ctxBudget)}...';
        if (kDebugMode || _kPromptSizeAudit) {
          debugPrint('[AI_PROMPT_SIZE] ⚠️ GUARDRAIL L1: contextSection truncado '
              '${cleanContext.length}→$ctxBudget chars | core+modeModule INTACTOS');
        }
      } else {
        truncatedContext = contextSection;
      }

      // Remontar com módulos estruturais 100% preservados
      candidate = core
          + '\n'
          + antiLeak
          + '\n'
          + uiContract
          + '\n'
          + modeModule
          + taskModules.toString()   // dose/diluicao/interacoes/siglas — intactos
          + truncatedContext
          + langSection;

      if (kDebugMode || _kPromptSizeAudit) {
        debugPrint('[AI_PROMPT_SIZE] ⚠️ GUARDRAIL ATIVADO: '
            'original=${candidate.length} chars | '
            'core=${core.length} | modeModule=${modeModule.length} | '
            'taskModules=${taskModules.length} | '
            'ctxBudget=$ctxBudget | resultado=${candidate.length} chars');
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
