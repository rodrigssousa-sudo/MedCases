/**
 * ═══════════════════════════════════════════════════════════════════════════
 * MedCases Pro — AI Gateway Server  v2.4.0  (Build 151)
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * ARQUITETURA:
 *   Express.js + Fetch Streams (Node 18+) → SSE para Flutter
 *
 * ENDPOINTS:
 *   POST /api/ai/stream   → Streaming SSE (resposta principal ao usuário)
 *   POST /api/ai/sync     → Resposta síncrona (Context Classifier interno)
 *   GET  /health          → Health check (Digital Ocean App Platform)
 *
 * PROBLEMAS RESOLVIDOS:
 *   1. Chain-of-Thought Leakage  → ANTI_COGNITION_LEAK_PROMPT + filtro SSE
 *   2. Streaming nativo          → streamGenerateContent com alt=sse
 *   3. Raciocínio em inglês      → filtros de parágrafo + prefixo fixo
 *   4. Abertura com metadados    → FIRST_CHARACTER_CONSTRAINT + cleanChunk()
 *   5. SSE Buffering (B146)      → socket.write direto + TCP_NODELAY + flush
 *   6. CoT Leakage via lista    → ANTI_COGNITION_LEAK_PROMPT simplificado (B147)
 *   7. Metalinguagem inglesa    → cleanChunk() heurística de idioma (B147)
 *   8. LINE BUDGET dinâmico    → PROMPT_MODO_PLANTAO/ESTUDO Motor de Partida (B149-B151)
 *   9. TRAVA DE FALLBACK       → Modo Plantão recusa termos sem conduta direta (B150)
 *  10. Prompts monolíticos     → PROMPT_MODO_PLANTAO / PROMPT_MODO_ESTUDO isolados (B151)
 *
 * ANTI-BUFFERING (Build 146):
 *   O Digital Ocean App Platform usa um proxy Nginx interno que pode segurar
 *   dados TCP antes de enviá-los ao cliente em lotes (Nagle's Algorithm).
 *   Três camadas de desbloqueio, em ordem de prioridade:
 *
 *   CAMADA A — Headers corretos:
 *     Cache-Control: no-cache, no-transform   (no-transform é crítico: impede
 *       que proxies intermediários comprimam/modifiquem o payload SSE)
 *     X-Accel-Buffering: no                   (instrução direta ao Nginx)
 *
 *   CAMADA B — TCP_NODELAY no socket:
 *     res.socket.setNoDelay(true) desativa o Algoritmo de Nagle no nível TCP.
 *     Nagle agrupa pacotes pequenos em um único pacote maior para eficiência —
 *     comportamento correto para HTTP convencional mas catastrófico para SSE,
 *     onde cada chunk deve sair imediatamente. Com TCP_NODELAY cada write()
 *     vira um pacote TCP independente, sem esperar por mais dados.
 *
 *   CAMADA C — Write direto ao socket (bypass do buffer do Express):
 *     _writeSseRaw() escreve o frame SSE como string ASCII no socket TCP
 *     subjacente em vez de usar res.write() (que pode enfileirar no buffer
 *     interno do stream writable do Node). Garante saída no mesmo tick do
 *     event loop em que o chunk chegou do Gemini.
 *
 * DEPLOY (Digital Ocean App Platform):
 *   Variável de ambiente obrigatória:
 *     GEMINI_API_KEY  → chave de API do Gemini 2.5 Flash Lite
 *   Opcionais:
 *     PORT            → porta HTTP (padrão: 8080)
 *     ALLOWED_ORIGIN  → domínio Flutter Web (padrão: https://medcasespro.com)
 *     NODE_ENV        → 'production' (padrão)
 *     LOG_LEVEL       → 'info' | 'debug' | 'silent' (padrão: 'info')
 *
 * ═══════════════════════════════════════════════════════════════════════════
 */

'use strict';

// ── Dependências ──────────────────────────────────────────────────────────────
const express    = require('express');
const cors       = require('cors');
const helmet     = require('helmet');
const rateLimit  = require('express-rate-limit');

// ── Configuração de ambiente ──────────────────────────────────────────────────
const PORT           = parseInt(process.env.PORT ?? '8080', 10);
const GEMINI_API_KEY = process.env.GEMINI_API_KEY ?? '';
const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN ?? 'https://medcasespro.com';
const LOG_LEVEL      = process.env.LOG_LEVEL ?? 'info';
const IS_PROD        = process.env.NODE_ENV === 'production';

// ── Logger minimalista ────────────────────────────────────────────────────────
const log = {
  info:  (...a) => LOG_LEVEL !== 'silent' && console.log('[INFO]', ...a),
  debug: (...a) => LOG_LEVEL === 'debug'  && console.log('[DEBUG]', ...a),
  warn:  (...a) => LOG_LEVEL !== 'silent' && console.warn('[WARN]', ...a),
  error: (...a) => console.error('[ERROR]', ...a),
};

// ════════════════════════════════════════════════════════════════════════════
// MODELO E ENDPOINTS GEMINI
// ════════════════════════════════════════════════════════════════════════════

const GEMINI_MODEL      = 'gemini-2.5-flash-lite';
const GEMINI_BASE       = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}`;
const ENDPOINT_STREAM   = `${GEMINI_BASE}:streamGenerateContent?alt=sse`;
const ENDPOINT_SYNC     = `${GEMINI_BASE}:generateContent`;

// ════════════════════════════════════════════════════════════════════════════
// SYSTEM INSTRUCTIONS — Motor de Partida (Build 151)
//
// ARQUITETURA — Dois prompts monolíticos completamente isolados.
//   Nenhuma parte é compartilhada entre os modos.
//   buildSystemInstruction(clientPrompt, longResponse) seleciona diretamente
//   o prompt correto sem interpolação nem concatenação de fragmentos.
//
//   PROMPT_MODO_PLANTAO  — longResponse === false  (padrão / omitido)
//     Identidade clínica + segurança anti-CoT + flashcard ≤14 linhas +
//     TRAVA DE FALLBACK para termos sem conduta emergencial direta
//
//   PROMPT_MODO_ESTUDO   — longResponse === true
//     Identidade clínica + segurança anti-CoT + revisão acadêmica ≤24 linhas +
//     REGRA DE ACRÔNIMOS: qualquer acrônimo/termo → revisão completa
//
// INVARIANTES EM AMBOS OS PROMPTS:
//   • Início com ### (âncora médica obrigatória)
//   • ZERO pre-text — primeiro caractere = conteúdo clínico
//   • Proibição absoluta de listar passos internos ou raciocinar em inglês
//   • LANGUAGE LOCK: resposta exclusivamente em PT-BR ou ES
//   • MARKDOWN ONLY: ###, **bold**, bullets (-)
//
// CAMADA DE DEFESA COMPLEMENTAR:
//   cleanChunk() — filtro de stream SSE ativo em ambos os modos.
//   RX_METALANGUAGE_EN + RX_NUMBERED_METALANG + RX_MED_ANCHOR
//   bloqueiam vazamentos de metalinguagem inglesa no nível do TCP chunk.
//
// RETROCOMPATIBILIDADE:
//   longResponse ausente/undefined/null → false → MODO PLANTÃO. Nunca quebra.
//
// HISTÓRICO:
//   B147: DYNAMIC RESPONSE MATRIX removida (fonte de recitação eliminada)
//   B148: LINE BUDGET ajustado para context-sensitive
//   B149: Split binário dinâmico via buildAntiLeakPrompt()
//   B151: Prompts monolíticos isolados — PROMPT_MODO_PLANTAO / PROMPT_MODO_ESTUDO
//   B150: TRAVA DE FALLBACK + semântica explícita de acrônimos
//   B151: Prompts completamente isolados — sem partes compartilhadas
// ════════════════════════════════════════════════════════════════════════════

// ── MODO PLANTÃO / GUARDIA ────────────────────────────────────────────────────
// longResponse === false  |  padrão quando campo omitido no payload
//
// Dois comportamentos internos mutuamente exclusivos:
//   [CONDUTA DIRETA]   Input tem emergência/dose → flashcard ≤14 linhas
//   [FALLBACK GUIADO]  Input sem conduta direta  → 1 pergunta cirúrgica PT/ES
//
// O limite é 14 (não 12) para acomodar a pergunta de follow-up final com
// conforto, sem que ela quebre o budget ou seja cortada pelo modelo.
// ─────────────────────────────────────────────────────────────────────────────
const PROMPT_MODO_PLANTAO = `You are the Clinical Decision Support engine embedded in MedCases Pro, a medical application used exclusively by licensed physicians in Brazil and Latin America. All responses are directed to physicians, never to patients.

ABSOLUTE OUTPUT RULES — violating any of these is a critical failure:

1. ZERO pre-text. Your very first output character must be a Markdown heading (###) opening the clinical answer directly. No greetings, no "Sure", no "Here is", no "Of course", no "I will", no "Let me", no preamble of any kind.

2. YOU ARE FORBIDDEN from listing, describing, or narrating your own execution steps, decision process, formatting rules, or internal guidelines. Never number or bullet your reasoning. Process all logic internally and silently — the physician sees only the final clinical output.

3. LANGUAGE LOCK: respond entirely and exclusively in the language used in the application system prompt (Português do Brasil or Español). Never respond in English. Never mix languages under any circumstance.

4. RESPONSE MODE — PLANTÃO / GUARDIA (Emergency Flashcard):

You are operating in SHIFT MODE. The physician at bedside needs immediate, actionable decisions only.

INTERNAL CLASSIFICATION (execute silently — never expose this logic):
Determine whether the input refers to a CLINICAL EMERGENCY or a NON-EMERGENCY TERM.

A CLINICAL EMERGENCY has at least one of the following: a direct acute life-threatening condition, an immediate pharmacological management, or a drug name used in a dosing or treatment context. Examples: IAM, PCR, Sepse, Choque séptico, Anafilaxia, FA com instabilidade, TEP maciço, AVC agudo, Hipercalemia grave, CAD grave, Epinefrina, Norepinefrina, Alteplase, Adenosina, Amiodarona, or any pathology with a recognized emergency protocol.

A NON-EMERGENCY TERM is a methodology, educational framework, organizational acronym, or purely theoretical concept that does NOT have a direct emergency protocol or drug dose. Examples: SOAP (documentation method), ACLS or ATLS as a training course, fisiopatologia, teoria geral, definição acadêmica, sigla organizacional ou educacional.

OUTPUT RULE — CLINICAL EMERGENCY:
Respond in ultra-direct clinical flashcard format:
- Line 1-3: immediate action + drug + dose + route
- Line 4-6: key monitoring targets
- Line 7-8: single critical contraindication (if applicable)
- LINE BUDGET: Respond in ultra-direct clinical flashcard format, focused exclusively on immediate actions and doses. HARD LIMIT of 14 lines maximum to accommodate the mandatory final follow-up question gracefully.
- Zero academic narrative. Zero pathophysiology. Zero historical context.
- Close with one focused follow-up question to refine or escalate the case.

OUTPUT RULE — NON-EMERGENCY TERM:
Generate exactly one short guiding question in the app language (PT or ES). Do not fabricate a protocol. Do not explain why the term has no emergency. Do not leak your reasoning. Use this exact structure:

### 🏥 [Reproduce the exact term typed by the physician] não possui conduta de emergência direta.
Deseja alternar para o **Modo Estudo** para ver a revisão completa, ou me passa o contexto clínico do paciente?

Spanish version (if the app is running in ES):
### 🏥 [Reproduce el término exacto] no tiene conducta de emergencia directa.
¿Deseas cambiar al **Modo Estudio** para ver la revisión completa, o me das el contexto clínico del paciente?

5. MARKDOWN ONLY: use clean Markdown headings (###), bold (**drug name**), and bullets (-). No emojis in structural output unless they appear in the client system prompt examples.`;

// ── MODO ESTUDOS / ESTUDIO ────────────────────────────────────────────────────
// longResponse === true
//
// Foco acadêmico, conceitual e de aplicação clínica profunda.
// Todo acrônimo ou termo teórico é SEMPRE interpretado como pedido de revisão.
// Nunca pede esclarecimento para termos conhecidos — expande diretamente.
//
// O limite superior é 24 linhas para dar respiro teórico real sem
// degeneração em narrativa infinita.
// ─────────────────────────────────────────────────────────────────────────────
const PROMPT_MODO_ESTUDO = `You are the Clinical Decision Support engine embedded in MedCases Pro, a medical application used exclusively by licensed physicians in Brazil and Latin America. All responses are directed to physicians, never to patients.

ABSOLUTE OUTPUT RULES — violating any of these is a critical failure:

1. ZERO pre-text. Your very first output character must be a Markdown heading (###) opening the clinical answer directly. No greetings, no "Sure", no "Here is", no "Of course", no "I will", no "Let me", no preamble of any kind.

2. YOU ARE FORBIDDEN from listing, describing, or narrating your own execution steps, decision process, formatting rules, or internal guidelines. Never number or bullet your reasoning. Process all logic internally and silently — the physician sees only the final clinical output.

3. LANGUAGE LOCK: respond entirely and exclusively in the language used in the application system prompt (Português do Brasil or Español). Never respond in English. Never mix languages under any circumstance.

4. RESPONSE MODE — ESTUDOS / ESTUDIO (Deep Academic Review):

You are operating in STUDY MODE. The physician wants conceptual depth, theoretical grounding, and practical clinical application.

ACRONYM & THEORETICAL TERM RULE (critical):
Any acronym, abbreviation, or theoretical term the physician types — including but not limited to SOAP, ACLS, ATLS, SIRS, ARDS, CURB-65, Wells Score, NIHSS, SOFA, APACHE, RIFLE, qSOFA, HEART Score, or any educational, methodological, or organizational abbreviation — MUST be interpreted as an explicit request for: (a) clear definition, (b) full structured review, and (c) practical clinical application. NEVER treat a known acronym or medical term as a vague or ambiguous input requiring clarification. NEVER ask "what do you mean by X?" for recognized medical or clinical terms.

CLINICAL CONDITIONS in study mode:
When the input is a disease, syndrome, or clinical condition (e.g., Sepse, Pneumonia, IAM, AVC, IC), provide: pathophysiology mechanism, diagnostic criteria, risk stratification, first-line and second-line management, and key clinical pearls.

OUTPUT FORMAT:
- Open with a precise definition or mechanism (1-2 lines, no preamble)
- Organize with ### subheadings for each section
- Use **bold** for key terms, drugs, and doses
- Use bullets (-) for criteria lists and management steps
- Include practical application and real-world clinical examples
- Cover pathophysiology when it adds actionable insight for the physician
- LINE BUDGET: Respond in deep, detailed technical review format. Expand medical density and use a flexible ceiling of 24 lines maximum to provide full breadth and depth (criteria, pathophysiology) and give the final question room to breathe.
- Close with one focused follow-up question to deepen the case or connect to practice.

5. MARKDOWN ONLY: use clean Markdown headings (###), bold (**term**), and bullets (-). No emojis in structural output unless they appear in the client system prompt examples.`;

/**
 * Seleciona o system instruction correto com base no modo escolhido.
 *
 * Motor de Partida — Build 151: seleção direta entre dois prompts monolíticos.
 * Não há concatenação de fragmentos nem interpolação em runtime.
 * Cada modo tem seu próprio contrato de comportamento completo e isolado.
 *
 * @param {string}  clientPrompt  — system prompt enviado pelo Flutter (AiService)
 * @param {boolean} longResponse  — false → MODO PLANTÃO | true → MODO ESTUDOS
 * @returns {string} system instruction completo pronto para envio ao Gemini
 */
function buildSystemInstruction(clientPrompt, longResponse) {
  const modePrompt = longResponse ? PROMPT_MODO_ESTUDO : PROMPT_MODO_PLANTAO;
  return `${modePrompt}\n\n---\n\n${clientPrompt ?? ''}`.trim();
}

// ════════════════════════════════════════════════════════════════════════════
// GENERATION CONFIG
// ════════════════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════════════════
// HELPER ANTI-BUFFERING — escrita direta no socket TCP
//
// res.write() em Node.js passa pelo buffer interno do stream writable.
// Em situações de alta carga, o stream pode decidir enfileirar vários
// writes antes de chamar socket.write() — produzindo o efeito de "bursts".
//
// _writeSseRaw() bypassa esse buffer: escreve diretamente no socket TCP,
// garantindo que cada evento SSE saia no wire imediatamente.
//
// Fallback gracioso: se socket não estiver disponível ou já fechado, usa
// res.write() como caminho alternativo (nunca lança exceção).
// ════════════════════════════════════════════════════════════════════════════

/**
 * Escreve um frame SSE diretamente no socket TCP subjacente.
 * Evita o buffer interno do stream writable do Node/Express.
 *
 * @param {import('http').ServerResponse} res - objeto de resposta HTTP
 * @param {string} frame - string SSE já formatada (ex: "data: {...}\n\n")
 */
function _writeSseRaw(res, frame) {
  if (res.writableEnded) return;

  const socket = res.socket;
  // Caminho 1: socket ativo → write direto (bypass do buffer Express)
  if (socket && socket.writable && !socket.destroyed) {
    try {
      socket.write(frame, 'utf8');
      return;
    } catch (_) {
      // Socket fechou entre o check e o write → cai no fallback
    }
  }
  // Caminho 2 (fallback): sem socket → usa res.write() convencional
  try {
    res.write(frame);
  } catch (_) { /* res já encerrado */ }
}

const GENERATION_CONFIG = {
  maxOutputTokens: 3200,
  temperature:     0.4,
  topP:            0.95,
  topK:            40,
  // thinkingConfig OMITIDO intencionalmente:
  //   flash-lite + tools:[google_search] + thinkingConfig → HTTP 400 silencioso
  //   que bypassa system_instruction e causa CoT leakage.
  //   Omitir é a configuração correta e estável (Build 114+).
};

const SAFETY_SETTINGS = [
  { category: 'HARM_CATEGORY_HARASSMENT',        threshold: 'BLOCK_NONE' },
  { category: 'HARM_CATEGORY_HATE_SPEECH',       threshold: 'BLOCK_NONE' },
  { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_NONE' },
  { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_NONE' },
];

// ════════════════════════════════════════════════════════════════════════════
// FILTRO DE CoT + HEURÍSTICA DE IDIOMA — cleanChunk()  (Build 147)
//
// CAMADA 2 DE DEFESA — descarta fragmentos SSE que são:
//   (A) Raciocínio interno CoT (API flags ou padrões textuais)
//   (B) Metalinguagem em inglês — o novo vetor de vazamento (Build 147)
//
// NOVO VETOR (Build 147):
//   O modelo burlou cleanChunk() porque não usou <thinking> — em vez disso,
//   gerou uma lista numerada RECITANDO as regras do system prompt em inglês:
//   "1. Identify the core request... 2. Structure the response..."
//   Isso passou pela filtragem de prefixos anterior porque "1." não estava
//   na lista de COT_LEAK_PREFIXES.
//
// SOLUÇÃO — Dois detectores novos:
//   [D1] METALANGUAGE DETECTOR: regex que detecta sentenças em inglês com
//        alta densidade de stop-words COMBINADAS com palavras-chave de prompt
//        (request, structure, response, mode, language, format, guidelines).
//        Estas combinações são o fingerprint de "recitação de instrução".
//
//   [D2] ENGLISH DENSITY GATE: heurística refinada (50% → threshold adaptativo)
//        que considera o tamanho do segmento e a presença de QUALQUER termo
//        médico (PT ou ES) como âncora de segurança — evita falsos positivos
//        em casos onde o modelo mistura idiomas com termos técnicos válidos.
//
// COMPORTAMENTO DO BUFFER ANTI-VAZAMENTO:
//   Quando um segmento É detectado como metalinguagem inglesa, o cleanChunk()
//   retorna '' (string vazia). O relayStream() já trata '' como chunk ignorado
//   — o frontend NÃO recebe nada, streaming continua transparente até que
//   chegue conteúdo clínico em PT/ES (ex: "### 1. Conduta Imediata").
//
// PADRÕES DETECTADOS (acumulativos, ordem de custo crescente):
//   • thought == true          → CoT explícito da API Gemini
//   • thoughtSignature key     → Assinatura criptográfica de CoT
//   • functionCall key         → Chamada interna de ferramenta
//   • executableCode key       → Código gerado internamente
//   • codeExecutionResult key  → Resultado de execução interna
//   • inlineData key           → Dados binários embutidos
//   • <thinking>…</thinking>   → Bloco estruturado de raciocínio
//   • ```tool_code / thinking  → Bloco de código interno
//   • COT_LEAK_PREFIXES        → Prefixos de sentença em inglês (i will, let me…)
//   • METALANGUAGE_RX [D1]     → Recitação de regras/prompt em inglês  ← NOVO
//   • English density gate [D2]→ Alta proporção de stop-words inglesas  ← REFINADO
// ════════════════════════════════════════════════════════════════════════════

// ── [D1] Regex de metalinguagem inglesa (fingerprint de recitação de prompt) ──
//
// Detecta SENTENÇAS (não apenas parágrafos) que combinam:
//   • Stop-words de planejamento em inglês (I, the, this, will, need, must…)
//   • + Palavras-chave de prompt/instrução (request, response, structure,
//     format, language, mode, guidelines, rules, output, provide, ensure,
//     identify, analyze, consider, generate, follow, based, given)
//
// O padrão é formulado como OU-lógico de combinações de alto sinal:
//   grupo A: pronome/artigo de sujeito ativo
//   grupo B: verbo modal ou de ação de metalinguagem
//   grupo C: objeto direto relacionado a instrução/prompt
//
// Calibrado para NÃO disparar em texto clínico em inglês legítimo
// (ex: "SpO2 must be monitored") — por isso exige OBJETO de prompt, não clínico.
const RX_METALANGUAGE_EN = /\b(?:i(?:'ll| will| need to| should| must| am going to| have to)|(?:the|this|my)\s+(?:user|prompt|request|query|question|response|output|task|instruction|guideline|rule|format|structure|mode|language|approach|goal|plan|step))\b.*?\b(?:provide|ensure|include|address|structure|format|follow|generate|create|identify|analyze|consider|respond|handle|process|organize|determine|present|discuss|mention|describe|detail|explain|note|remember|understand|apply|implement|use|make|start|begin)\b/gi;

// ── Regex complementar: listas numeradas de metalinguagem ──────────────────
// Detecta especificamente o padrão "1. Identify..." / "2. Structure..."
// que o modelo gerou recitando a DYNAMIC RESPONSE MATRIX.
// Gatilho: linha começa com dígito + ponto/parêntese + verbo de metalinguagem em inglês.
const RX_NUMBERED_METALANG = /^[ \t]*\d+[.)]\s+(?:identify|structure|analyze|consider|provide|ensure|include|address|format|follow|generate|create|respond|handle|process|organize|determine|present|discuss|note|understand|apply|implement|use|start|begin|check|verify|confirm|review|assess|evaluate)/im;

// ── Stop-words de inglês para o density gate ─────────────────────────────────
// Lista focada em palavras FUNCIONAIS (artigos, preposições, pronomes, auxiliares)
// que são marcadores confiáveis de inglês nativo vs. termos médicos internacionais
const RX_ENG_STOPWORDS = /\b(?:the|this|that|these|those|with|from|they|their|there|when|where|what|which|would|could|should|about|after|before|also|some|each|into|than|then|more|over|only|both|other|through|during|including|without|however|therefore|furthermore|additionally|specifically|importantly|regarding|concerning|considering|following|based|will|have|been|has|was|were|are|and|but|for|not|you|your|our|we|can|may|might|shall|its|it)\b/gi;

// ── Palavras-chave de prompt (alto sinal de metalinguagem) ───────────────────
const RX_PROMPT_KEYWORDS = /\b(?:request|response|output|format|structure|guideline|rule|mode|language|prompt|instruction|task|query|approach|plan|step|goal|user|system|model|template|example|provide|ensure|generate|identify|analyze|consider|respond|organize|determine|present|discuss|implement|apply|follow)\b/gi;

// ── Termos médicos em PT/ES como âncoras de segurança ──────────────────────
// Se o segmento contém QUALQUER destes → assumir texto clínico legítimo mesmo
// que tenha palavras em inglês (termos internacionais como SpO2, PEEP, etc.)
const RX_MED_ANCHOR = /\b(?:dose|dosis|mg|mcg|µg|mL|mEq|UI|bpm|mmHg|EV|VO|SC|IM|SL|IV|BIC|infus[aã]o|infusión|paciente|tratament[oa]|tratamiento|f[aá]rmaco|medicament[oa]|protocolo|urgên?cia|urgencia|clín?ic[oa]|diagnóst?ico|síntoma|sintoma|antibiótico|antibiotico|corticoide|vasopress?or|anticoagul|trombólise|trombólisis|cardiovers[aã]o|desfibril|ressuscit|resucit|ventila[cç][aã]o|ventilación|intuba[cç][aã]o|intubación|sepse|sepsis|choque|shock|lactato|leucócit|leucocit|hemograma|creatinina|potássi|potassio|sódio|sodio|glicemia|glucemia|hemoglob|pressão|presión|frequência|frecuencia|saturação|saturación|débito|debito)\b/i;

/** Prefixos de INÍCIO DE SENTENÇA que indicam CoT/metalinguagem em inglês */
const COT_LEAK_PREFIXES = [
  // Pronome + verbo ativo de metalinguagem
  'i will ', "i'll ", 'i need to ', 'i should ', 'i have to ',
  'i am going', 'i must ', 'i want to ', 'i can ', 'i am ',
  // "Let me / Let's" — geralmente precede planejamento
  'let me ', "let's ", "let's ",
  // Referência a artefatos do prompt
  'the user ', 'the prompt ', 'the question ', 'the request ',
  'the response ', 'the output ', 'the format ', 'the language ',
  'the system ', 'the model ', 'the instruction ',
  // Conectivos de raciocínio em inglês
  'given the ', 'given that ', 'given this ',
  'based on ', 'since the ', 'as per ', 'according to ',
  // Sequenciadores de lista de passos
  'first, i ', 'now, i ', 'next, i ', 'then, i ', 'finally, i ',
  'step 1', 'step 2', 'step 3',
  // Metalinguagem direta
  'my goal ', 'my approach ', 'my plan ', 'my task ',
  'this is a ', 'this requires ', 'this response ',
  'it seems ', 'it looks like ', 'it appears ',
  // API / código interno
  'thought:', 'note:', 'tool_code', 'print(google',
  'search_query', 'queries=[',
  // Metadados proibidos (português/espanhol)
  'confianza clínica:', 'confiança clínica:', 'clinical confidence:',
  'el usuario ', 'el prompt ', 'o usuário ', 'o prompt ',
  // Conectivos de enumeração de regras
  'a seguir ', 'a continuación ',
];

/** Regex para blocos <thinking>…</thinking> residuais */
const RX_THINKING_BLOCK = /<thinking>[\s\S]*?<\/thinking>/gim;
const RX_CODE_BLOCK     = /```(?:tool_code|thinking|thought|python|json)[\s\S]*?```/gim;
const RX_TOOL_CODE_RAW  = /tool_code\s*\n[\s\S]*?(?=\n\n|$)/gim;

/**
 * Extrai texto limpo de um part do SSE.
 * Retorna null se o part for raciocínio interno (API flags).
 *
 * @param {Object} part - part de um candidate do Gemini
 * @returns {string|null}
 */
function extractPartText(part) {
  if (!part || typeof part !== 'object') return null;

  // Descarta flags estruturais de CoT (nível de API)
  if (part.thought === true)                  return null;
  if ('thoughtSignature' in part)             return null;
  if ('functionCall' in part)                 return null;
  if ('executableCode' in part)               return null;
  if ('codeExecutionResult' in part)          return null;
  if ('inlineData' in part)                   return null;
  if (!('text' in part))                      return null;

  const raw = String(part.text ?? '');
  if (raw.trim() === '')                      return null;

  return raw;
}

/**
 * Testa se um segmento de texto é metalinguagem em inglês (recitação de prompt).
 *
 * Critério composto:
 *   1. Contém padrão [D1] de metalanguage regex, OU
 *   2. Começa com lista numerada de verbo de metalinguagem [D1b], OU
 *   3. Density gate [D2]: stop-words inglesas > 45% das palavras totais
 *      E palavras-chave de prompt > 10% das palavras totais
 *      E NENHUM termo médico PT/ES detectado (âncora de segurança)
 *
 * O threshold duplo (stop-words + prompt keywords) evita falsos positivos
 * em frases médicas com terminologia internacional em inglês (SpO2, PEEP…).
 *
 * @param {string} segment - segmento de texto a testar
 * @returns {boolean} true = é metalinguagem inglesa → descartar
 */
function _isEnglishMetalanguage(segment) {
  const trimmed = segment.trim();
  if (!trimmed) return false;

  // Âncora de segurança: conteúdo médico PT/ES → NUNCA descartar
  if (RX_MED_ANCHOR.test(trimmed)) {
    RX_MED_ANCHOR.lastIndex = 0;
    return false;
  }
  RX_MED_ANCHOR.lastIndex = 0;

  // [D1] Regex de metalinguagem estruturada
  RX_METALANGUAGE_EN.lastIndex = 0;
  if (RX_METALANGUAGE_EN.test(trimmed)) return true;

  // [D1b] Lista numerada de metalinguagem
  if (RX_NUMBERED_METALANG.test(trimmed)) return true;

  // [D2] Density gate
  const words = trimmed.split(/\s+/).filter(w => w.length > 1);
  if (words.length < 5) return false; // segmento muito curto — não filtrar

  RX_ENG_STOPWORDS.lastIndex = 0;
  const stopCount = (trimmed.match(RX_ENG_STOPWORDS) || []).length;
  const stopRatio = stopCount / words.length;

  RX_PROMPT_KEYWORDS.lastIndex = 0;
  const promptCount = (trimmed.match(RX_PROMPT_KEYWORDS) || []).length;
  const promptRatio = promptCount / words.length;

  // Threshold: >45% stop-words inglesas E >10% prompt-keywords → metalinguagem
  return stopRatio > 0.45 && promptRatio > 0.10;
}

/**
 * Limpa um fragmento de texto bruto recebido do stream SSE (Build 147).
 *
 * Pipeline de filtros em ordem de custo crescente:
 *   1. Remove blocos estruturados (<thinking>, ```tool_code```)
 *   2. Divide em segmentos por linha dupla (parágrafos SSE)
 *   3. Para cada segmento:
 *      a. Verifica prefixo de CoT em inglês (COT_LEAK_PREFIXES)
 *      b. Verifica metalinguagem inglesa estruturada [D1] e density gate [D2]
 *   4. Se TODOS os segmentos foram filtrados E nenhum contém cabeçalho ### →
 *      retorna '' (buffer mantido — aguarda conteúdo clínico PT/ES)
 *   5. Se ao menos UM segmento passou → retorna conteúdo limpo
 *
 * O retorno de '' é INTENCIONAL: o relayStream() descarta o chunk e continua
 * aguardando. A resposta clínica começa a fluir quando o modelo produz o
 * primeiro cabeçalho ### ou bullet em PT/ES.
 *
 * @param {string} raw - texto bruto do part SSE
 * @returns {string} texto limpo (pode ser '' se tudo foi filtrado)
 */
function cleanChunk(raw) {
  if (!raw || typeof raw !== 'string') return '';

  let text = raw;

  // ── Passo 1: Remove blocos estruturados de CoT/código ─────────────────────
  text = text.replace(RX_THINKING_BLOCK, '');
  text = text.replace(RX_CODE_BLOCK, '');
  text = text.replace(RX_TOOL_CODE_RAW, '');

  if (!text.trim()) return '';

  // ── Passo 2: Divide em segmentos (parágrafos ou linhas individuais) ────────
  // Usa \n\n como delimitador principal mas também processa linhas isoladas
  // quando o chunk é uma linha única (streaming token-by-token do Gemini).
  const segments = text.split(/\n\n+/);

  // ── Passo 3: Filtra segmento a segmento ────────────────────────────────────
  const clean = [];

  for (const seg of segments) {
    const trimmed = seg.trim();
    if (!trimmed) continue;

    const lower = trimmed.toLowerCase();

    // [F1] Prefixo de CoT (verificação de string rápida — O(n) nas prefixes)
    let isCotPrefix = false;
    for (const prefix of COT_LEAK_PREFIXES) {
      if (lower.startsWith(prefix)) { isCotPrefix = true; break; }
    }
    if (isCotPrefix) continue;

    // [F2] Metalinguagem inglesa (regex + density gate)
    if (_isEnglishMetalanguage(trimmed)) continue;

    clean.push(seg);
  }

  // ── Passo 4: Decisão final ─────────────────────────────────────────────────
  //
  // Se filtrou TUDO e nenhum segmento sobrou:
  //   → retorna '' (vazio intencional — o relayStream descarta este chunk)
  //   → NÃO retorna o raw original (diferente da versão anterior)
  //   → Raciocínio: é melhor ter silêncio que vazar metalinguagem para o médico
  //
  // Exceção: se o raw contém cabeçalho Markdown (###) ou bullet (-) em
  //   posição inicial → provavelmente é conteúdo clínico legítimo fragmentado
  //   (o chunk chegou partido no meio de uma linha). Nesse caso, retorna raw.
  if (clean.length === 0) {
    // Verifica se o raw original tem início de conteúdo clínico legítimo
    const rawTrimmed = raw.trim();
    const hasMarkdownAnchor = /^#{1,3}\s+\S/.test(rawTrimmed)  // ### Título
                           || /^-\s+\*?\*?\S/.test(rawTrimmed)  // - **Fármaco**
                           || /^\*\*\S/.test(rawTrimmed);       // **Negrito direto
    if (hasMarkdownAnchor) return rawTrimmed;
    return ''; // descarte silencioso — aguarda próximo chunk com PT/ES
  }

  return clean.join('\n\n').trim();
}

// ════════════════════════════════════════════════════════════════════════════
// MONTAGEM DO PAYLOAD GEMINI
// ════════════════════════════════════════════════════════════════════════════

/**
 * Converte o histórico do formato Flutter (role/content ou role/text)
 * para o formato Gemini (role: 'user'|'model', parts: [{text}]).
 *
 * @param {Array} history - histórico de mensagens do cliente
 * @returns {Array}
 */
function buildContents(history, userMessage) {
  const contents = [];

  for (const msg of (history ?? [])) {
    const role = (msg.role === 'assistant' || msg.role === 'model') ? 'model' : 'user';
    const text = String(msg.content ?? msg.text ?? '');
    if (text.trim()) {
      contents.push({ role, parts: [{ text }] });
    }
  }

  contents.push({ role: 'user', parts: [{ text: userMessage }] });
  return contents;
}

/**
 * Monta o body completo da requisição ao Gemini.
 *
 * @param {Object} opts
 * @param {string}  opts.systemInstruction
 * @param {Array}   opts.contents
 * @param {boolean} opts.useGrounding
 * @param {number}  opts.maxTokens
 * @returns {string} JSON serializado
 */
function buildGeminiPayload({ systemInstruction, contents, useGrounding, maxTokens }) {
  const payload = {
    system_instruction: { parts: [{ text: systemInstruction }] },
    contents,
    generationConfig: {
      ...GENERATION_CONFIG,
      ...(maxTokens ? { maxOutputTokens: maxTokens } : {}),
    },
    safetySettings: SAFETY_SETTINGS,
  };

  if (useGrounding) {
    payload.tools = [{ google_search: {} }];
  }

  return JSON.stringify(payload);
}

// ════════════════════════════════════════════════════════════════════════════
// REQUISIÇÃO STREAMING → SSE RELAY
//
// Faz o pedido ao Gemini com streamGenerateContent?alt=sse.
// Parseia os chunks SSE ("data: {...}") e repassa como eventos SSE
// para o cliente Flutter.
//
// Eventos emitidos:
//   data: {"text":"..."}\n\n          → fragmento de resposta
//   data: {"done":true}\n\n           → fim normal do stream
//   data: {"error":"..."}\n\n         → erro (quota, auth, etc.)
//   : ping\n\n                         → heartbeat a cada 15s
//
// WATCHDOG: se o stream ficar 45s sem chunk → fecha conexão.
// ════════════════════════════════════════════════════════════════════════════

const WATCHDOG_MS   = 45_000;  // 45s sem chunk → encerra
const HEARTBEAT_MS  = 15_000;  // ping a cada 15s para manter SSE ativo

/**
 * Executa o stream SSE do Gemini e repassa para res.
 *
 * @param {import('http').ServerResponse} res
 * @param {string} body - payload JSON serializado
 * @param {string} apiKey
 * @param {number} attempt - tentativa atual (para retry interno)
 */
async function relayStream(res, body, apiKey, attempt = 0) {
  const MAX_RETRIES     = 3;
  const RETRY_DELAYS_MS = [2_000, 5_000, 15_000];

  let watchdog   = null;
  let heartbeat  = null;
  let abortCtrl  = new AbortController();

  function resetWatchdog() {
    clearTimeout(watchdog);
    watchdog = setTimeout(() => {
      log.warn('Watchdog disparou — stream sem chunks por 45s');
      abortCtrl.abort();
      _sendSseError(res, 'timeout');
    }, WATCHDOG_MS);
  }

  function startHeartbeat() {
    heartbeat = setInterval(() => {
      // Build 146: heartbeat também via _writeSseRaw para saída imediata
      _writeSseRaw(res, ': ping\n\n');
    }, HEARTBEAT_MS);
  }

  function cleanup() {
    clearTimeout(watchdog);
    clearInterval(heartbeat);
    abortCtrl.abort();
  }

  try {
    const fetchResp = await fetch(`${ENDPOINT_STREAM}&key=${apiKey}`, {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
      signal: abortCtrl.signal,
    });

    // ── Erros HTTP não-transitórios ──────────────────────────────────────
    if (fetchResp.status === 401 || fetchResp.status === 403) {
      cleanup();
      return _sendSseError(res, 'api_key_invalid');
    }
    if (fetchResp.status === 400) {
      const errBody = await fetchResp.text().catch(() => '');
      log.error('Gemini 400 Bad Request:', errBody.slice(0, 300));
      cleanup();
      return _sendSseError(res, 'bad_request');
    }

    // ── 429 — Retry com backoff ──────────────────────────────────────────
    if (fetchResp.status === 429) {
      cleanup();
      if (attempt < MAX_RETRIES) {
        const delay = RETRY_DELAYS_MS[attempt] ?? 15_000;
        log.warn(`Gemini 429 — retry ${attempt + 1}/${MAX_RETRIES} em ${delay}ms`);
        await sleep(delay);
        return relayStream(res, body, apiKey, attempt + 1);
      }
      log.error('Gemini 429 definitivo — quota esgotada');
      return _sendSseError(res, 'quota');
    }

    // ── 5xx — Retry transitório ──────────────────────────────────────────
    if (fetchResp.status >= 500) {
      cleanup();
      if (attempt < MAX_RETRIES) {
        const delay = RETRY_DELAYS_MS[attempt] ?? 15_000;
        log.warn(`Gemini ${fetchResp.status} — retry ${attempt + 1}/${MAX_RETRIES} em ${delay}ms`);
        await sleep(delay);
        return relayStream(res, body, apiKey, attempt + 1);
      }
      return _sendSseError(res, `http_${fetchResp.status}`);
    }

    if (!fetchResp.ok) {
      cleanup();
      return _sendSseError(res, `http_${fetchResp.status}`);
    }

    // ── Stream SSE ────────────────────────────────────────────────────────
    resetWatchdog();
    startHeartbeat();

    const reader   = fetchResp.body.getReader();
    const decoder  = new TextDecoder('utf-8');
    let   buffer   = '';

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      resetWatchdog();
      buffer += decoder.decode(value, { stream: true });

      // Processa linhas SSE completas
      const lines = buffer.split('\n');
      buffer = lines.pop() ?? ''; // última linha pode estar incompleta

      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith(':')) continue;
        if (!trimmed.startsWith('data:')) continue;

        const jsonStr = trimmed.slice(5).trim();
        if (jsonStr === '[DONE]') break;

        let parsed;
        try {
          parsed = JSON.parse(jsonStr);
        } catch {
          log.debug('SSE chunk não-JSON ignorado:', jsonStr.slice(0, 80));
          continue;
        }

        // Extrai texto limpo dos candidates
        const candidates = parsed?.candidates ?? [];
        for (const candidate of candidates) {
          const parts     = candidate?.content?.parts ?? [];
          const finishReason = candidate?.finishReason;

          let chunkText = '';
          for (const part of parts) {
            const extracted = extractPartText(part);
            if (extracted !== null) {
              chunkText += extracted;
            }
          }

          if (chunkText) {
            const cleaned = cleanChunk(chunkText);
            if (cleaned) {
              log.debug('→ chunk enviado:', cleaned.slice(0, 60));
              _sendSseData(res, { text: cleaned });
            }
          }

          // Fim normal do stream
          if (finishReason && finishReason !== 'OTHER') {
            log.info('Stream concluído. finishReason:', finishReason);
          }
        }

        // Trata promptFeedback (conteúdo bloqueado)
        const blockReason = parsed?.promptFeedback?.blockReason;
        if (blockReason) {
          log.warn('Conteúdo bloqueado pelo Gemini:', blockReason);
          cleanup();
          return _sendSseError(res, `blocked_${blockReason.toLowerCase()}`);
        }
      }
    }

    cleanup();
    _sendSseDone(res);

  } catch (err) {
    cleanup();
    if (err.name === 'AbortError') {
      log.warn('Stream abortado (watchdog ou cliente desconectou)');
      return; // já tratado pelo watchdog
    }
    log.error('Erro no stream SSE:', err.message);
    _sendSseError(res, 'stream_error');
  }
}

// ── Helpers SSE ───────────────────────────────────────────────────────────────

function _sendSseData(res, payload) {
  // Build 146: usa _writeSseRaw para bypass do buffer interno do Express.
  // Cada evento SSE sai no wire imediatamente, sem esperar outros writes.
  _writeSseRaw(res, `data: ${JSON.stringify(payload)}\n\n`);
}

function _sendSseDone(res) {
  _sendSseData(res, { done: true });
  if (!res.writableEnded) res.end();
}

function _sendSseError(res, errorCode) {
  _sendSseData(res, { error: errorCode, done: true });
  if (!res.writableEnded) res.end();
}

// ════════════════════════════════════════════════════════════════════════════
// REQUISIÇÃO SÍNCRONA (Context Classifier — resposta rápida sem stream)
// ════════════════════════════════════════════════════════════════════════════

/**
 * Faz uma chamada síncrona ao Gemini (generateContent).
 * Usada internamente para o Context Classifier (classifica 'MÉDICO'/'NOVO').
 *
 * @param {string} prompt - prompt completo
 * @param {string} apiKey
 * @param {number} maxTokens
 * @returns {Promise<{text: string}|{error: string}>}
 */
async function syncRequest(prompt, apiKey, maxTokens = 20) {
  const payload = JSON.stringify({
    contents: [{ role: 'user', parts: [{ text: prompt }] }],
    generationConfig: { maxOutputTokens: maxTokens, temperature: 0.1 },
    safetySettings: SAFETY_SETTINGS,
  });

  try {
    const resp = await fetch(`${ENDPOINT_SYNC}?key=${apiKey}`, {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    payload,
      signal:  AbortSignal.timeout(8_000), // 8s timeout
    });

    if (!resp.ok) return { error: `http_${resp.status}` };

    const data  = await resp.json();
    const parts = data?.candidates?.[0]?.content?.parts ?? [];
    const text  = parts.map(p => p.text ?? '').join('').trim();

    return { text };
  } catch (err) {
    return { error: err.message };
  }
}

// ════════════════════════════════════════════════════════════════════════════
// VALIDAÇÃO DO BODY DA REQUISIÇÃO
// ════════════════════════════════════════════════════════════════════════════

/**
 * Valida o body da requisição de stream/sync.
 * Retorna null se válido, string de erro se inválido.
 *
 * @param {Object} body
 * @returns {string|null}
 */
function validateStreamBody(body) {
  if (!body || typeof body !== 'object') return 'body ausente';
  if (!body.userMessage || typeof body.userMessage !== 'string') return 'userMessage ausente';
  if (!body.systemPrompt || typeof body.systemPrompt !== 'string') return 'systemPrompt ausente';
  if (body.userMessage.length > 10_000)  return 'userMessage muito longo (max 10.000 chars)';
  if (body.systemPrompt.length > 80_000) return 'systemPrompt muito longo (max 80.000 chars)';
  return null;
}

// ════════════════════════════════════════════════════════════════════════════
// EXPRESS APP
// ════════════════════════════════════════════════════════════════════════════

const app = express();

// ── Middlewares globais ───────────────────────────────────────────────────────

app.use(helmet({
  contentSecurityPolicy: false,      // Flutter configura o próprio CSP
  crossOriginEmbedderPolicy: false,  // SSE requer ausência de COEP
}));

app.use(cors({
  origin: (origin, cb) => {
    // Permite: domínio configurado, localhost (dev) e null (apps nativas)
    const allowed = [
      ALLOWED_ORIGIN,
      'http://localhost',
      'http://localhost:3000',
      'http://localhost:8080',
      'http://127.0.0.1',
    ];
    if (!origin || allowed.some(a => origin.startsWith(a))) {
      cb(null, true);
    } else {
      log.warn('CORS bloqueou origem:', origin);
      cb(new Error('Not allowed by CORS'));
    }
  },
  methods:          ['GET', 'POST', 'OPTIONS'],
  allowedHeaders:   ['Content-Type', 'Authorization', 'X-Request-ID'],
  exposedHeaders:   ['X-Request-ID'],
  credentials:      true,
  maxAge:           86_400,
}));

app.use(express.json({ limit: '512kb' }));

// ── Rate limiting ─────────────────────────────────────────────────────────────

const streamLimiter = rateLimit({
  windowMs:         60_000,         // janela de 1 minuto
  max:              60,             // 60 req/min por IP (1/s médio)
  standardHeaders:  true,
  legacyHeaders:    false,
  message:          { error: 'rate_limit', message: 'Muitas requisições. Tente em 1 minuto.' },
  skip: (req) => !IS_PROD,         // desativa rate limit em desenvolvimento
});

// ════════════════════════════════════════════════════════════════════════════
// ROTA: POST /api/ai/stream
//
// Entrada (JSON):
//   {
//     userMessage:  string,     // pergunta clínica do usuário
//     systemPrompt: string,     // system prompt montado pelo Flutter (AiService)
//     history:      Array,      // histórico de mensagens (opcional)
//     useGrounding: boolean,    // ativar Google Search (padrão: true)
//     maxTokens:    number,     // tokens máximos (padrão: 3200)
//     longResponse: boolean,    // Motor de Partida (Build 151):
//                               //   false / omitido → PROMPT_MODO_PLANTAO (flashcard ≤14 linhas)
//                               //   true            → PROMPT_MODO_ESTUDO  (revisão ≤24 linhas)
//   }
//
// Saída (SSE):
//   data: {"text":"fragmento"}\n\n
//   data: {"done":true}\n\n
//   data: {"error":"código"}\n\n
// ════════════════════════════════════════════════════════════════════════════

app.post('/api/ai/stream', streamLimiter, async (req, res) => {
  const requestId = req.headers['x-request-id'] ?? `req_${Date.now()}`;
  log.info(`[${requestId}] POST /api/ai/stream`);

  // ── Validação da API key ──────────────────────────────────────────────────
  // Prioridade: header Authorization > variável de ambiente
  const bearerKey = (req.headers.authorization ?? '').replace(/^Bearer\s+/i, '').trim();
  const apiKey    = bearerKey || GEMINI_API_KEY;

  if (!apiKey) {
    log.error(`[${requestId}] GEMINI_API_KEY não configurada`);
    return res.status(500).json({ error: 'server_misconfigured', message: 'API key ausente no servidor.' });
  }

  // ── Validação do body ─────────────────────────────────────────────────────
  const validationErr = validateStreamBody(req.body);
  if (validationErr) {
    log.warn(`[${requestId}] body inválido: ${validationErr}`);
    return res.status(400).json({ error: 'bad_request', message: validationErr });
  }

  const {
    userMessage,
    systemPrompt,
    history      = [],
    useGrounding = true,
    maxTokens,
    longResponse = false,  // Motor de Partida (Build 151): false=PLANTAO | true=ESTUDO
  } = req.body;

  // ── Monta payload ─────────────────────────────────────────────────────────
  const systemInstruction = buildSystemInstruction(systemPrompt, longResponse);
  const contents          = buildContents(history, userMessage);
  const body              = buildGeminiPayload({
    systemInstruction,
    contents,
    useGrounding,
    maxTokens,
  });

  const modo = longResponse ? 'ESTUDO' : 'PLANTAO';
  log.info(`[${requestId}] modo=${modo} useGrounding=${useGrounding} si_len=${systemInstruction.length}`);

  // ── Configura cabeçalhos SSE ──────────────────────────────────────────────
  // ── Build 146: Headers anti-buffering completos ────────────────────────
  //
  // Cache-Control: no-cache, no-transform
  //   • no-cache: sem cache de resposta SSE em proxies
  //   • no-transform: CRÍTICO — impede que proxies Nginx/CDN comprimam o
  //     payload (gzip/deflate em SSE quebra o framing de eventos).
  //     Anteriormente era "no-store" — que não instrui proxies sobre transform.
  //
  // X-Accel-Buffering: no
  //   Instrução direta ao Nginx para não usar proxy_buffering nesta conexão.
  //   O Digital Ocean App Platform usa Nginx como proxy reverso interno.
  //
  // Transfer-Encoding: chunked
  //   Força modo chunked explicitamente. Sem Content-Length definido, Node
  //   já usa chunked por padrão, mas declarar é garantia para proxies.
  res.setHeader('Content-Type',       'text/event-stream; charset=utf-8');
  res.setHeader('Cache-Control',      'no-cache, no-transform');
  res.setHeader('Connection',         'keep-alive');
  res.setHeader('X-Accel-Buffering',  'no');
  res.setHeader('Transfer-Encoding',  'chunked');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Request-ID', requestId);

  // ── Build 146: TCP_NODELAY — desativa Algoritmo de Nagle ────────────────
  //
  // O Algoritmo de Nagle (RFC 896) agrupa pacotes TCP pequenos em um lote
  // maior para reduzir overhead de rede. Correto para HTTP REST, mas
  // catastrófico para SSE: cada chunk do Gemini pode ficar represado até
  // que o buffer TCP acumule ~1460 bytes (MTU padrão).
  //
  // setNoDelay(true) = TCP_NODELAY = cada socket.write() vira um pacote
  // TCP independente enviado imediatamente, sem esperar outros dados.
  //
  // Deve ser chamado ANTES de flushHeaders() para garantir que o handshake
  // HTTP inicial também seja enviado imediatamente.
  if (res.socket) {
    res.socket.setNoDelay(true);
    log.debug(`[${requestId}] TCP_NODELAY ativado`);
  }

  // Envia headers imediatamente (antes do primeiro chunk)
  res.flushHeaders();

  // Detecta desconexão do cliente
  req.on('close', () => {
    log.debug(`[${requestId}] Cliente desconectou`);
  });

  // ── Relay do stream ───────────────────────────────────────────────────────
  await relayStream(res, body, apiKey);
  log.info(`[${requestId}] Stream encerrado`);
});

// ════════════════════════════════════════════════════════════════════════════
// ROTA: POST /api/ai/sync
//
// Entrada (JSON):
//   {
//     userMessage:  string,
//     systemPrompt: string,
//     maxTokens:    number,   // padrão: 20
//   }
//
// Saída (JSON):
//   { text: string }
//   { error: string }
//
// Usado para: Context Classifier, validação de chave, chamadas leves.
// ════════════════════════════════════════════════════════════════════════════

app.post('/api/ai/sync', streamLimiter, async (req, res) => {
  const requestId = req.headers['x-request-id'] ?? `req_${Date.now()}`;
  log.info(`[${requestId}] POST /api/ai/sync`);

  const bearerKey = (req.headers.authorization ?? '').replace(/^Bearer\s+/i, '').trim();
  const apiKey    = bearerKey || GEMINI_API_KEY;

  if (!apiKey) {
    return res.status(500).json({ error: 'server_misconfigured' });
  }

  const { userMessage, systemPrompt, maxTokens = 20 } = req.body ?? {};

  if (!userMessage || typeof userMessage !== 'string') {
    return res.status(400).json({ error: 'bad_request', message: 'userMessage ausente' });
  }

  const fullPrompt = systemPrompt
    ? `${systemPrompt}\n\n${userMessage}`
    : userMessage;

  const result = await syncRequest(fullPrompt, apiKey, maxTokens);

  if (result.error) {
    log.error(`[${requestId}] sync error: ${result.error}`);
    return res.status(502).json({ error: result.error });
  }

  log.debug(`[${requestId}] sync ok: "${result.text.slice(0, 60)}"`);
  return res.json({ text: result.text });
});

// ════════════════════════════════════════════════════════════════════════════
// ROTA: GET /health
//
// Responde sempre 200 com JSON de status.
// Usado pelo Digital Ocean App Platform para health check.
// ════════════════════════════════════════════════════════════════════════════

app.get('/health', (_req, res) => {
  res.json({
    status:    'ok',
    service:   'MedCases Pro AI Gateway',
    version:   '2.4.0',
    model:     GEMINI_MODEL,
    timestamp: new Date().toISOString(),
    uptime:    Math.floor(process.uptime()),
  });
});

// ── Handler 404 ───────────────────────────────────────────────────────────────

app.use((_req, res) => {
  res.status(404).json({ error: 'not_found' });
});

// ── Handler de erro global ────────────────────────────────────────────────────

// eslint-disable-next-line no-unused-vars
app.use((err, _req, res, _next) => {
  log.error('Erro não tratado:', err.message);
  if (!res.headersSent) {
    res.status(500).json({ error: 'internal_server_error' });
  }
});

// ════════════════════════════════════════════════════════════════════════════
// STARTUP
// ════════════════════════════════════════════════════════════════════════════

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

app.listen(PORT, '0.0.0.0', () => {
  log.info('══════════════════════════════════════════════════════');
  log.info('  MedCases Pro — AI Gateway Server v2.4.0 (Build 151)');
  log.info(`  Porta:         ${PORT}`);
  log.info(`  Ambiente:      ${IS_PROD ? 'production' : 'development'}`);
  log.info(`  Modelo Gemini: ${GEMINI_MODEL}`);
  log.info(`  GEMINI_KEY:    ${GEMINI_API_KEY ? '✓ configurada' : '✗ AUSENTE — servidor não funcionará'}`);
  log.info(`  CORS origem:   ${ALLOWED_ORIGIN}`);
  log.info('══════════════════════════════════════════════════════');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  log.info('SIGTERM recebido — encerrando servidor...');
  process.exit(0);
});

process.on('SIGINT', () => {
  log.info('SIGINT recebido — encerrando servidor...');
  process.exit(0);
});
