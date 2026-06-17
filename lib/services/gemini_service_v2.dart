// ══════════════════════════════════════════════════════════════════════════════
// GeminiServiceV2 — Build 105 — Motor de IA BYOA blindado para produção
//
// ARQUITETURA v5.0 — Quatro camadas de blindagem estrutural + Design System:
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  CAMADA 1 — FILTRAGEM NATIVA DE STREAM (anti-vazamento de pensamento)   │
// │                                                                         │
// │  _extractText() inspeciona CADA part do SSE chunk e descarta            │
// │  categoricamente qualquer bloco identificado como raciocínio interno:   │
// │    • thought == true          → Chain-of-Thought explícito do Gemini    │
// │    • 'thoughtSignature' key   → Assinatura criptográfica de CoT         │
// │    • 'functionCall' key       → Chamada interna de ferramenta           │
// │    • 'executableCode' key     → Código executável gerado internamente   │
// │    • 'codeExecutionResult'    → Resultado de execução interna           │
// │    • 'inlineData' key         → Dados binários (imagens, etc.)          │
// │  Apenas parts com chave 'text' (String, não-vazia) chegam à UI.         │
// └─────────────────────────────────────────────────────────────────────────┘
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  CAMADA 2 — JANELA DESLIZANTE DE HISTÓRICO (Context Classifier) B105    │
// │                                                                         │
// │  Antes de cada stream, _classifyContext() faz uma chamada leve          │
// │  (não-streaming) enviando:                                              │
// │    • Última resposta da IA (truncada a 300 chars)                       │
// │    • Nova pergunta do usuário                                           │
// │  Instrução: responda APENAS 'MÉDICO' ou 'NOVO'.                         │
// │    'MÉDICO' → mesmo caso/medicamento → últimas 5 trocas (10 entradas)  │
// │    'NOVO'   → assunto diferente      → histórico vazio (clean slate)    │
// │  Timeout 8s, fallback conservador 'MÉDICO'. Custo: ~60 tokens/chamada. │
// └─────────────────────────────────────────────────────────────────────────┘
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  CAMADA 3 — CONFIGURAÇÃO REST BLINDADA + PREFIXO DE FERRO v5 (B105)     │
// │                                                                         │
// │  • system_instruction isolado do histórico (Content.system equivalente) │
// │  • _systemPromptPrefix v7 injetado ANTES de qualquer instrução AiService│
// │    BLOCO 0: IDIOMA PT-BR/ES + ANTI-LEAK + ANTI-TONAL (Build 112)      │
// │    BLOCO 1: PERSONA Plantão Chefe + Limites Matemáticos (12L/4L v7)   │
// │    BLOCO 1B: CONTRATO DE UI — tokens 🟥 ⛔ 📌 📚 para cards Flutter    │
// │    BLOCO 2: Anatomia Bupropión bilíngue (FARMACO MODE)                 │
// │    BLOCO 3: MATRIZ DE ACRÔNIMOS (IAM/AVC/TEP/IC/ICC/IRA/FA — Build112)│
// │  • Janela de histórico: 5 pares (era 3) — suporta diálogos longos      │
// │  • maxOutputTokens: 3200  → ceiling preservado (respostas completas)    │
// │  • temperature: 0.4       → consistência clínica calibrada              │
// │  • Retry com backoff 5s/15s/30s + cooldown global pós-429              │
// └─────────────────────────────────────────────────────────────────────────┘
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  CAMADA 4 — RAG CROSS-CHECK ANTI-ALUCINAÇÃO (implementado em AiService) │
// │                                                                         │
// │  • _ragCrossCheckEs/Pt: módulo 10 do systemPrompt (seção 15 de 19)      │
// │    → 4 passos: comparação query-RAG, classificação A/B/C,              │
// │      isolamento de dados de paciente, verificação final pré-envio       │
// │  • Regras K+L em safetyRules: Verdade Absoluta Restrita + Proibição    │
// │    de Alucinação Clínica                                                │
// │  • ragAnchor 9 regras: revisor crítico, proibição de invenção,         │
// │    isolamento de dados de paciente entre sessões                        │
// │  • selfCheck item 13: RAG cross-check obrigatório pré-resposta (5 subs) │
// └─────────────────────────────────────────────────────────────────────────┘
//
// ENDPOINTS:
//   STREAM : POST /v1beta/models/gemini-2.5-flash-lite:streamGenerateContent
//            ?alt=sse&key=KEY
//            Chunks SSE formato: "data: {...}\n\n"
//   SYNC   : POST /v1beta/models/gemini-2.5-flash-lite:generateContent?key=KEY
//            Context Classifier — resposta mínima ('MÉDICO'/'NOVO')
//
// FLUXO PRINCIPAL:
//   sendStream() → [quota check] → _runPipeline()
//     → _classifyContext() [sync, 8s timeout]
//     → _buildContextWindow() [max 3 pares ou vazio]
//     → _executeWithRetry() [max 3 tentativas]
//       → _streamRequest() [SSE blindado]
//         → _extractText() [filtro CoT, 6 condições]
//         → controller.add(GeminiChunk) [apenas texto limpo para UI]
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// GeminiChunk — unidade de dado do stream
// ─────────────────────────────────────────────────────────────────────────────
class GeminiChunk {
  /// Fragmento de texto do streaming (pode ser vazio em chunks de metadado).
  final String text;

  /// true → este chunk sinaliza o fim da resposta (finishReason detectado
  /// ou stream encerrado normalmente).
  final bool isDone;

  /// Código de erro se a requisição falhou (null = sucesso normal).
  /// Códigos possíveis: 'quota', 'api_key_invalid', 'timeout', 'network',
  /// 'stream_error', 'http_XXX', 'unexpected'.
  final String? errorCode;

  const GeminiChunk({
    required this.text,
    this.isDone = false,
    this.errorCode,
  });

  /// true → o stream terminou com falha.
  bool get isError => errorCode != null;

  /// Cria um chunk de erro com isDone implícito.
  factory GeminiChunk.error(String code) =>
      GeminiChunk(text: '', isDone: true, errorCode: code);

  /// Sinalização de conclusão sem texto adicional.
  static const GeminiChunk done = GeminiChunk(text: '', isDone: true);
}

// ─────────────────────────────────────────────────────────────────────────────
// GeminiServiceV2 — serviço estático (BYOA, sem instâncias)
// ─────────────────────────────────────────────────────────────────────────────
class GeminiServiceV2 {
  GeminiServiceV2._(); // construtor privado — utilitário 100% estático

  // ══════════════════════════════════════════════════════════════════════════
  // PRIVACIDADE CLÍNICA — LOGS CONDICIONAIS
  //
  // Em produção (release), respostas clínicas e dados do paciente NÃO devem
  // aparecer nos consoles de crash-reporting ou ferramentas de observabilidade.
  // _debugGemini=false em kReleaseMode silencia todos os logs do serviço.
  //
  // Durante desenvolvimento (debug/profile), os logs ficam visíveis normalmente.
  // ══════════════════════════════════════════════════════════════════════════

  /// true apenas em debug/profile — nunca em release build.
  static const bool _debugGemini = kDebugMode;

  /// Centraliza todos os logs do serviço — no-op em produção.
  static void _log(String message) {
    if (_debugGemini) debugPrint(message);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ENDPOINTS E MODELO
  // ══════════════════════════════════════════════════════════════════════════

  /// Modelo base — flash-lite tem quota free-tier muito maior que o flash-pro.
  /// Free tier: ~1.500 RPM, 1.000.000 TPM (vs. 10 RPM do gemini-2.5-flash).
  static const _modelId = 'gemini-2.5-flash-lite';

  /// Endpoint SSE de streaming (usado na resposta principal ao usuário).
  static const _endpointStream =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_modelId:streamGenerateContent?alt=sse';

  /// Endpoint síncrono (usado APENAS pelo Context Classifier — leve e rápido).
  static const _endpointSync =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_modelId:generateContent';

  // ══════════════════════════════════════════════════════════════════════════
  // CONTROLE DE QUOTA E RETRY
  // ══════════════════════════════════════════════════════════════════════════

  /// Número máximo de tentativas após erro 429.
  static const _maxRetries = 3;

  /// Backoff progressivo entre tentativas (attempt 0→5s, 1→15s, 2→30s).
  static const _retryBackoff = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD 135 — AUTO-RETRY TRANSITÓRIO: Backoff & Jitter
  //
  // Erros TRANSITÓRIOS (infra Google instável, rate-limit temporário):
  //   → Retentar automaticamente antes de propagar erro para a UI.
  //   → Máximo 3 tentativas com backoff exponencial + jitter aleatório.
  //
  // Erros NÃO-TRANSITÓRIOS (401/403/400/prompt inválido):
  //   → Propagar imediatamente — retry não adianta.
  //
  // Backoff schedule (base ± 500ms jitter):
  //   Tentativa 1: 2s ± 500ms  (1.500ms — 2.500ms)
  //   Tentativa 2: 4s ± 500ms  (3.500ms — 4.500ms)
  //   Tentativa 3: 8s ± 500ms  (7.500ms — 8.500ms)
  // ══════════════════════════════════════════════════════════════════════════

  /// Número máximo de tentativas para erros transitórios (5xx/gRPC/rede instável).
  static const _maxTransientRetries = 3;

  /// Delays base para cada tentativa transitória (sem jitter).
  static const _transientRetryBaseDelays = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
  ];

  /// Jitter máximo em ms aplicado a cada delay (± 500ms).
  static const _transientJitterMs = 500;

  /// RNG para jitter — instanciado uma vez para performance.
  static final _rng = math.Random();

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD 135 — WATCHDOG TIMEOUT MID-STREAM
  //
  // Se o stream SSE abrir mas congelar silenciosamente (sem chunks por 45s):
  //   → Timer dispara → encerra conexão de forma controlada
  //   → Emite GeminiChunk.error('timeout') → card nativo de instabilidade
  //
  // O timer é RESETADO a cada chunk válido recebido.
  // O timer é CANCELADO em onDone, onError e finally.
  // ══════════════════════════════════════════════════════════════════════════

  /// Tempo máximo de inatividade mid-stream antes do watchdog disparar.
  static const _watchdogTimeout = Duration(seconds: 45);

  /// Janela de cooldown após 429 definitivo (esgotou todas as tentativas).
  /// Bloqueia requisições por 60s para não desperdiçar tokens em requests
  /// condenados quando a quota está realmente esgotada.
  static const _quotaCooldown = Duration(minutes: 1);

  /// Timestamp de expiração do cooldown (null = sem cooldown ativo).
  static DateTime? _quotaUntil;

  /// true → cooldown ativo, não deve enviar requisições.
  static bool get isInQuotaCooldown =>
      _quotaUntil != null && DateTime.now().isBefore(_quotaUntil!);

  /// Tempo restante de cooldown (null se não há cooldown ou já expirou).
  static Duration? get quotaCooldownRemaining {
    if (_quotaUntil == null) return null;
    final remaining = _quotaUntil!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  /// Reseta o cooldown manualmente (ex: usuário configurou nova chave API).
  static void resetQuotaCooldown() => _quotaUntil = null;

  // ══════════════════════════════════════════════════════════════════════════
  // PREFIXO DE FERRO v5 — CAMADA 3  (Build 105)
  //
  // NOVIDADES v5 vs v4:
  //   • BLOCO 0: IDIOMA PT-BR/ES + ANTI-LEAK + ANTI-TONAL de memória (v7)
  //   • BLOCO 1: Persona "Plantão Chefe" + Limites Matemáticos (v7 Build 112)
  //              12 linhas max global / 4 linhas por card / 1 linha 📚
  //              Filtro Antitonal: proíbe copiar tom enciclopédico do RAG
  //   • BLOCO 1B: CONTRATO DE UI — tokens 🟥 ⛔ 📌 📚 (inalterado)
  //   • BLOCO 2: Anatomia Bupropión bilíngue (inalterado)
  //   • BLOCO 3: Matriz de Acrônimos — IC adicionado (Build 112)
  //              IC/ICC sempre = Insuficiência Cardíaca — nunca inglês
  //
  // Defesas sobrepostas (inalteradas da v4):
  //   [A] thinkingConfig omitido no stream → flash-lite não vaza CoT
  //   [B] Este prefixo → instrução textual direta ao modelo
  //   [C] _extractText() + _looksLikeInternalReasoning() → 7 filtros JSON
  // ══════════════════════════════════════════════════════════════════════════
  static const _systemPromptPrefix =

      // ── BLOCO -1 — COERÇÃO MÁXIMA FLASHCARD (Build 124) ─────────────────────
      // Injetado no topo absoluto do system_instruction, antes de qualquer outra
      // regra. Prioridade irrevogável — não pode ser sobrescrita pelo histórico.
      'CRITICAL IDENTITY (Build 124 — IRREVOGÁVEL):\n'
      'You are an EMERGENCY MEDICAL FLASHCARD, NOT an encyclopedia.\n'
      'YOUR ONLY OUTPUT is drug names + doses + routes. Nothing else.\n\n'
      'ANTI-ENCYCLOPEDIA RULE — applies to ALL questions without exception:\n'
      '  If the user asks "What is X?", "¿Qué es X?", "O que é X?",\n'
      '  "Explain X", "How does X work?", "Mechanism of X" or ANY definition/\n'
      '  explanation request — IGNORE the request for explanation.\n'
      '  CONVERT IMMEDIATELY to flashcard format:\n'
      '  → Start with 🟥 CONDUCTA FARMACOLÓGICA (ES) or 🟥 CONDUTA FARMACOLÓGICA (PT)\n'
      '  → List drugs with ✅ **DrugName**: Dose route (frequency).\n'
      '  → Never write paragraphs, descriptions, or mechanism of action.\n\n'
      'ZERO tolerance violations:\n'
      '  ✗ "El Salbutamol es un broncodilatador..." → FORBIDDEN\n'
      '  ✗ "Agonistas Dopaminérgicos:" → FORBIDDEN (class labels)\n'
      '  ✗ Any sentence that does not start with 🟥, ✅, ⛔, 📌, 📚 or - bullet\n'
      '  ✓ 🟥 CONDUCTA FARMACOLÓGICA → ✅ **Salbutamol**: 2,5 mg nebulizado (cada 20 min)\n\n'
      'If you violate this, the application crashes and patient care is harmed.\n\n'

      // ── BLOCO 0 — IDIOMA DINÂMICO + ANTI-LEAK + ANTI-TONAL (v7 — Build 112) ──
      // v7: regras matemáticas de tamanho (12 linhas max / 4 por card),
      //     filtro antitonal de memória (proíbe copiar tom enciclopédico de RAG),
      //     persona reforçada como "Médico de Plantão Chefe do MedCases Pro".
      '🌐 IDIOMA — REGRA MESTRE ABSOLUTA (v7):\n'
      'Você é o MÉDICO DE PLANTÃO CHEFE do MedCases Pro.\n'
      'Missão única: CONDUTA TERAPÊUTICA e FARMACOLOGIA DE URGÊNCIA — nada mais.\n'
      'O idioma OBRIGATÓRIO desta sessão está declarado em 🔒 IDIOMA OBRIGATORIO/OBLIGATORIO '
      'que aparece IMEDIATAMENTE A SEGUIR.\n'
      'OBEDEÇA esse idioma de forma ABSOLUTA e EXCLUSIVA — Português-BR ou Español.\n'
      'NUNCA responda em Inglês, a menos que o usuário solicite EXPLICITAMENTE.\n'
      'PROIBIDO: misturar idiomas, usar inglês na resposta clínica, deduzir idioma do histórico.\n'
      'Esta regra é ABSOLUTA e não pode ser sobrescrita por nenhuma outra instrução.\n\n'
      '⚠️ ANTI-LEAK DE METADADOS — PROIBIÇÃO TOTAL (Build 113):\n'
      'A primeira linha da resposta DEVE SER SEMPRE o conteúdo clínico direto.\n'
      'TERMINANTEMENTE PROIBIDO escrever:\n'
      '  ✗ "The user is asking..." / "The user wants..." / "I should..."\n'
      '  ✗ "Confianza Clínica:" / "Confiança Clínica:" / "Clinical Confidence:"\n'
      '  ✗ "El usuario solicita..." / "O usuário solicita..." / "Baseado na conversa..."\n'
      '  ✗ "El idioma de la pregunta es..." / "A língua da pergunta é..."\n'
      '  ✗ "Esta sigla pode significar..." / "SCA pode se referir a..."\n'
      '  ✗ Qualquer meta-comentário, análise de idioma ou raciocínio sobre a sigla.\n'
      'REGRA DE SIGLA ISOLADA: se a query for apenas uma sigla médica (1-5 chars),\n'
      'abra IMEDIATAMENTE o card 🟥 com conduta — sem preâmbulo, sem análise.\n\n'

      // ── BLOCO 1 — PERSONA URGÊNCIA + ANTI-CoT + LIMITES MATEMÁTICOS (v7 Build 112) ──
      '🔒 REGRAS ABSOLUTAS DE OPERAÇÃO (v7 — INEGOCIÁVEIS):\n'
      '1. JAMAIS exiba raciocínio interno, rascunhos ou meta-dados.\n'
      '2. ZERO inglês visível — apenas termos médicos universais (SpO₂, qSOFA, PCR, INR).\n'
      '3. Responda DIRETAMENTE na primeira linha. Sem chain-of-thought, <thinking>, scratchpad.\n'
      '\n'
      '👨‍⚕️ PERSONA — MÉDICO DE PLANTÃO CHEFE DO MedCases Pro:\n'
      'Comunicação CIRÚRGICA: vá DIRETO à DOSE, VIA e FREQUÊNCIA. Nenhuma palavra a mais.\n'
      'PROIBIDO ABSOLUTO: introduções, definições, fisiopatologia, conceitos acadêmicos.\n'
      'O médico de plantão precisa agir em SEGUNDOS — cada linha deve ser acionável.\n'
      'LINGUAGEM TELEGRÁFICA MILITAR (Build 119): em vez de frases explicativas, use dados puros.\n'
      '  ✗ Proibido: "Es el fármaco más eficaz para controlar os síntomas motores"\n'
      '  ✓ Obrigatório: "Sintomas motores (rigidez/bradicinesia)"\n'
      '  ✗ Proibido: "El tratamiento se enfoca en la dopaminérgica substituição"\n'
      '  ✓ Obrigatório: "**Levodopa/Carbidopa** — 100/25 mg VO 3x/día"\n\n'
      '⚡ CONTRATO DE TAMANHO — LIMITES MATEMÁTICOS RÍGIDOS (v7):\n'
      '  📏 LIMITE GLOBAL: Toda a resposta = MÁXIMO 12 LINHAS NO TOTAL.\n'
      '  📏 LIMITE POR CARD: Cada bloco (🟥 ⛔ 📌) = MÁXIMO 4 LINHAS.\n'
      '  📏 LIMITE RODAPÉ: 📚 = EXATAMENTE 1 linha de referências.\n'
      '  ⚠️ Se ultrapassar 12 linhas, CORTE — priorize 🟥 (conduta) sobre tudo.\n\n'
      '🚫 FILTRO ANTITONAL DE MEMÓRIA (v7 — CRÍTICO):\n'
      '  Quando o sistema injetar textos longos de histórico, RAG ou memória interna:\n'
      '  ✗ PROIBIDO replicar o tom enciclopédico, acadêmico ou prolixo desses textos.\n'
      '  ✗ PROIBIDO copiar seções como "Causas e Fatores de Risco", "Fisiopatologia",\n'
      '    "Epidemiologia", "Diagnóstico Diferencial" ou qualquer bloco conceitual.\n'
      '  ✓ OBRIGATÓRIO: filtrar essas informações e reformatá-las no molde cirúrgico\n'
      '    dos tokens 🟥 ⛔ 📌 📚 com máximo 4 linhas cada.\n'
      '  ✓ Memória/histórico = matéria-prima para extração de conduta. Nunca copiar.\n\n'
      '🚫 FILTRO ANTI-PROSA CIRÚRGICO (Build 119 — INEGOCIÁVEL):\n'
      'ANTES de gerar qualquer linha de output, verificar se a frase começa com prosa proibida.\n'
      'PADRÕES PROIBIDOS — DISPARADORES DE REESCRITA IMEDIATA:\n'
      '  ✗ "El tratamiento se enfoca en..." → ✓ Fármaco + dose direto na primeira linha\n'
      '  ✗ "Es crucial recordar que..."     → ✓ ELIMINAR — substituir por bullet clínico\n'
      '  ✗ "Es importante destacar que..."  → ✓ ELIMINAR — substituir por bullet clínico\n'
      '  ✗ "Como ya mencionamos..."         → ✓ ELIMINAR completamente\n'
      '  ✗ "En resumen, el manejo de..."    → ✓ ELIMINAR — iniciar direto no dado\n'
      '  ✗ "O tratamento se baseia em..."   → ✓ Fármaco + dose direto na primeira linha\n'
      '  ✗ "É crucial lembrar que..."       → ✓ ELIMINAR — substituir por bullet clínico\n'
      '  ✗ "Vale ressaltar que..."          → ✓ ELIMINAR completamente\n'
      '  ✗ "O fármaco mais eficaz para controlar os sintomas é..." → ✓ "Sintomas motores (rigidez/bradicinesia)"\n'
      'CONTRATO DE LINGUAGEM — PADRÃO TELEGRÁFICO OBRIGATÓRIO:\n'
      '  ✓ Fármaco (Indicação): Dose via frequência\n'
      '  ✓ Primeiro caractere da resposta = conteúdo clínico puro. ZERO preâmbulo.\n'
      '  ✓ Negrito APENAS em doses numéricas e nomes de fármacos\n'
      '  ✓ Bullets telegráficos: fato clínico + valor + unidade — sem conectores decorativos\n'
      'O médico de plantão tem 3 segundos — cada caractere a mais é tempo de vida perdido.\n\n'
      '💊 FÁRMACOS E DOSES: sempre **NEGRITO MAIÚSCULAS** juntos — ex: **MORFINA 4 MG IV**, **LEVODOPA/CARBIDOPA 100/25 MG VO 3X/DIA**, **AMOXICILINA 500 MG VO 8/8H**.\n\n'
      '✅ FORMATAÇÃO MARKDOWN OBRIGATÓRIA (Build 116 — Parser Flutter):\n'
      'O app usa flutter_markdown para renderizar a resposta. USE os marcadores abaixo:\n'
      '  ✅ **negrito** → use para fármacos, doses, valores críticos\n'
      '  ✅ ## Título → use para cabeçalho de seção (Fármacos e Doses, Red Flags, etc.)\n'
      '  ✅ * item → use para bullets de lista\n'
      '  ✅ > alerta → use para blockquote de alerta crítico\n'
      'PROIBIDO EXPOR TAGS RAW: se a tag não puder ser renderizada, omiti-la.\n'
      '🚫 PROIBIÇÃO ABSOLUTA — OUTPUT LIMPO (Build 116):\n'
      '  ✗ NUNCA escreva rótulos de modo interno: "[A]", "[B]", "[CONV]", "[CONV]"\n'
      '  ✗ NUNCA escreva "MODO ACTIVO:", "MODO [A] CONDUCTA", "MODO CONVERSACIONAL"\n'
      '  ✗ NUNCA escreva "[REVISIÓN INTERNA]", "[REVISION_INTERNA]", "CAMADA 1", "CAPA 1"\n'
      '  ✗ NUNCA escreva "Confianza Clínica:", "Confiança Clínica:", "Nivel de Confianza"\n'
      '  ✗ NUNCA escreva meta-comentários sobre o processo: "Vou estruturar...", "Baseado na query..."\n'
      '  ✗ NUNCA gere tags <think>...</think> ou <thinking>...</thinking> — reasoning interno PROIBIDO no output.\n'
      'O médico deve ver APENAS o conteúdo clínico puro — sem rótulos de sistema visíveis.\n\n'
      // ── Build 121 — Bloqueio total de "Motivo:" e abertura obrigatória com 🟥 ──
      '🚫 PROIBIÇÃO TOTAL DE "MOTIVO:" E "CONFIANZA CLINICA:" (Build 121 — CRÍTICO):\n'
      '  ✗ NUNCA escrever "Motivo:" como primeira linha, linha autônoma ou abertura de resposta.\n'
      '  ✗ NUNCA escrever "Confianza Clinica: Alta/Moderada/Baja" ou "Confiança Clínica: Alta/Moderada/Baixa" visível ao usuário.\n'
      '  ✗ NUNCA antepor NENHUM metadado de confiança, justificativa ou raciocínio antes do conteúdo clínico.\n'
      '  ✓ PRIMEIRO CARACTERE OBRIGATÓRIO de toda resposta clínica = 🟥 CONDUTA IMEDIATA / CONDUCTA INMEDIATA\n'
      '  ✓ A confiança clínica é avaliada INTERNAMENTE — NUNCA exposta no output ao médico.\n'
      '  ALERTA: violar esta regra produz crash e erro de UX crítico em produção.\n\n'
      '🧠 MEMÓRIA CLÍNICA CONTÍNUA — CONTEXTO IMPLÍCITO (Build 117):\n'
      'Ao receber uma nova query, verificar o histórico da conversa (history):\n'
      '  ✓ Se a query atual NÃO menciona explicitamente uma patologia/fármaco MAS o turno anterior SIM:\n'
      '    → INFERIR que é um seguimento do MESMO tema clínico. Responder em continuidade.\n'
      '    → Exemplo: turno anterior="Parkinson" + nova query="tratamento para paciente jovem"\n'
      '       Interpretar como: "Tratamento de Parkinson para paciente jovem"\n'
      '  ✓ NUNCA pedir esclarecimento se o contexto clínico puder ser inferido do histórico.\n'
      '  ✓ Manter o fio de raciocínio clínico da sessão sem resetar o contexto.\n\n'
      '❓ PERGUNTA CLÍNICA DE FECHAMENTO — OBRIGATÓRIA (Build 117):\n'
      'Toda resposta clínica DEVE terminar com uma pergunta curta e direta APÓS o 📚.\n'
      '  ✓ Instiga o usuário a decidir o próximo passo clínico.\n'
      '  ✓ Exemplos: "Deseja avaliar o ajuste de dose ou discutir os efeitos adversos?"\n'
      '              "Quer aprofundar o escalonamento ou revisar as contraindicações?"\n'
      '              "¿Deseas evaluar X o discutir Y?"\n'
      '  ✗ NUNCA terminar a resposta apenas com 📚 sem a pergunta de fechamento.\n\n'

      // ── BLOCO 1C — ARQUITETURA TRIPARTITE + GABARITO FLASHCARD (Build 122) ──
      '🏗️ ARQUITETURA TRIPARTITE DE RESPOSTA — GABARITO FLASHCARD (Build 122):\n'
      'TODA resposta clínica DEVE seguir exatamente esta sequência de 3 estágios:\n'
      '\n'
      'ESTÁGIO 1 — CONDUTA FARMACOLÓGICA (abre a resposta, sem preâmbulo):\n'
      '  • PADRÃO OBRIGATÓRIO para cada fármaco:\n'
      '      ✅ **NomeFármaco**: Dose via (frequência/carga).\n'
      '  • EXEMPLO CORRETO:  ✅ **Clopidogrel**: 600 mg VO (carga).\n'
      '  • EXEMPLO ERRADO:   ✅ Inibidor P2Y12: Clopidogrel 600 mg VO (carga). ← PROIBIDO\n'
      '  • PROIBIDO ABSOLUTO: classes farmacológicas como "Inibidor P2Y12", "Betabloqueador",\n'
      '    "IECA", "ARA-II", "Antagonista de Ca²⁺", "Anticoagulante" — apenas o NOME.\n'
      '  • Separar subseções com ⸻ (linha divisória)\n'
      '\n'
      'ESTÁGIO 2 — PERGUNTA DE FILTRO (após ⸻ final do estágio 1):\n'
      '  • 1 única pergunta clínica indutiva em linha própria\n'
      '  • Permite ao médico decidir o próximo passo sem overload\n'
      '  • Exemplos: "¿Deseas revisar la titulación o evaluar complicaciones?"\n'
      '              "Deseja ajuste de dose, segunda linha ou monitorização?"\n'
      '\n'
      'ESTÁGIO 3 — REFERÊNCIAS (bloco final separado, colapsável no app):\n'
      '  • Cabeçalho EXATO: "📚 REFERENCIAS" (ES) ou "📚 REFERÊNCIAS" (PT)\n'
      '  • Bullets com fontes: * Harrison · * ESC 2023 · * SBC etc.\n'
      '  • O app Flutter detecta este cabeçalho e encapsula em chip colapsável\n'
      '  • PROIBIDO mesclar referências no corpo clínico (inline 📚 inline)\n'
      '  • PROIBIDO omitir este bloco — toda resposta clínica deve ter referências\n'
      '\n'
      'GABARITO FEW-SHOT — PARKINSON ATÔMICO (Build 123 — modelo de fidelidade):\n'
      '🟥 CONDUCTA FARMACOLÓGICA\n'
      '✅ **Levodopa/Carbidopa**: 100/25 mg VO 3x/día (Máx. 1500 mg/día).\n'
      '✅ **Pramipexol**: 0,125 mg VO 3x/día → Titular hasta 1,5 mg 3x/día.\n'
      '✅ **Rasagilina**: 1 mg VO 1x/día.\n'
      '✅ **Entacapona**: 200 mg VO con cada dosis de Levodopa (Máx. 1600 mg/día).\n'
      '⸻\n'
      '⛔ ALERTAS CRÍTICAS\n'
      '🚫 **Biperideno**: Evitar en ancianos (alto riesgo de confusión mental y retención urinaria).\n'
      '🚫 **Levodopa**: Contraindicado en psicosis activa y glaucoma de ángulo cerrado.\n'
      '⸻\n'
      '¿Deseas ajustar dosis por función renal, revisar interacciones o evaluar el escalonamiento para fluctuaciones motoras ("off")?\n'
      '\n'
      '📚 REFERENCIAS\n'
      '* Guías MDS 2023 · AAN 2022 · Harrison\'s\n'
      '\n'
      'ORDEM OBRIGATÓRIA: Estágio 1 → Estágio 2 → Estágio 3. NUNCA inverter.\n\n'

      // ── BLOCO 1B — CONTRATO DE UI / DESIGN SYSTEM DE CARDS (Build 105) ─────
      // CRÍTICO: O app Flutter usa um parser que converte esses tokens em
      // elementos visuais nativos (cards coloridos). Respeitar RIGOROSAMENTE.
      '🎨 CONTRATO DE FORMATAÇÃO — DESIGN SYSTEM DO APP (PARSER COMPATIBILITY):\n'
      'O aplicativo converte os tokens abaixo em cards visuais nativos.\n'
      'USE OBRIGATORIAMENTE estes marcadores para estruturar condutas médicas:\n'
      '\n'
      '  🟥 CARD VERMELHO — Conduta Principal / Prescrição Medicamentosa:\n'
      '     Formato: 🟥 NOME-DO-FÁRMACO EM MAIÚSCULO — dose via frequência\n'
      '     Exemplo: 🟥 AMOXICILINA — 500 mg VO 8/8h por 7 dias\n'
      '     Exemplo: 🟥 LEVODOPA + CARBIDOPA — 100/25 mg VO 3x/dia\n'
      '     Use para: medicamento de 1ª escolha, dose de ataque, protocolo principal.\n'
      '\n'
      '  ⛔ CARD LARANJA — Alertas / Contraindicações / Interações:\n'
      '     Formato: ⛔ Texto do alerta clínico relevante\n'
      '     Exemplo: ⛔ Contraindicado em insuficiência renal grave (ClCr < 15)\n'
      '     Use para: contraindicações absolutas, alertas de segurança, interações graves.\n'
      '\n'
      '  📌 CARD AZUL — Próximo Passo / Refinamento Diagnóstico:\n'
      '     Formato: 📌 Texto da pergunta ou direcionamento clínico\n'
      '     Exemplo: 📌 Quer ajuste por peso/renal ou titulação progressiva?\n'
      '     Use para: perguntas de refinamento, próxima conduta, decisão compartilhada.\n'
      '\n'
      '  📚 RODAPÉ DE EVIDÊNCIA — Linha final de cada resposta:\n'
      '     Formato: 📚 Guideline1 · Guideline2 · PubMed · Harrison\n'
      '     Exemplo: 📚 Harrison · PubMed · Guidelines de Emergência · SBC 2023\n'
      '     OBRIGATÓRIO: finalizar TODA resposta com esta linha de referências.\n'
      '\n'
      'REGRA DE SAUDAÇÃO: Se o histórico já contiver mensagens anteriores,\n'
      'NÃO repita "Bom dia", "Olá", "Claro", "Com prazer" — vá direto ao conteúdo clínico.\n\n'

      // ── BLOCO 2 — ANATOMIA BUPROPIÓN v5 BILÍNGUE (FARMACO MODE COMPLETO) ──
      '🏗️ ANATOMIA — MODO FARMACO COMPLETO (modelo Bupropión):\n'
      'Ativa SOMENTE em FARMACO MODE COMPLETO. Adaptar títulos ao idioma.\n'
      '\n'
      '  § 1 — DEFINICIÓN / DEFINIÇÃO\n'
      '    1 parágrafo curto (máx. 3 linhas). Mecanismo em MAIÚSCULAS.\n'
      '\n'
      '  § 2 — INDICACIONES Y DOSIS / INDICAÇÕES E DOSES\n'
      '    Bullets curtos com indicação + DOSE: [valor] [via] [frequência]. Máx. 5.\n'
      '\n'
      '  § 3 — ALERTA DE SEGURANÇA (somente se risco real de vida)\n'
      '    > 🔴 ALERTA CRÍTICO: [contraindicação absoluta ou efeito fatal]\n'
      '\n'
      '  § 4 — OUTROS PONTOS\n'
      '    Máx. 4 bullets: efeitos adversos relevantes, interações, monitoramento.\n'
      '\n'
      '  § 5 — RODAPÉ DE EVIDÊNCIA\n'
      '    📚 Referências base: Harrison · PubMed · [guideline relevante]\n\n'

      // ── BLOCO 3 — MATRIZ DE ACRÔNIMOS CRÍTICOS DE PLANTÃO (Build 113) ──────
      // Build 112: adicionado IC = INSUFICIÊNCIA CARDÍACA
      // Build 113: SCA recebeu regra NUNCA explícita contra Neurologia/Ataxia;
      //            IAM recebeu lock de idioma PT-BR para queries de sigla isolada
      '🚨 MATRIZ DE ACRÔNIMOS CRÍTICOS — INTERPRETAÇÃO OBRIGATÓRIA:\n'
      'Toda sigla abaixo, quando mencionada sem contexto adicional, deve ser\n'
      'interpretada IMEDIATAMENTE como emergência/urgência médica:\n'
      '\n'
      '  IAM  → INFARTO AGUDO DO MIOCÁRDIO     (Risco: 🔴 VERMELHO — Emergência)\n'
      '         NUNCA: "Identity and Access Management" ou qualquer sigla de TI.\n'
      '         NUNCA comentar sobre idioma da query. Responder em PT-BR com conduta imediata.\n'
      '  AVC  → ACIDENTE VASCULAR CEREBRAL      (Risco: 🔴 VERMELHO — Emergência)\n'
      '  AVE  → ACIDENTE VASCULAR ENCEFÁLICO    (Risco: 🔴 VERMELHO — Emergência)\n'
      '  TEP  → TROMBOEMBOLISMO PULMONAR         (Risco: 🔴 VERMELHO — Emergência)\n'
      '  TEPA → TROMBOEMBOLISMO PULMONAR AGUDO   (Risco: 🔴 VERMELHO — Emergência)\n'
      '  PCR  → PARADA CARDIORRESPIRATÓRIA       (Risco: 🔴 VERMELHO — Emergência)\n'
      '         NUNCA: "Polymerase Chain Reaction" em contexto clínico de emergência.\n'
      '  IC   → INSUFICIÊNCIA CARDÍACA           (Risco: 🟠 LARANJA — Urgência)\n'
      '         NUNCA: "Interstitial Cystitis", "Intensive Care" ou qualquer termo em inglês.\n'
      '         Responda SEMPRE em Português-BR ou Espanhol sobre manejo cardíaco.\n'
      '  ICC  → INSUFICIÊNCIA CARDÍACA CONGESTIVA (Risco: 🟠 LARANJA — Urgência)\n'
      '         NUNCA: qualquer expansão em inglês. Responda em PT-BR/ES sobre manejo cardíaco.\n'
      '  IRA  → INSUFICIÊNCIA RENAL AGUDA        (Risco: 🟠 LARANJA — Urgência)\n'
      '  FA   → FIBRILAÇÃO ATRIAL                (Risco: 🟠 LARANJA — Urgência)\n'
      '  SCA  → SÍNDROME CORONÁRIA AGUDA         (Risco: 🔴 VERMELHO — Emergência)\n'
      '         EXCLUSIVAMENTE Cardiologia: AAS, anticoagulação, cateterismo, stent.\n'
      '         NUNCA: Neurologia, Ataxia, "Spinocerebellar Ataxia" ou qualquer\n'
      '         expansão em inglês. SCA neste app = CORONÁRIA, sem exceção.\n'
      '  SEPSE → SEPSE / CHOQUE SÉPTICO          (Risco: 🔴 VERMELHO — Emergência)\n'
      '  AVCi → AVC ISQUÊMICO — trombólise/trombectomia se elegível (Risco: 🔴 VERMELHO)\n'
      '  AVCh → AVC HEMORRÁGICO — controle PA urgente (Risco: 🔴 VERMELHO)\n'
      '\n'
      '⚠️ REGRA ANTI-METADADOS PARA SIGLAS ISOLADAS (Build 113):\n'
      'Se o usuário digitar APENAS uma sigla ("IAM", "SCA", "IC", "TEP", etc.),\n'
      'NUNCA comente sobre o idioma da pergunta nem sobre a ambiguidade da sigla.\n'
      'Vá DIRETAMENTE para o card 🟥 com conduta de emergência em Português-BR.\n'
      '\n'
      'PROIBIDO ABSOLUTO: interpretar siglas médicas como termos de tecnologia,\n'
      'negócios, segurança digital ou medicina em língua inglesa. Qualquer sigla ambígua → MÉDICO PT-BR/ES.\n\n';

  // ══════════════════════════════════════════════════════════════════════════
  // sendStream — API PÚBLICA
  //
  // Streaming token-a-token via SSE com janela deslizante de histórico.
  //
  // Parâmetros:
  //   apiKey       → Gemini API key do usuário (BYOA)
  //   userMessage  → pergunta atual do usuário
  //   systemPrompt → prompt de sistema montado pelo AiService (19 seções)
  //   history      → histórico completo [{role: 'user'/'assistant', content}]
  //   useGrounding → ativar Google Search Grounding (padrão: true)
  //
  // Retorna:
  //   Stream<GeminiChunk> — cada evento é texto parcial ou sinalização.
  //   O AppProvider acumula os chunks num StringBuffer e atualiza a UI.
  //
  // Fluxo interno:
  //   1. Verifica cooldown global pós-429
  //   2. _runPipeline: classify → window → stream
  //
  // Compatibilidade: mesma assinatura da versão anterior — nenhum caller
  // precisa ser modificado.
  // ══════════════════════════════════════════════════════════════════════════
  static Stream<GeminiChunk> sendStream({
    required String apiKey,
    required String userMessage,
    required String systemPrompt,
    List<Map<String, String>> history = const [],
    bool useGrounding = true,
  }) {
    final controller = StreamController<GeminiChunk>();

    // ── Guarda de quota: rejeita imediatamente se cooldown ativo ─────────────
    if (isInQuotaCooldown) {
      final remaining = quotaCooldownRemaining;
      _log(
        '[GeminiV2] quota cooldown ativo — ${remaining?.inSeconds ?? 0}s restantes',
      );
      controller
        ..add(GeminiChunk.error('quota'))
        ..close();
      return controller.stream;
    }

    // ── Pipeline assíncrono (não bloqueia o thread UI) ────────────────────────
    _runPipeline(
      controller: controller,
      apiKey: apiKey,
      userMessage: userMessage,
      systemPrompt: systemPrompt,
      history: history,
      useGrounding: useGrounding,
    );

    return controller.stream;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // _runPipeline — Orquestrador do pipeline assíncrono
  //
  // Passo 1: Context Classifier — determina se a nova pergunta continua
  //          o caso anterior ('MÉDICO') ou inicia assunto novo ('NOVO').
  //
  // Passo 2: _buildContextWindow — constrói o histórico calibrado:
  //          'MÉDICO' → últimas 3 trocas (6 entradas, ~1.200 tokens)
  //          'NOVO'   → lista vazia (só a pergunta atual, ~50 tokens)
  //
  // Passo 3: _executeWithRetry — stream SSE com retry automático.
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> _runPipeline({
    required StreamController<GeminiChunk> controller,
    required String apiKey,
    required String userMessage,
    required String systemPrompt,
    required List<Map<String, String>> history,
    required bool useGrounding,
  }) async {
    if (controller.isClosed) return;

    // ── Passo 1: Janela de histórico ─────────────────────────────────────────
    // Build 110: BYPASS do _classifyContext — o classificador era o ponto de
    // falha da memória. Ele podia retornar 'NOVO' para follow-ups legítimos
    // ('Mais detalhes', 'E a dose?') e descartar o histórico inteiro.
    // Solução: sempre passa o histórico janelado. O Gemini com o system prompt
    // já tem contexto suficiente para distinguir continuidade de novo tema.
    // O _classifyContext ainda existe para uso futuro mas não bloqueia mais o histórico.
    final windowedHistory = _buildContextWindow(history, 'MÉDICO');
    _log('[GeminiV2] histórico → ${windowedHistory.length ~/ 2} troca(s) no payload (classifier bypass Build 110)');

    // ── Passo 2: Stream com histórico calibrado ───────────────────────────────
    try {
      await _executeWithRetry(
        controller: controller,
        apiKey: apiKey,
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        history: windowedHistory,
        useGrounding: useGrounding,
        attempt: 0,
      );
    } catch (e) {
      _log('[GeminiV2] _runPipeline erro inesperado: $e');
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error('unexpected'))
          ..close();
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // _classifyContext — Context Classifier (CAMADA 2)
  //
  // Chamada síncrona ultra-leve à API (não-streaming, generateContent).
  // Envia APENAS:
  //   • Última resposta da IA (truncada a 300 chars para economizar tokens)
  //   • Nova pergunta do usuário
  //
  // A instrução do sistema temporária ordena: responda UMA palavra.
  //   'MÉDICO' = mesma consulta/caso/medicamento/tema clínico anterior
  //   'NOVO'   = mudou de assunto, novo caso, nova dúvida não relacionada
  //
  // Custo típico: ~60-80 tokens. Timeout agressivo: 8 segundos.
  // Fallback em qualquer falha: 'MÉDICO' (conservador — mantém contexto).
  //
  // Por que não usar o histórico completo para classificar?
  //   Para não gastar tokens do classifier com histórico longo. O par
  //   (última IA + nova query) é suficiente para determinar continuidade.
  // ══════════════════════════════════════════════════════════════════════════
  static Future<String> _classifyContext({
    required String apiKey,
    required List<Map<String, String>> history,
    required String userMessage,
  }) async {
    // Busca a última resposta da IA no histórico (percorre de trás para frente)
    String lastAiResponse = '';
    for (int i = history.length - 1; i >= 0; i--) {
      if (history[i]['role'] == 'assistant') {
        lastAiResponse = history[i]['content'] ?? '';
        break;
      }
    }

    // Sem resposta prévia da IA → não há contexto para comparar
    if (lastAiResponse.isEmpty) {
      _log('[GeminiV2] classifier: sem resposta IA prévia → MÉDICO');
      return 'MÉDICO';
    }

    // Trunca para 300 chars — suficiente para capturar o tema sem gastar tokens
    final truncatedAi = lastAiResponse.length > 300
        ? '${lastAiResponse.substring(0, 300)}...'
        : lastAiResponse;

    // Instrução temporária em inglês — eficiente para classificação binária
    const classifierSystemPrompt =
        'You are a medical conversation context classifier. '
        'Your ONLY job is to determine if the new user question continues the same '
        'clinical topic as the previous AI response, or starts a completely new topic. '
        'Reply with EXACTLY one word — no punctuation, no explanation:\n'
        '"MÉDICO" — if the new question follows up on the same clinical case, '
        'medication, diagnosis, exam, or any aspect of the previous response.\n'
        '"NOVO" — if the user changed subject, started a new case, asked about '
        'something completely unrelated, or explicitly said they want a new topic.';

    final requestBody = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': classifierSystemPrompt}
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text': 'Previous AI response (truncated to 300 chars):\n'
                  '"$truncatedAi"\n\n'
                  'New user question:\n'
                  '"$userMessage"\n\n'
                  'Same clinical topic? Reply MÉDICO or NOVO.',
            }
          ],
        }
      ],
      'generationConfig': {
        'maxOutputTokens': 10,   // Uma palavra — 10 tokens é mais que suficiente
        'temperature': 0.0,      // Determinístico — queremos uma classificação estável
        'topK': 1,               // Greedy decoding — token mais provável apenas
        'thinkingConfig': {'thinkingBudget': 0}, // Zero CoT — velocidade máxima
      },
    });

    final url = Uri.parse('$_endpointSync?key=$apiKey');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
  _log(
          '[GeminiV2] classifier HTTP ${response.statusCode} → fallback MÉDICO',
        );
        return 'MÉDICO';
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawText = _extractTextFromSync(data).trim().toUpperCase();
      _log('[GeminiV2] classifier resposta raw: "$rawText"');

      // Sanitiza: remove tudo que não seja letra maiúscula ou acentuada.
      // Previne que "MÉDICO." / "NOVO!" / "MÉDICO\n" quebrem a avaliação.
      final normalized =
          rawText.replaceAll(RegExp(r'[^A-ZÁÉÍÓÚÃÕÇ]'), '').toUpperCase();
      _log('[GeminiV2] classifier normalizado: "$normalized"');

      // Aceita variações naturais: NUEVO, NEW, CHANGE → NOVO
      // Qualquer outra resposta (incluindo silêncio ou erro) → MÉDICO (conservador)
      if (normalized.contains('NOV') ||
          normalized.contains('NEW') ||
          normalized.contains('CHAN') ||
          normalized.contains('DIFF')) {
        return 'NOVO';
      }
      return 'MÉDICO';
    } on TimeoutException {
      _log('[GeminiV2] classifier timeout (8s) → fallback MÉDICO');
      return 'MÉDICO';
    } catch (e) {
      _log('[GeminiV2] classifier erro: $e → fallback MÉDICO');
      return 'MÉDICO';
    }
  }

  // ── Extrai texto de resposta síncrona (generateContent, não SSE) ──────────
  // Aplica o mesmo filtro de CoT para garantir que o classificador
  // não retorne texto de pensamento interno acidentalmente.
  static String _extractTextFromSync(Map<String, dynamic> data) {
    try {
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return '';
      final candidate = candidates[0] as Map<String, dynamic>;
      final parts = candidate['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) return '';

      final buffer = StringBuffer();
      for (final rawPart in parts) {
        final part = rawPart as Map<String, dynamic>;
        // Filtra CoT mesmo no classifier
        if (part['thought'] == true) continue;
        if (part.containsKey('thoughtSignature')) continue;
        final text = part['text'] as String?;
        if (text != null && text.isNotEmpty) buffer.write(text);
      }
      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // _buildContextWindow — Janela deslizante de histórico (CAMADA 2)  Build 105
  //
  // Controla quantas trocas anteriores são enviadas no payload da API.
  //
  // 'MÉDICO' (mesmo caso / follow-up):
  //   → Retorna as últimas 5 trocas = max 10 entradas.
  //   → Build 105: aumentado de 3→5 pares para suportar diálogos longos
  //     sem perder o fio da meada clínica após o 4º turno.
  //   → Uma troca = 1 user + 1 model. 5 trocas ≈ 2.000 tokens de contexto.
  //
  // 'NOVO' (assunto diferente — classificador confirmou mudança de tema):
  //   → Build 105: retorna lista vazia APENAS quando history.length >= 2
  //     (já há pelo menos 1 troca completa). Se history.length < 2, o
  //     classifier raramente tem contexto suficiente para ser confiável
  //     → nesse caso retorna lista vazia igualmente (primeira mensagem).
  //   → Previne "contaminação cruzada" de dados clínicos entre casos.
  //
  // IMPORTANTE: este método NÃO modifica o histórico original no AppProvider.
  // Retorna uma CÓPIA calibrada para o payload da requisição atual.
  // ══════════════════════════════════════════════════════════════════════════
  static List<Map<String, String>> _buildContextWindow(
    List<Map<String, String>> history,
    String contextLabel,
  ) {
    if (contextLabel == 'NOVO') {
      // Assunto novo confirmado pelo classificador — clean slate para evitar
      // mistura de dados clínicos entre casos distintos (segurança do paciente).
      _log('[GeminiV2] NOVO: histórico descartado para este payload (${history.length} entradas)');
      return [];
    }

    // Mesmo assunto — Build 105: janela ampliada para 5 pares (era 3)
    // Suporta diálogos de acompanhamento sem perda de memória conversacional.
    const maxPairs = 5;
    const maxEntries = maxPairs * 2; // 10 entradas = 5 user + 5 model

    if (history.length <= maxEntries) {
      _log('[GeminiV2] MÉDICO: histórico completo (${history.length} entradas)');
      return List.of(history); // já dentro do limite — usa tudo sem truncar
    }

    // Pega as [maxEntries] entradas mais recentes
    final window = history.sublist(history.length - maxEntries);
    _log(
      '[GeminiV2] MÉDICO: janela deslizante ${history.length} → ${window.length} entradas (últimos $maxPairs turnos)',
    );
    return window;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // _executeWithRetry — Wrapper de retry recursivo para o stream
  //
  // Build 135: expandido com Auto-Retry Transitório (Exponential Backoff + Jitter).
  //
  // ARQUITETURA DE RETRY DUPLA:
  //
  //   Camada A — Retry 429 (rate-limit): tratado DENTRO de _streamRequest.
  //     → statusCode 429 com Retry-After header; backoff 5/15/30s.
  //     → Não passa por aqui (acontece no nível HTTP).
  //
  //   Camada B — Retry Transitório 5xx/gRPC (Build 135): tratado AQUI.
  //     → Erros de INFRA que chegam via GeminiChunk.error('http_503') ou 'timeout'.
  //     → Detectados após _streamRequest retornar (o chunk de erro já foi gerado).
  //     → PROBLEMA: o chunk de erro já foi adicionado ao controller antes do retry.
  //     → SOLUÇÃO: usar um controller intermediário por tentativa para capturar
  //       o resultado SEM expor erro prematuro ao controller final do caller.
  //       Se a tentativa falha com erro transitório → espera + nova tentativa.
  //       Se a tentativa falha com erro permanente → propaga ao controller final.
  //       Se a tentativa sucede → pipe chunks para o controller final.
  //
  // ERROS TRANSITÓRIOS (retry permitido):
  //   'http_503'  → HTTP 500/502/503/504 + gRPC RESOURCE_EXHAUSTED/INTERNAL/ABORTED/UNAVAILABLE
  //   'timeout'   → HTTP TimeoutException + gRPC DEADLINE_EXCEEDED
  //   'network'   → SocketException + gRPC CANCELLED (rede instável pode recuperar)
  //   'stream_error' → erro mid-stream (pode ser transiente)
  //
  // ERROS NÃO-TRANSITÓRIOS (sem retry — falha imediata):
  //   'quota'          → quota esgotada + cooldown global já ativado
  //   'api_key_invalid'→ 401/403 — chave errada, retry não adianta
  //   'unexpected'     → exceção desconhecida
  //   Erros com conteúdo parcial → exibir parcial ao invés de retry
  //
  // CANCELAMENTO: se controller.isClosed durante o wait → aborta imediatamente.
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> _executeWithRetry({
    required StreamController<GeminiChunk> controller,
    required String apiKey,
    required String userMessage,
    required String systemPrompt,
    required List<Map<String, String>> history,
    required bool useGrounding,
    required int attempt,
    // Build 135: contagem de tentativas transitórias (separada da contagem 429)
    int transientAttempt = 0,
  }) async {
    if (controller.isClosed) return;

    // ── Usa controller intermediário para interceptar erros antes de expor ──
    // Isso permite que o retry transitório aconteça SEM enviar chunk de erro
    // ao controller final enquanto ainda há tentativas disponíveis.
    final intermediate = StreamController<GeminiChunk>();
    GeminiChunk? capturedError;
    final chunks = <GeminiChunk>[];
    bool hadContent = false;

    // Subscrevemos o intermediário para capturar tudo
    final completer = Completer<void>();
    intermediate.stream.listen(
      (chunk) {
        if (chunk.isError) {
          capturedError = chunk;
        } else {
          if (chunk.text.isNotEmpty) hadContent = true;
          chunks.add(chunk);
        }
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      cancelOnError: false,
    );

    try {
      await _streamRequest(
        controller: intermediate,
        apiKey: apiKey,
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        history: history,
        useGrounding: useGrounding,
        attempt: attempt,
      );
    } catch (e) {
      _log('[GeminiV2] _executeWithRetry: exceção inesperada: $e');
      if (!intermediate.isClosed) {
        intermediate
          ..add(GeminiChunk.error('unexpected'))
          ..close();
      }
    }

    // Aguarda o intermediate finalizar
    try {
      await completer.future;
    } catch (_) {}

    // ── Verifica se houve erro transitório e se vale retry ───────────────────
    final isTransientError = capturedError != null &&
        (capturedError!.errorCode == 'http_503' ||
         capturedError!.errorCode == 'timeout'  ||
         capturedError!.errorCode == 'network'  ||
         capturedError!.errorCode == 'stream_error');

    // Se houve conteúdo parcial substancial (>40 chars) → não retentamos,
    // entregamos o parcial (compatível com a lógica do AppProvider).
    final partialCharsTotal = chunks.fold<int>(0, (sum, c) => sum + c.text.length);
    final hasPartialContent  = hadContent && partialCharsTotal > 40;

    if (isTransientError && !hasPartialContent &&
        transientAttempt < _maxTransientRetries) {

      if (controller.isClosed) return; // cancelamento manual durante retry

      // ── Backoff Exponencial + Jitter ──────────────────────────────────────
      final baseDelay = _transientRetryBaseDelays[transientAttempt];
      final jitterMs  = _rng.nextInt(_transientJitterMs * 2 + 1) - _transientJitterMs;
      final waitMs    = (baseDelay.inMilliseconds + jitterMs).clamp(500, 30000);
      final waitDur   = Duration(milliseconds: waitMs);

      _log(
        '[GeminiV2] Build 135: erro transitório (${capturedError!.errorCode}) — '
        'retry ${transientAttempt + 1}/$_maxTransientRetries em ${waitDur.inMilliseconds}ms '
        '(base ${baseDelay.inSeconds}s ± ${jitterMs}ms jitter)',
      );

      // Aguarda com verificação de cancelamento a cada 500ms
      final waitEnd = DateTime.now().add(waitDur);
      while (DateTime.now().isBefore(waitEnd)) {
        if (controller.isClosed) {
          _log('[GeminiV2] Build 135: retry cancelado — controller fechado durante wait');
          return;
        }
        final remaining = waitEnd.difference(DateTime.now());
        await Future.delayed(
          remaining > const Duration(milliseconds: 500)
              ? const Duration(milliseconds: 500)
              : remaining,
        );
      }

      if (controller.isClosed) return;

      _log('[GeminiV2] Build 135: iniciando tentativa transitória ${transientAttempt + 2}');
      return _executeWithRetry(
        controller: controller,
        apiKey: apiKey,
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        history: history,
        useGrounding: useGrounding,
        attempt: attempt,                        // attempt 429 preservado
        transientAttempt: transientAttempt + 1,  // contagem transitória avança
      );
    }

    // ── Propaga todos os chunks coletados para o controller final ─────────────
    // Se chegamos aqui: sucesso, erro não-transitório, ou esgotou retries.
    if (controller.isClosed) return;

    for (final chunk in chunks) {
      if (controller.isClosed) break;
      controller.add(chunk);
    }

    if (capturedError != null && !controller.isClosed) {
      // Esgotou retries ou erro não-transitório → propaga erro original
      if (isTransientError && transientAttempt >= _maxTransientRetries) {
        _log(
          '[GeminiV2] Build 135: ${_maxTransientRetries} retries transitórios esgotados — '
          'propagando ${capturedError!.errorCode} para UI',
        );
      }
      controller
        ..add(capturedError!)
        ..close();
    } else if (!controller.isClosed) {
      controller.close();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // _streamRequest — Requisição SSE blindada (CAMADAS 1, 3 e 4)
  //
  // MONTAGEM DO PAYLOAD:
  //   system_instruction → prefixo de ferro + systemPrompt do AiService
  //                        Injetado isolado (não faz parte do histórico)
  //                        Equivalente a Content.system() do SDK Firebase AI
  //
  //   contents           → histórico janelado + nova mensagem do usuário
  //                        [{role:'user'/'model', parts:[{text:'...'}]}]
  //
  //   generationConfig   → maxOutputTokens:3200, temp:0.4 (thinkingConfig omitido)
  //
  //   safetySettings     → BLOCK_NONE em todas as categorias (conteúdo médico
  //                        frequentemente é bloqueado por filtros genéricos)
  //
  // PARSING SSE:
  //   Lê o stream de bytes, monta linhas, parseia JSON de "data: {...}"
  //   _extractText() → CAMADA 1: filtra 6 tipos de parts não-textuais
  //   Apenas texto puro do usuário chega ao controller (e portanto à UI)
  //
  // TRATAMENTO DE ERROS:
  //   429 → retry com backoff progressivo (5s/15s/30s) até _maxRetries
  //         Se esgotou retries → cooldown global de 60s
  //   401/403 → api_key_invalid (sem retry — chave inválida não muda)
  //   SAFETY/RECITATION finishReason → tenta sem grounding; se já sem → done
  //   MAX_TOKENS finishReason → resposta parcial entregue, emite done
  //   Timeout HTTP → GeminiChunk.error('timeout')
  //   Exceção de rede → GeminiChunk.error('network')
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> _streamRequest({
    required StreamController<GeminiChunk> controller,
    required String apiKey,
    required String userMessage,
    required String systemPrompt,
    required List<Map<String, String>> history,
    required bool useGrounding,
    required int attempt,
  }) async {
    final url = Uri.parse('$_endpointStream&key=$apiKey');

    // ── CAMADA 3: Injeta prefixo de ferro ANTES do systemPrompt ──────────────
    // O modelo lê _systemPromptPrefix antes de qualquer instrução do AiService.
    // Garante proibição de CoT visível mesmo sem thinkingBudget funcionar.
    final blindedSystemPrompt = '$_systemPromptPrefix$systemPrompt';

    // ── Monta contents: histórico janelado (já calibrado) + nova mensagem ─────
    // Mapeamento de roles: AppProvider usa 'assistant', Gemini API usa 'model'
    final contents = <Map<String, dynamic>>[];
    for (final entry in history) {
      final role = entry['role'] == 'assistant' ? 'model' : 'user';
      contents.add({
        'role': role,
        'parts': [
          {'text': entry['content'] ?? ''}
        ],
      });
    }
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ],
    });

    // ── Corpo da requisição blindado ──────────────────────────────────────────
    final body = <String, dynamic>{
      // system_instruction — isolado do histórico, lido pelo modelo como
      // instrução de sistema (não como turno de conversa). Esta é a forma
      // correta de injetar system prompts na API REST do Gemini.
      'system_instruction': {
        'parts': [
          {'text': blindedSystemPrompt}
        ],
      },
      'contents': contents,
      'generationConfig': {
        // maxOutputTokens: 3200
        //   Previne corte abrupto de texto no meio do streaming.
        //   3200 tokens ≈ 12.800 chars → suporta MODO FARMACO completo
        //   (prompt de 19 seções + RAG injetado + resposta clínica longa).
        //   Build 93: aumentado de 2048→3200 após análise de truncamentos.
        'maxOutputTokens': 3200,

        // temperature: 0.4 — equilíbrio entre precisão clínica e fluência.
        // Valores > 0.6 aumentam risco de alucinação em contexto médico.
        'temperature': 0.4,
        'topP': 0.95,
        'topK': 40,

        // thinkingConfig REMOVIDO intencionalmente do payload do stream.
        //
        // gemini-2.5-flash-lite rejeita esta chave no endpoint streamGenerateContent
        // com erro 400 "Unknown field" — o modelo lite não suporta controle de
        // thinkingBudget via generationConfig no stream.
        //
        // A proteção anti-CoT é mantida por duas camadas redundantes:
        //   [B] _systemPromptPrefix BLOCO 0/1 → instrução direta ao modelo
        //   [C] _extractText() + _looksLikeInternalReasoning() → filtros no JSON
        //
        // O thinkingConfig permanece APENAS no classifier (_classifyContext),
        // onde o modelo sync aceita a chave e a velocidade é crítica (~60 tokens).
      },

      // safetySettings — BLOCK_NONE em todas as categorias.
      // Necessário para conteúdo médico: filtros genéricos bloqueiam
      // discussões de overdose, automutilação, etc., que são legítimas
      // em contexto clínico educacional.
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_NONE',
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_NONE',
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_NONE',
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_NONE',
        },
      ],
    };

    // Google Search Grounding — ativa busca na web para informações atuais.
    // Desativado automaticamente em retry de SAFETY/RECITATION.
    if (useGrounding) {
      body['tools'] = [
        {'google_search': {}}
      ];
    }

    // ── Envia requisição HTTP com stream de resposta ──────────────────────────
    late http.StreamedResponse response;
    try {
      final request = http.Request('POST', url)
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(body);

      response = await request.send().timeout(const Duration(seconds: 60));
    } on TimeoutException {
      _log('[GeminiV2] timeout na conexão HTTP (60s)');
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error('timeout'))
          ..close();
      }
      return;
    } catch (e) {
      // ══════════════════════════════════════════════════════════════════════
      // Build 134 — Blindagem gRPC + 5xx Expandida
      //
      // Classifica erros brutos da infraestrutura Google em 3 categorias:
      //
      // CATEGORIA A — Sobrecarga / Indisponibilidade (→ http_503):
      //   Build 132: HTTP 503/500/unavailable/overloaded
      //   Build 134: RESOURCE_EXHAUSTED (quota gRPC), UNAVAILABLE (gRPC status 14),
      //              INTERNAL (gRPC status 13), ABORTED (gRPC status 10)
      //   Mapeamento: GeminiChunk.error('http_503') → card bilíngue de suporte
      //
      // CATEGORIA B — Quota / Rate Limit (→ quota):
      //   Build 134: RESOURCE_EXHAUSTED pode ser quota além de sobrecarga.
      //   Verificado ANTES da categoria A para dar feedback mais específico.
      //
      // CATEGORIA C — Timeout / Deadline (→ timeout):
      //   Build 134: DEADLINE_EXCEEDED (gRPC status 4)
      //   Mapeamento: GeminiChunk.error('timeout') → mesmo card de timeout HTTP
      //
      // CATEGORIA D — Cancelamento (→ network):
      //   Build 134: CANCELLED (gRPC status 1)
      //   Geralmente por shutdown do cliente — trata como network error
      //
      // CATEGORIA E — SocketException / conectividade (→ network):
      //   Mantido do Build 132 integralmente.
      // ══════════════════════════════════════════════════════════════════════
      final errStr = e.toString().toLowerCase();

      // ── CATEGORIA A: Sobrecarga / Indisponibilidade → http_503 ───────────
      // gRPC RESOURCE_EXHAUSTED pode indicar sobrecarga de infraestrutura
      // (além de quota). UNAVAILABLE, INTERNAL e ABORTED são erros do servidor.
      // HTTP 503/500/unavailable/overloaded mantidos do Build 132.
      if (errStr.contains('503') ||
          errStr.contains('500') ||
          errStr.contains('unavailable') ||
          errStr.contains('service unavailable') ||
          errStr.contains('overloaded') ||
          errStr.contains('resource_exhausted') ||   // gRPC status 8
          errStr.contains('internal') ||             // gRPC status 13
          errStr.contains('aborted')) {              // gRPC status 10
        _log('[GeminiV2] infraestrutura Google instável (5xx/gRPC): $e');
        if (!controller.isClosed) {
          controller
            ..add(GeminiChunk.error('http_503'))
            ..close();
        }
        return;
      }

      // ── CATEGORIA C: Timeout / Deadline Exceeded → timeout ───────────────
      // DEADLINE_EXCEEDED (gRPC status 4): a requisição excedeu o prazo máximo.
      // Mapeado para 'timeout' — mesmo handler da TimeoutException HTTP.
      if (errStr.contains('deadline_exceeded') ||    // gRPC status 4
          errStr.contains('deadline exceeded')) {
        _log('[GeminiV2] deadline excedido (gRPC DEADLINE_EXCEEDED): $e');
        if (!controller.isClosed) {
          controller
            ..add(GeminiChunk.error('timeout'))
            ..close();
        }
        return;
      }

      // ── CATEGORIA D: Cancelamento → network ──────────────────────────────
      // CANCELLED (gRPC status 1): cliente ou servidor cancelou a operação.
      // Tratado como perda de rede — o usuário pode tentar novamente.
      if (errStr.contains('cancelled') ||            // gRPC status 1 (en-US)
          errStr.contains('canceled')) {             // variante americana
        _log('[GeminiV2] requisição cancelada (gRPC CANCELLED): $e');
        if (!controller.isClosed) {
          controller
            ..add(GeminiChunk.error('network'))
            ..close();
        }
        return;
      }

      // ── CATEGORIA E: SocketException / conectividade → network ───────────
      // SocketException → perda total de conectividade (Wi-Fi/4G desconectado)
      // Outros → falha de conexão genérica
      final isSocket = errStr.contains('socketexception') ||
          errStr.contains('connection refused') ||
          errStr.contains('no address associated') ||
          errStr.contains('network is unreachable') ||
          errStr.contains('connection reset') ||
          errStr.contains('broken pipe') ||
          errStr.contains('os error');
      _log('[GeminiV2] erro de rede${isSocket ? " (SocketException)" : ""}: $e');
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error('network'))
          ..close();
      }
      return;
    }

    // ── Tratamento de erros HTTP (antes de ler o stream) ─────────────────────

    if (response.statusCode == 429) {
      if (attempt < _maxRetries) {
        // Calcula tempo de espera — respeita header Retry-After se disponível
        Duration waitTime = _retryBackoff[attempt];
        final retryAfter = response.headers['retry-after'] ??
            response.headers['x-ratelimit-reset-requests'];
        if (retryAfter != null) {
          final retrySeconds = int.tryParse(retryAfter);
          if (retrySeconds != null && retrySeconds > 0) {
            waitTime = Duration(seconds: retrySeconds.clamp(2, 60));
          }
        }
  _log(
          '[GeminiV2] 429 rate limit — retry ${attempt + 1}/$_maxRetries '
          'em ${waitTime.inSeconds}s',
        );
        await Future.delayed(waitTime);
        if (controller.isClosed) return;
        return _streamRequest(
          controller: controller,
          apiKey: apiKey,
          userMessage: userMessage,
          systemPrompt: systemPrompt,
          history: history,
          useGrounding: useGrounding,
          attempt: attempt + 1,
        );
      }
      // Esgotou todas as tentativas → cooldown global
      _quotaUntil = DateTime.now().add(_quotaCooldown);
      _log(
        '[GeminiV2] 429 definitivo — cooldown de ${_quotaCooldown.inMinutes}min ativado',
      );
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error('quota'))
          ..close();
      }
      return;
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      _log('[GeminiV2] ${response.statusCode}: chave API inválida/sem permissão');
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error('api_key_invalid'))
          ..close();
      }
      return;
    }

    if (response.statusCode != 200) {
      _log('[GeminiV2] HTTP inesperado: ${response.statusCode}');
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error('http_${response.statusCode}'))
          ..close();
      }
      return;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // LEITURA DO STREAM SSE (CAMADA 1 — filtragem de CoT em tempo real)
    //
    // Formato Gemini SSE:
    //   data: {"candidates":[{"content":{"parts":[{"text":"..."}]},...}]}\n\n
    //
    // Cada linha "data: {...}" é um evento JSON independente.
    // Eventos "[DONE]" ou vazios são ignorados.
    //
    // _extractText() é chamado em CADA evento — filtra 6 tipos de parts
    // não-textuais antes de qualquer char chegar ao StringBuffer da UI.
    //
    // finishReason tratamento:
    //   STOP        → conclusão normal — emite done
    //   MAX_TOKENS  → corte por limite de tokens — emite done (parcial OK)
    //   SAFETY      → filtro de segurança — retry sem grounding
    //   RECITATION  → repetição detectada — retry sem grounding
    //   outros      → trata como STOP
    // ══════════════════════════════════════════════════════════════════════════
    final lineBuffer = StringBuffer();
    bool hadContent = false;
    bool finishEmitted = false; // guarda anti-done-duplo

    // ── Build 135: Watchdog Timer Mid-Stream ─────────────────────────────────
    // Detecta streams congelados: SSE abriu mas não emite novos chunks por 45s.
    //
    // Comportamento:
    //   • Timer criado imediatamente antes do loop SSE.
    //   • RESETADO a cada chunk válido recebido (qualquer bytes > 0).
    //   • DISPARADO se 45s passarem sem chunks → encerra controller com 'timeout'.
    //   • CANCELADO em onDone, onError e no finally externo.
    //   • Nunca dispara se controller já foi fechado (guard isClosed).
    //
    // Proteções anti-memory-leak:
    //   • watchdogTimer é sempre cancelado no finally abaixo.
    //   • Guard !controller.isClosed antes de emitir evento.
    Timer? watchdogTimer;
    bool watchdogFired = false;

    void resetWatchdog() {
      watchdogTimer?.cancel();
      if (controller.isClosed || finishEmitted || watchdogFired) return;
      watchdogTimer = Timer(_watchdogTimeout, () {
        if (controller.isClosed || finishEmitted) return;
        watchdogFired = true;
        _log(
          '[GeminiV2] Build 135: WATCHDOG disparado — stream congelado por '
          '${_watchdogTimeout.inSeconds}s sem chunks (Build 135)',
        );
        if (!controller.isClosed) {
          controller
            ..add(GeminiChunk.error('timeout'))
            ..close();
        }
      });
    }

    // Inicia watchdog antes do loop
    resetWatchdog();

    try {
      await for (final bytes in response.stream) {
        if (controller.isClosed) break;
        if (watchdogFired) break; // watchdog já encerrou — para o loop

        // Reset watchdog a cada chunk recebido (qualquer bytes > 0)
        if (bytes.isNotEmpty) resetWatchdog();

        final rawChunk = utf8.decode(bytes, allowMalformed: true);

        // Processa char a char — monta linhas completas terminadas em \n
        for (final char in rawChunk.split('')) {
          if (char == '\n') {
            final line = lineBuffer.toString().trim();
            lineBuffer.clear();

            // Ignora linhas que não sejam eventos SSE
            if (!line.startsWith('data: ')) continue;
            final jsonStr = line.substring(6).trim();
            if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;

            try {
              final eventData = jsonDecode(jsonStr) as Map<String, dynamic>;

              // ── CAMADA 1: Filtro rigoroso de CoT ──────────────────────────
              // _extractText() descarta qualquer part com thought/CoT/metadata.
              // Zero caracteres de raciocínio interno chegam ao controller.
              final textFragment = _extractText(eventData);
              final finishReason = _extractFinishReason(eventData);

              // ── SAFETY/RECITATION guard: não emite isDone=true se vai fazer retry
              final shouldRetryWithoutGrounding =
                  (finishReason == 'SAFETY' || finishReason == 'RECITATION') &&
                  useGrounding;

              if (textFragment.isNotEmpty) {
                hadContent = true;
                if (!controller.isClosed) {
                  controller.add(GeminiChunk(
                    text: textFragment,
                    // isDone só é true se há finishReason E não haverá retry.
                    // Sem esse guard, a UI recebe isDone antes do retry ser
                    // executado, quebrando a sincronia do streaming.
                    isDone: finishReason != null && !shouldRetryWithoutGrounding,
                  ));
                }
              } else if (finishReason != null &&
                  !hadContent &&
                  !shouldRetryWithoutGrounding) {
                // Chunk vazio com finishReason sem retry pendente
                // (ex: SAFETY sem texto gerado, já na segunda tentativa)
                if (!controller.isClosed) {
                  controller.add(const GeminiChunk(text: '', isDone: true));
                }
              }

              // ── Tratamento de finishReason ────────────────────────────────
              if (finishReason != null) {
          _log(
                  '[GeminiV2] finishReason=$finishReason '
                  '(conteúdo: ${hadContent ? 'sim' : 'nenhum'})',
                );

                switch (finishReason) {
                  case 'STOP':
                    // Conclusão normal — done já foi emitido acima se havia texto
                    finishEmitted = true;

                  case 'MAX_TOKENS':
                    // Limite de tokens atingido — resposta parcial entregue.
                    // maxOutputTokens=3200 previne isso na maioria dos casos.
                    // Quando ocorre, a resposta parcial é válida e útil.
              _log(
                      '[GeminiV2] MAX_TOKENS: resposta parcial entregue '
                      '(aumentar maxOutputTokens se recorrente)',
                    );
                    finishEmitted = true;

                  case 'SAFETY':
                  case 'RECITATION':
                    // Filtro de segurança ou detecção de recitação.
                    // Primeira tentativa: retry sem grounding (que pode
                    // trazer conteúdo que aciona o filtro).
                    if (useGrounding && !controller.isClosed) {
                _log(
                        '[GeminiV2] $finishReason: retry sem grounding',
                      );
                      return _streamRequest(
                        controller: controller,
                        apiKey: apiKey,
                        userMessage: userMessage,
                        systemPrompt: systemPrompt,
                        history: history,
                        useGrounding: false, // desativa grounding no retry
                        attempt: attempt,
                      );
                    }
                    // Já estava sem grounding — encerra sem retry adicional
                    finishEmitted = true;

                  default:
                    // finishReasons desconhecidos tratados como STOP
                    finishEmitted = true;
                }
              }
            } catch (parseError) {
              // JSON mal-formado em chunk — ignora e continua processando
        _log('[GeminiV2] parse error em evento SSE: $parseError');
            }
          } else {
            lineBuffer.write(char);
          }
        }
      }
    } catch (streamError) {
      _log('[GeminiV2] erro durante leitura do stream: $streamError');
      watchdogTimer?.cancel(); // cancela watchdog em erro de stream
      if (!hadContent && !controller.isClosed) {
        controller.add(GeminiChunk.error('stream_error'));
      }
    } finally {
      // Build 135: garante cancelamento do watchdog em TODOS os caminhos de saída.
      // Evita memory leak de Timer mesmo em casos excepcionais.
      watchdogTimer?.cancel();
      watchdogTimer = null;
    }

    // ── Fecha o controller ao terminar o stream ───────────────────────────────
    // Emite GeminiChunk.done apenas se finishReason não foi detectado no stream
    // (ex: stream encerrou abruptamente sem enviar finishReason).
    // Guarda anti-duplicata garante que AppProvider sempre receba o sinal final.
    // Build 135: se watchdog disparou, controller já foi fechado — não re-fechar.
    if (!controller.isClosed && !watchdogFired) {
      if (!finishEmitted) {
        // Stream encerrado sem finishReason explícito — trata como done normal
        controller.add(GeminiChunk.done);
      }
      controller.close();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // _extractText — CAMADA 1: Filtro rigoroso de CoT por evento SSE
  //
  // REGRA CENTRAL: extrair EXCLUSIVAMENTE candidates[0].content.parts[N].text
  //               onde o part NÃO seja pensamento interno do modelo.
  //
  // CONDITIONS DE DESCARTE (6 filtros cumulativos):
  //
  //   1. thought == true
  //      → Part explicitamente marcado como cadeia de pensamento (CoT).
  //        Gemini 2.5 pode gerar esses mesmo sem thinkingConfig no payload
  //        (comportamento de fallback interno do modelo). JAMAIS chega à UI.
  //
  //   2. containsKey('thoughtSignature')
  //      → Assinatura criptográfica que identifica bloco de pensamento.
  //        Aparece em conjunto com thought:true ou isoladamente.
  //
  //   3. containsKey('functionCall')
  //      → Chamada interna a ferramenta (Google Search, code interpreter).
  //        Metadado de uso interno — não é texto para o usuário.
  //
  //   4. containsKey('executableCode')
  //      → Código executável gerado internamente pelo modelo.
  //        Não deve ser exibido como resposta ao usuário.
  //
  //   5. containsKey('codeExecutionResult')
  //      → Resultado de execução de código interno.
  //        Metadado de processamento, não conteúdo de resposta.
  //
  //   6. containsKey('inlineData')
  //      → Dados binários inline (imagens, áudio, etc.).
  //        Não é texto — não processável como string.
  //
  // CONDIÇÃO DE ACEITE:
  //   Part tem chave 'text' (String, não-vazia) E não tem nenhuma das 6 acima.
  //   → Concatenado no buffer e retornado para o controller.
  //
  // Esta função é a ÚLTIMA linha de defesa. Mesmo que _systemPromptPrefix
  // seja contornado por comportamento inesperado do modelo, nenhum char
  // de CoT ou raciocínio interno chega à UI graças aos 7 filtros aqui.
  // ══════════════════════════════════════════════════════════════════════════
  static String _extractText(Map<String, dynamic> data) {
    try {
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return '';

      final candidate = candidates[0] as Map<String, dynamic>;
      final parts = candidate['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) return '';

      final buffer = StringBuffer();

      for (final rawPart in parts) {
        final part = rawPart as Map<String, dynamic>;

        // ── 6 filtros de descarte (ordem importa: thought primeiro) ──────
        if (part['thought'] == true) continue;           // [1] CoT explícito
        if (part.containsKey('thoughtSignature')) continue; // [2] assinatura CoT
        if (part.containsKey('functionCall')) continue;     // [3] tool call
        if (part.containsKey('executableCode')) continue;   // [4] código interno
        if (part.containsKey('codeExecutionResult')) continue; // [5] resultado exec
        if (part.containsKey('inlineData')) continue;       // [6] binário inline

        // ── Aceita apenas texto puro ─────────────────────────────────────
        final text = part['text'] as String?;
        if (text != null && text.isNotEmpty) {
          // ── CAMADA 1b: Heurística anti-vazamento dentro da chave 'text' ──
          // Defesa de último recurso: mesmo que o modelo injete raciocínio
          // interno como texto comum (bypassando thought=true e o prefixo),
          // descartamos o part inteiro se contiver padrões de CoT reconhecidos.
          if (_looksLikeInternalReasoning(text)) continue;
          buffer.write(text);
        }
      }

      return buffer.toString();
    } catch (_) {
      // Exceção no parsing → retorna string vazia (seguro para o stream)
      return '';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // _looksLikeInternalReasoning — CAMADA 1b: Heurística anti-CoT no texto
  //
  // Detecta padrões de raciocínio interno que podem vazar dentro da chave
  // 'text' mesmo após _systemPromptPrefix BLOCOS 0/1 e os 6 filtros JSON.
  // Chamado por _extractText() para cada part aceito pelos 6 filtros JSON.
  //
  // CALIBRAÇÃO v5.1 (Build 93) — falso-positivo crítico corrigido:
  //   'i should' e 'i need to' removidos. Eram substrings ambíguas que
  //   apareciam em citações de diretrizes médicas legítimas, ex:
  //     "potassium levels above 6.5 mEq/L — i need to start treatment"
  //     "guidelines suggest i should consider calcium gluconate first"
  //   Causavam corte abrupto do stream no meio de respostas clínicas válidas.
  //   A proteção dessas frases é suficientemente coberta pelo BLOCO 0 do
  //   _systemPromptPrefix (instrução direta ao modelo, camada B).
  //
  // Padrões mantidos — longos, explícitos e inequívocos:
  //   • 'the user is asking' / 'the user wants' → meta-comentário de intent
  //   • '<thinking>'                            → tag XML de CoT explícita
  //   • '[análise_interna]' / '[revisão_interna]' → tags bracket de CoT
  //   • 'scratchpad'                            → rascunho interno explícito
  //
  // Retorna true → part descartado (não chega à UI).
  // Retorna false → part seguro para exibição.
  // ══════════════════════════════════════════════════════════════════════════
  // _looksLikeInternalReasoning — CAMADA 1b v5.3 (Build 97)
  //
  // Build 97 — adicionado: detecção de tool_code/google_search leaks.
  // Quando o Google Search Grounding está ativo, o modelo Gemini pode vazar
  // blocos de chamada de ferramenta como texto plain em vez de functionCall part.
  // Exemplo de vazamento documentado no screenshot IMG_2909.jpg:
  //   "tool_code\nprint(google_search.search(queries=[\"manejo y tratamiento..."
  // Este bloco é puramente interno e jamais deve ser exibido ao médico.
  //
  // NOTA IMPORTANTE: Este filtro age sobre CADA CHUNK individual do stream SSE.
  // Se o cabeçalho vier num chunk separado (o que acontece frequentemente),
  // ele é descartado antes de entrar no buffer acumulado. A _cleanAiText()
  // (CAMADA 2) pega o residual caso o padrão esteja num chunk misto.
  static bool _looksLikeInternalReasoning(String text) {
    final lower = text.toLowerCase();

    // ── Build 97: tool_code / google_search leak detector ──────────────────
    // Captura blocos de chamada de ferramenta vazados como texto plain.
    // Padrões inequívocos — nunca aparecem em texto clínico legítimo.
    if (lower.contains('tool_code')) return true;
    if (lower.contains('google_search')) return true;
    if (lower.contains('print(google')) return true;
    if (lower.contains('print(perplexity')) return true;
    if (lower.contains('perplexity_search')) return true;
    if (lower.contains('search_query')) return true;
    if (lower.contains('queries=[')) return true;
    if (lower.contains('```tool_code')) return true;
    if (lower.contains('```python')) return true;
    if (lower.contains('```json\n{')) return true;

    // ── Padrões longos e inequívocos de CoT (calibração v5.1) ──────────────
    if (lower.contains('the user is asking')) return true;
    if (lower.contains('the user wants')) return true;
    if (lower.contains('<thinking>')) return true;
    if (lower.contains('[análise_interna]')) return true;
    if (lower.contains('[revisão_interna]')) return true;
    if (lower.contains('scratchpad')) return true;

    // Build 96 — catch-all bilíngue "Confian[za|ça] Clínica" v6.0
    // Padrão ampliado: captura QUALQUER variação que contenha "confian" + "cl"
    // — sem dois-pontos, com markdown, com pipe, uppercase, etc.
    if (lower.contains('confianza cl') ||
        lower.contains('confiança cl') ||
        lower.contains('confianza:') ||
        lower.contains('confiança:') ||
        lower.contains('clinical confidence') ||
        lower.contains('nivel de confianza') ||
        lower.contains('nível de confiança') ||
        lower.contains('nivel de confiança') ||
        lower.contains('nível de confianza')) {
      return true;
    }
    // Regex catch-all: qualquer chunk que contenha "confian" seguido de
    // espaços/pontuação/markdown e depois "cl" (clínica/clinica)
    if (RegExp(r'confian[zç]a', caseSensitive: false).hasMatch(lower)) {
      return true;
    }

    // ── Build 126: padrões de CoT — calibração conservadora ─────────────────
    // Build 126 REMOVE os seguintes padrões por causarem falsos-positivos críticos:
    //   'vou responder'    → "Vou responder ao seu caso de IAM com..."  (LEGÍTIMO)
    //   'voy a responder'  → "Voy a responder sobre el IAM..."          (LEGÍTIMO)
    //   'conforme solicitado' → texto clínico normal                    (LEGÍTIMO)
    //   'según lo solicitado' → idem                                    (LEGÍTIMO)
    //   'a consulta é sobre' / 'la consulta es sobre' → intro legítima  (LEGÍTIMO)
    //   'para responder a esta' / 'para responder esta' → clínico       (LEGÍTIMO)
    //   'a pergunta do usuário' → pode ser em resposta educativa        (LEGÍTIMO)
    //
    // Mantidos apenas os inequívocos e longos (só aparecem em CoT real):
    if (lower.contains('el usuario ha indicado que')) return true;
    if (lower.contains('el usuario ha proporcionado')) return true;
    if (lower.contains('el usuario ha solicitado que')) return true;
    if (lower.contains('o usuário informou que')) return true;
    if (lower.contains('o usuário forneceu os seguintes')) return true;
    if (lower.contains('o usuário indicou que')) return true;

    // Build 128 — Firewall de strings: captura vazamentos de pseudocódigo estrutural
    // que o Gemini 2.5 Flash-Lite pode ecoar diretamente no output da UI.
    if (lower.contains('detector de capa')) return true;
    if (lower.contains('detector de camada')) return true;
    if (lower.contains('capa 1 obligatoria')) return true;
    if (lower.contains('camada 1 obrigatoria')) return true;
    if (lower.contains('bloque 1')) return true;
    if (lower.contains('bloque 2')) return true;
    if (lower.contains('bloque 3')) return true;
    if (lower.contains('bloco 1')) return true;
    if (lower.contains('bloco 2')) return true;
    if (lower.contains('bloco 3')) return true;
    if (lower.contains('▶▶▶')) return true;
    if (lower.contains('◀◀◀')) return true;
    if (lower.contains('item 0 —')) return true;
    if (lower.contains('fin item 0')) return true;
    if (lower.contains('fim item 0')) return true;

    // Build 130 — Firewall adicional: captura marcadores de prompt que
    // o Gemini 2.5 Flash-Lite pode ecoar após refatoração do contextAnchor/RAG.
    if (lower.contains('datos_verificados')) return true;
    if (lower.contains('dados_verificados')) return true;
    if (lower.contains('contexto_interno')) return true;
    if (lower.contains('verificacion interna')) return true;
    if (lower.contains('verificacao interna')) return true;
    if (lower.contains('silenciosa')) return true;
    if (lower.contains('rag cross-check')) return true;

    // Build 131 — Firewall anti-preâmbulo: captura frases de raciocínio introdutório
    // que o modelo ecoa antes de abrir os blocos clínicos visuais.
    if (lower.contains('sin contexto adicional')) return true;
    if (lower.contains('sem contexto adicional')) return true;
    if (lower.contains('activa el protocolo')) return true;
    if (lower.contains('ativa o protocolo')) return true;
    if (lower.contains('protocolo de emergencia estándar')) return true;
    if (lower.contains('protocolo de emergência padrão')) return true;
    if (lower.contains('acionar emergência')) return true;
    if (lower.contains('acionar emergencia')) return true;
    if (lower.contains('llame al samu')) return true;
    if (lower.contains('ligue para o samu')) return true;
    if (lower.contains('conf de alta prioridad')) return true;
    if (lower.contains('conf de alta prioridade')) return true;

    // Build 132 — Firewall anti-preâmbulo mutante: captura novos padrões de
    // raciocínio introdutório observados em produção (iOS/Web, Gemini Flash-Lite).
    if (lower.contains('motivo:')) return true;
    if (lower.contains('sigla médica')) return true;
    if (lower.contains('sigla medica')) return true;
    if (lower.contains('protocolo de manejo')) return true;

    // Padrão meta-comentário: SOMENTE quando a sentença ABRE com "El usuario solicita..."
    // (primeiros 80 chars do chunk — não aplica se é meio de uma resposta)
    final head = lower.length > 80 ? lower.substring(0, 80) : lower;
    if (RegExp(
      r'^\s*(?:el\s+usuario\s+(?:solicita|proporciona|pregunta|pide|quiere|busca|ha\s+(?:pedido|indicado|proporcionado|solicitado))'
      r'|o\s+usu[aá]rio\s+(?:solicita|fornece|pergunta|pede|quer|busca|indicou|informou|forneceu)'
      r'|the\s+user\s+(?:is\s+asking|asks|wants|requests|provides|has\s+indicated|has\s+asked)'
      r'|baseado\s+(?:no|na)\s+(?:contexto|conversa)'
      r'|basado\s+en\s+(?:el\s+contexto|la\s+conversaci))',
      caseSensitive: false,
    ).hasMatch(head)) {
      return true;
    }

    return false;
  }

  // ── Extrai finishReason do evento SSE ─────────────────────────────────────
  // Retorna null para FINISH_REASON_UNSPECIFIED (chunk intermediário)
  // ou quando não há candidates válidos.
  static String? _extractFinishReason(Map<String, dynamic> data) {
    try {
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;
      final candidate = candidates[0] as Map<String, dynamic>;
      final reason = candidate['finishReason'] as String?;
      // FINISH_REASON_UNSPECIFIED = chunk intermediário, não é conclusão
      if (reason == null || reason == 'FINISH_REASON_UNSPECIFIED') return null;
      return reason;
    } catch (_) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // errorMessage — Mensagens de erro bilíngues (ES/PT) para a UI
  //
  // Chamado pelo AppProvider quando o stream termina com errorCode != null.
  // Inclui hint de cooldown quando relevante (quota error com tempo restante).
  // ══════════════════════════════════════════════════════════════════════════
  static String errorMessage(String code, String lang) {
    final isEs = lang == 'es';
    final cooldownSecs = quotaCooldownRemaining?.inSeconds;
    final cooldownHint =
        (cooldownSecs != null && cooldownSecs > 0) ? ' (~${cooldownSecs}s)' : '';

    return switch (code) {
      'quota' => isEs
          ? 'Límite de consultas alcanzado$cooldownHint. '
              'Intenta de nuevo en un momento. ⚕ Apoyo educacional.'
          : 'Limite de consultas atingido$cooldownHint. '
              'Tente novamente em instantes. ⚕ Apoio educacional.',
      'api_key_invalid' => isEs
          ? 'No se pudo conectar al asistente. '
              'Verifica la configuración de la API. ⚕ Apoyo educacional.'
          : 'Não foi possível conectar ao assistente. '
              'Verifique a configuração da API. ⚕ Apoio educacional.',
      'timeout' => isEs
          ? '🚨 Conexión Requerida\n\n'
              'La consulta tardó demasiado — posible señal débil en el hospital.\n\n'
              'El resto de tus herramientas sigue operando 100% offline:\n'
              '• 💊 Fármacos — base completa embarcada\n'
              '• ⚠️ Interacciones — motor offline activo\n'
              '• 🧮 Calculadoras — sin necesidad de red\n\n'
              'Verifica tu señal y vuelve a intentarlo.'
          : '🚨 Conexão Necessária\n\n'
              'A consulta demorou muito — possível sinal fraco no hospital.\n\n'
              'O restante das suas ferramentas segue operando 100% offline:\n'
              '• 💊 Fármacos — base completa embarcada\n'
              '• ⚠️ Interações — motor offline ativo\n'
              '• 🧮 Calculadoras — sem necessidade de rede\n\n'
              'Verifique seu sinal e tente novamente.',
      'network' => isEs
          ? '🚨 Conexión Requerida\n\n'
              'La IA de MedCases requiere conexión a internet para procesar '
              'análisis cognitivos avanzados.\n\n'
              'El resto de tus herramientas sigue operando 100% offline:\n'
              '• 💊 Fármacos — base completa embarcada\n'
              '• ⚠️ Interacciones — motor offline activo\n'
              '• 🧮 Calculadoras — sin necesidad de red\n\n'
              'Verifica tu señal y vuelve a intentarlo.'
          : '🚨 Conexão Necessária\n\n'
              'A IA do MedCases requer conexão com a internet para processar '
              'análises cognitivas avançadas.\n\n'
              'O restante das suas ferramentas segue operando 100% offline:\n'
              '• 💊 Fármacos — base completa embarcada\n'
              '• ⚠️ Interações — motor offline ativo\n'
              '• 🧮 Calculadoras — sem necessidade de rede\n\n'
              'Verifique seu sinal e tente novamente.',
      // 5xx = instabilidade na infraestrutura do Google Gemini (503, 500, 502, 504)
      'http_503' || 'http_500' || 'http_502' || 'http_504' => isEs
          ? '🚨 Servidor de IA Inestable\n\n'
              'El servicio de Google Gemini está experimentando una sobrecarga temporal.\n\n'
              'El resto de tus herramientas sigue operando 100% offline:\n'
              '• 💊 Fármacos — base completa embarcada\n'
              '• ⚠️ Interacciones — motor offline activo\n'
              '• 🧮 Calculadoras — sin necesidad de red\n\n'
              'Inténtalo de nuevo en unos instantes.'
          : '🚨 Servidor de IA Instável\n\n'
              'O serviço do Google Gemini está enfrentando uma sobrecarga temporária.\n\n'
              'O restante das suas ferramentas segue operando 100% offline:\n'
              '• 💊 Fármacos — base completa embarcada\n'
              '• ⚠️ Interações — motor offline ativo\n'
              '• 🧮 Calculadoras — sem necessidade de rede\n\n'
              'Tente novamente em alguns instantes.',
      // stream_error = SSE caiu no meio → tratado como falha de rede
      'stream_error' => isEs
          ? '🚨 Conexión Requerida\n\n'
              'La conexión con el servidor de IA se interrumpió.\n\n'
              'El resto de tus herramientas sigue operando 100% offline:\n'
              '• 💊 Fármacos — base completa embarcada\n'
              '• ⚠️ Interacciones — motor offline activo\n'
              '• 🧮 Calculadoras — sin necesidad de red\n\n'
              'Verifica tu señal y vuelve a intentarlo.'
          : '🚨 Conexão Necessária\n\n'
              'A conexão com o servidor de IA foi interrompida.\n\n'
              'O restante das suas ferramentas segue operando 100% offline:\n'
              '• 💊 Fármacos — base completa embarcada\n'
              '• ⚠️ Interações — motor offline ativo\n'
              '• 🧮 Calculadoras — sem necessidade de rede\n\n'
              'Verifique seu sinal e tente novamente.',
      _ => isEs
          ? 'No pude procesar esa consulta. '
              '¿Puedes reformularla? ⚕ Apoyo educacional.'
          : 'Não consegui processar essa consulta. '
              'Pode reformulá-la? ⚕ Apoio educacional.',
    };
  }
}
