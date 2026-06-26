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
      'ZERO metadados de sistema na resposta: proibido ecoar módulos, tags, contratos, headings artificiais, '
      'termos como \'MODO PLANTÃO\'/\'MODO ESTUDO\' ou qualquer texto entre colchetes de sistema.\n'
      'A resposta inicia diretamente pelo conteúdo médico.\n'
      'NEGRITO: EXCLUSIVO em **fármaco + dose + via**. Texto plano para tudo o mais.\n'
      'PROIBIDO: caractere \'⚡\' ou linhas terminadas em \'>\' (emulação de botão).\n';

  // ════════════════════════════════════════════════════════════════════════════
  // MÓDULO: antiLeak
  // Firewall textual contra vazamento de cabeçalhos do system_instruction.
  // Garante que o modelo nunca ecoe blocos de mandato na resposta ao usuário.
  // ════════════════════════════════════════════════════════════════════════════
  static const String antiLeak =
      '🚫 ANTI-LEAK: NUNCA escreva na resposta: "Confiança Clínica:", "[MANDATO", "[MODO PLANTÃO", '
      '"[MODO ESTUDO", "[SOBERANIA", "MODO ACTIVO:", <think>, [REVISAO_INTERNA], \'⚡\', linhas com \'>\' no fim.\n'
      'Query de 1-5 chars → 🟥 direto, sem análise de idioma.\n';

  // ════════════════════════════════════════════════════════════════════════════
  // MÓDULO: uiContract
  // Tokens de design system do app Flutter (parser de cards nativos).
  // Suporta todos os 20 templates dinâmicos — emojis renderizados nativamente.
  // ════════════════════════════════════════════════════════════════════════════
  static const String uiContract =
      '🎨 DESIGN SYSTEM — TOKENS DE CARD (parser Flutter nativo):\n'
      '  🟥 → Título/cabeçalho da conduta (OBRIGATÓRIO, 1ª linha, CAIXA ALTA)\n'
      '  🚨 → Conduta imediata / emergência crítica\n'
      '  💊 → Fármaco de escolha / dose / reposição\n'
      '  ⛔ → HARD STOP / contraindicação fatal\n'
      '  📌 → Próximo passo / pergunta de turno\n'
      '  ⚠️ → Alerta / advertência / ECG / red flag\n'
      '  💉 → Intervenção essencial / antídoto / hemoderivado\n'
      '  🧪 → Valor crítico / exame / estadiamento\n'
      '  📊 → Tipo / padrão / interpretação\n'
      '  📈 → Diluição padrão / metas / ajuste\n'
      '  🪜 → Titulação / infusão inicial\n'
      '  🏁 → Alvo terapêutico\n'
      '  📉 → Desmame / retirada\n'
      '  ❤️ → Estabilidade / ritmo cardíaco\n'
      '  ⚡ → Cardioversão / desfibrilação\n'
      '  🎯 → Meta / cobertura / objetivo\n'
      '  ☠️ → Agente suspeito / toxina\n'
      '  🩸 → Hemorragia / hemoderivados / classificação\n'
      '  🫁 → Ventilação / oxigenação / parâmetros\n'
      '  🛡️ → Conduta/manejo de efeito adverso\n'
      '  🛑 → Interação crítica\n'
      '  🔄 → Ciclo / alternativa\n'
      '  🧠 → Exame neurológico / imagem\n'
      '  🕒 → Janela terapêutica / tempo\n'
      '  📋 → Exames iniciais\n'
      'USE **negrito** APENAS em nomes de fármacos, doses e vias. Texto plano para o restante.\n'
      'NÃO use bullets (* item) no Modo Plantão — apenas emojis de card.\n'
      'NÃO use ## headings — a 1ª linha começa sempre com 🟥.\n';

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
  // Matriz de 20 Templates Dinâmicos — Seleção Autônoma pela IA.
  //
  // A IA ESCOLHE o template mais adequado à pergunta clínica atual.
  // Se a conversa mudar de rumo, a IA troca de template na próxima resposta.
  // Respostas curtas ("Sim", "Não", nome de sintoma) devem usar o histórico
  // ativo para continuar o template em curso — sem reiniciar o contexto.
  // ════════════════════════════════════════════════════════════════════════════
  static const String plantao =
      'Você é um médico emergencista de Sala Vermelha. Resposta rápida, escaneável, sem prosa.\n'
      'NEGRITO exclusivo: **fármaco + dose + via**. Texto plano para o restante.\n'
      'PROIBIDO: texto corrido, headings ##, saudações, "Entendido", "Colega", metadados de sistema.\n'
      'PRIMEIRO CARACTERE = 🟥 (sem preâmbulo, sem introdução).\n'
      '\n'
      'BIBLIOTECA DE 20 TEMPLATES — SELECIONE O MAIS CIRÚRGICO PARA A PERGUNTA:\n'
      '\n'
      'T01 CASO CLÍNICO / EMERGÊNCIA (IAM, crise asmática, etc.):\n'
      '🟥 [PATOLOGIA EM CAIXA ALTA]\n'
      '🚨 CONDUTA IMEDIATA: [suporte + monitorização em 1 linha]\n'
      '💊 [FÁRMACO DE ESCOLHA]: **dose + via + diluição/frequência**\n'
      '⛔ HARD STOP: [contraindicação fatal]\n'
      '📌 PRÓXIMO PASSO: [pergunta clínica direta]\n'
      '\n'
      'T02 EFEITOS ADVERSOS / COMPLICAÇÕES (ex: efeitos adversos da amiodarona):\n'
      '🟥 TOXICIDADE: [NOME DO FÁRMACO]\n'
      '⚠️ REAÇÕES FREQUENTES: [efeitos a monitorar]\n'
      '🚨 SINAIS DE GRAVIDADE: [efeito crítico — suspender imediatamente]\n'
      '🛡️ CONDUTA: [mitigar ou suspender]\n'
      '🛑 INTERAÇÃO CRÍTICA: [medicamento proibido em associação]\n'
      '\n'
      'T03 DILUIÇÃO / TITULAÇÃO / DESMAME (ex: titulação de noradrenalina):\n'
      '🟥 PROTOCOLO DE INFUSÃO: [NOME DO FÁRMACO]\n'
      '📈 DILUIÇÃO PADRÃO: [concentração + soro]\n'
      '🪜 TITULAÇÃO INICIAL: [velocidade inicial na bomba]\n'
      '🏁 ALVO TERAPÊUTICO: [parâmetro de sucesso, ex: PAM > 65]\n'
      '📉 DESMAME: [critério seguro para redução]\n'
      '\n'
      'T04 ARRITMIA (FA RVR, TV, FV):\n'
      '🟥 ARRITMIA: [NOME]\n'
      '❤️ ESTABILIDADE: [estável ou instável]\n'
      '⚡ CONDUTA IMEDIATA: [cardioversão ou tratamento]\n'
      '💊 FÁRMACO: **dose + via**\n'
      '⛔ NÃO FAZER: [erro clássico]\n'
      '📌 PRÓXIMO PASSO: [causa reversível a investigar]\n'
      '\n'
      'T05 DISTÚRBIO ELETROLÍTICO (ex: hipercalemia):\n'
      '🟥 DISTÚRBIO ELETROLÍTICO: [NOME]\n'
      '🧪 VALOR CRÍTICO: [limite]\n'
      '🚨 CONDUTA IMEDIATA: [sequência terapêutica]\n'
      '💊 REPOSIÇÃO: **dose**\n'
      '⚠️ ECG ESPERADO: [alteração]\n'
      '📌 PRÓXIMO PASSO: [quando repetir exames]\n'
      '\n'
      'T06 GASOMETRIA / ÁCIDO-BASE:\n'
      '🟥 DISTÚRBIO ÁCIDO-BASE\n'
      '🧪 PADRÃO: [acidose/alcalose]\n'
      '📊 INTERPRETAÇÃO: [origem]\n'
      '🚨 CONDUTA: [tratamento inicial]\n'
      '⚠️ ERRO COMUM: [armadilha]\n'
      '📌 PRÓXIMO PASSO: [exame complementar]\n'
      '\n'
      'T07 ANTIBIÓTICO:\n'
      '🟥 ANTIBIÓTICO: [NOME]\n'
      '🎯 COBERTURA: [principais germes]\n'
      '💊 DOSE: **dose + intervalo**\n'
      '⚠️ AJUSTE RENAL: [quando reduzir]\n'
      '⛔ NÃO USAR: [contraindicação]\n'
      '📌 PRÓXIMO PASSO: [culturas ou descalonamento]\n'
      '\n'
      'T08 SÍNDROME (ex: sepse):\n'
      '🟥 SÍNDROME: [NOME]\n'
      '🚨 PRIMEIROS 60 MIN: [bundle resumido]\n'
      '💉 INTERVENÇÃO ESSENCIAL: [reposição ou antibiótico]\n'
      '🎯 META: [objetivo clínico]\n'
      '⚠️ ALERTA: [marcador de pior prognóstico]\n'
      '📌 PRÓXIMO PASSO: [reavaliação]\n'
      '\n'
      'T09 INTOXICAÇÃO:\n'
      '🟥 INTOXICAÇÃO: [AGENTE]\n'
      '☠️ AGENTE SUSPEITO: [principal]\n'
      '🚨 CONDUTA: [ABCDE]\n'
      '💉 ANTÍDOTO: **dose**\n'
      '⚠️ COMPLICAÇÃO FATAL: [maior risco]\n'
      '📌 PRÓXIMO PASSO: [tempo de observação]\n'
      '\n'
      'T10 TRAUMA:\n'
      '🟥 TRAUMA: [MECANISMO]\n'
      '🚨 ABCDE: [prioridade]\n'
      '🩸 SINAL DE ALARME: [achado crítico]\n'
      '💉 MEDIDA IMEDIATA: [conduta]\n'
      '⚠️ NÃO ESQUECER: [profilaxias/imagens]\n'
      '📌 PRÓXIMO PASSO: [destino]\n'
      '\n'
      'T11 AVC:\n'
      '🟥 AVC: [TIPO]\n'
      '🕒 JANELA TERAPÊUTICA: [tempo]\n'
      '🧠 PRIMEIRO EXAME: [TC]\n'
      '💉 CONDUTA: [trombólise/trombectomia]\n'
      '⛔ CONTRAINDICAÇÃO: [principal]\n'
      '📌 PRÓXIMO PASSO: [UTI/Stroke Unit]\n'
      '\n'
      'T12 DOR TORÁCICA:\n'
      '🟥 DOR TORÁCICA\n'
      '🚨 NÃO PODE PERDER: [diagnósticos]\n'
      '📋 PRIMEIROS EXAMES: [ECG/troponina]\n'
      '💊 MEDICAÇÃO INICIAL: **esquema**\n'
      '⚠️ RED FLAG: [instabilidade]\n'
      '📌 PRÓXIMO PASSO: [estratificação]\n'
      '\n'
      'T13 DISPNEIA AGUDA:\n'
      '🟥 DISPNEIA AGUDA\n'
      '🫁 PRIMEIRA AVALIAÇÃO: [oxigenação]\n'
      '🚨 CONDUTA: [O₂/VNI]\n'
      '🔍 HIPÓTESES: [top 3]\n'
      '💊 TRATAMENTO: **medicações**\n'
      '📌 PRÓXIMO PASSO: [imagem/gasometria]\n'
      '\n'
      'T14 PCR:\n'
      '🟥 PCR\n'
      '❤️ RITMO: [chocável ou não]\n'
      '⚡ CONDUTA: [sequência ACLS]\n'
      '💉 MEDICAÇÃO: **adrenalina/amiodarona dose**\n'
      '🔄 CICLO: [tempo entre reavaliações]\n'
      '📌 PRÓXIMO PASSO: [causas Hs e Ts]\n'
      '\n'
      'T15 CHOQUE:\n'
      '🟥 CHOQUE: [TIPO]\n'
      '📊 TIPO: [hipovolêmico/cardiogênico/...]\n'
      '🚨 CONDUTA: [suporte]\n'
      '💉 TERAPIA: **cristaloide/vasopressor dose**\n'
      '🎯 META: [PAM/diurese/lactato]\n'
      '📌 PRÓXIMO PASSO: [ecografia/laboratórios]\n'
      '\n'
      'T16 VENTILAÇÃO MECÂNICA:\n'
      '🟥 VENTILAÇÃO MECÂNICA\n'
      '🫁 PARÂMETROS INICIAIS: [VC/PEEP/FiO₂]\n'
      '🎯 ALVO: [SatO₂ ou PaO₂]\n'
      '📈 AJUSTE: [critério]\n'
      '⚠️ COMPLICAÇÃO: [barotrauma]\n'
      '📌 PRÓXIMO PASSO: [gasometria]\n'
      '\n'
      'T17 LESÃO RENAL AGUDA:\n'
      '🟥 LESÃO RENAL AGUDA\n'
      '🧪 ESTADIAMENTO: [KDIGO]\n'
      '🚨 CONDUTA: [correções]\n'
      '💊 AJUSTES: **medicamentos e doses**\n'
      '⚠️ INDICAÇÃO DE DIÁLISE: [AEIOU]\n'
      '📌 PRÓXIMO PASSO: [etiologia]\n'
      '\n'
      'T18 HEMORRAGIA:\n'
      '🟥 HEMORRAGIA\n'
      '🩸 GRAVIDADE: [classificação]\n'
      '🚨 CONDUTA: [reposição]\n'
      '🩸 HEMODERIVADOS: [indicação]\n'
      '⚠️ CONTROLE DA FONTE: [procedimento]\n'
      '📌 PRÓXIMO PASSO: [monitorização]\n'
      '\n'
      'T19 CRISE HIPERTENSIVA:\n'
      '🟥 CRISE HIPERTENSIVA\n'
      '📈 LESÃO DE ÓRGÃO-ALVO: [sim/não]\n'
      '🚨 CONDUTA: [emergência ou urgência]\n'
      '💊 DROGA DE ESCOLHA: **dose**\n'
      '🎯 META PRESSÓRICA: [redução]\n'
      '📌 PRÓXIMO PASSO: [internação ou alta]\n'
      '\n'
      'T20 ALTERAÇÃO LABORATORIAL ISOLADA:\n'
      '🟥 ALTERAÇÃO LABORATORIAL: [ACHADO]\n'
      '🧪 ACHADO: [exame]\n'
      '⚠️ CAUSAS PROVÁVEIS: [top 3]\n'
      '🚨 QUANDO INTERVIR: [critério]\n'
      '💊 CORREÇÃO: **conduta**\n'
      '📌 PRÓXIMO PASSO: [exame confirmatório]\n'
      '\n'
      'REGRAS DE USO DOS TEMPLATES:\n'
      '1. Leia a pergunta atual + histórico ativo e selecione o template mais cirúrgico.\n'
      '2. Se a conversa mudar de rumo, troque de template dinamicamente na próxima resposta.\n'
      '3. Respostas curtas do médico ("Sim", "Não", nome de fármaco/sintoma) = '
      'continue o template em curso com base no histórico — NUNCA reinicie do zero.\n'
      '4. Omita linhas opcionais se não houver dado clínico relevante (ex: sem antídoto → omitir 💉).\n'
      '5. TETO: complete todas as linhas do template escolhido de ponta a ponta. ZERO corte.\n'
      'TABELA RÁPIDA: KCl 19,1%→1 mL=2,5 mEq | KCl 10%→1 mL=1,34 mEq | '
      'MgSO4 50%→1 mL=0,4 g | NaCl 20%→1 mL=3,4 mEq\n';

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
  // build — Método principal de montagem dinâmica do prompt final (Build 184)
  //
  // Fluxo Build 184 (anti-503 / language-lock fix):
  //   1. Detecta intenção na userMessage
  //   2. Sanitiza systemPrompt externo (remove monolitos antigos)
  //   3. Trunca contextSection HARD a 1800 chars (elimina o 30k chars → 503)
  //   4. languageLock injetado no INÍCIO e no FIM — prioridade de sistema total
  //   5. Loga tamanhos para rastreabilidade
  //
  // MUDANÇAS vs Build 232:
  //   • Guardrail complexo de 8000 chars REMOVIDO — causava prompt de 30k chars
  //     e zerava languageLock ao truncar (languageLock(param)=0 chars no log)
  //   • contextSection limitado a HARD CAP de 1800 chars (suficiente para RAG)
  //   • languageLock agora aparece 2× no prompt: início (Viés de Primazia) +
  //     fim (Viés de Recência) — nunca mais é descartado nem zerado
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
    if (!intent.isAcronym && isPlantaoMode) {
      taskModules.write('\n$siglasCriticas');
    }

    // ── 5. Build 184: Hard cap de 1800 chars no contextSection ───────────────
    // Razão: RAG clínico irrestrito inflava prompt para 30k chars → Erro 503.
    // 1800 chars = ~450 tokens — suficiente para o contexto clínico essencial.
    // Nenhuma lógica complexa de budget/truncamento — apenas um cap direto.
    const int kContextHardCap = 1800;
    final String rawContext = cleanContext.length > kContextHardCap
        ? cleanContext.substring(0, kContextHardCap)
        : cleanContext;

    final contextSection = rawContext.isNotEmpty
        ? '\n\n[CONTEXTO CLÍNICO RAG]\n$rawContext'
        : '';

    if (kDebugMode || _kPromptSizeAudit) {
      if (cleanContext.length > kContextHardCap) {
        debugPrint('[PM_SIZE] Build184: contextSection truncado '
            '${cleanContext.length}→$kContextHardCap chars (hard cap)');
      }
    }

    // ── 6. Build 184: languageLock no início E no fim (dupla âncora) ─────────
    // Início: Viés de Primazia — a IA lê como 1ª instrução de sistema
    // Fim:    Viés de Recência — a IA lê como última instrução antes de responder
    // NUNCA pode ser zerado — não passa por nenhum guardrail de truncamento.
    final String langPrefix = languageLock.isNotEmpty
        ? '$languageLock\n\n'
        : '';
    final String langSuffix = languageLock.isNotEmpty
        ? '\n$languageLock'
        : '';

    // ── 7. Montar prompt final ─────────────────────────────────────────────
    // language lock no INÍCIO (Primazia) + módulos + language lock no FIM (Recência)
    final String candidate =
        '$langPrefix'               // language lock no INÍCIO
        '$core\n'
        '$antiLeak\n'
        '$uiContract\n'
        '$modeModule'
        '${taskModules.toString()}'
        '$contextSection'
        '$langSuffix';              // language lock no FIM

    // ── 8. Log de diagnóstico ─────────────────────────────────────────────
    if (kDebugMode || _kPromptSizeAudit) {
      final modeLabel = isPlantaoMode ? 'plantao' : 'estudo';

      debugPrint('[PM_SIZE] ══════════════════════════════════════');
      debugPrint('[PM_SIZE] incomingSystemPrompt=${systemPrompt.length} chars');
      debugPrint('[PM_SIZE] cleanContextAfterSanitize=${cleanContext.length} chars');
      debugPrint('[PM_SIZE] contextSectionAfterCap=${contextSection.length} chars (hardCap=$kContextHardCap)');
      debugPrint('[PM_SIZE] core=${core.length} chars');
      debugPrint('[PM_SIZE] antiLeak=${antiLeak.length} chars');
      debugPrint('[PM_SIZE] uiContract=${uiContract.length} chars');
      debugPrint('[PM_SIZE] modeModule($modeLabel)=${modeModule.length} chars');
      debugPrint('[PM_SIZE] taskModules(${intent.taskLabel})=${taskModules.length} chars');
      debugPrint('[PM_SIZE] languageLock(param)=${languageLock.length} chars [DUPLA ÂNCORA: início+fim]');
      debugPrint('[PM_SIZE] finalPromptToGemini=${candidate.length} chars');
      debugPrint('[PM_TASK] dose=${intent.isDose} diluicao=${intent.isDilution} interacao=${intent.isInteraction} sigla=${intent.isAcronym}');
      debugPrint('[PM_MODE] $modeLabel');
      debugPrint('[PM_SIZE] ══════════════════════════════════════');

      if (kDebugMode) {
        debugPrint('[AI_PROMPT_SIZE] core=${core.length}c antiLeak=${antiLeak.length}c ui=${uiContract.length}c mode($modeLabel)=${modeModule.length}c task(${intent.taskLabel})=${taskModules.length}c ctx=${contextSection.length}c lang=${languageLock.length}c total=${candidate.length}c');
        debugPrint('[AI_MODE] ${modeLabel.toUpperCase()}');
        debugPrint('[AI_TASK] ${intent.taskLabel}');
      }
    }

    return candidate;
  }
}
