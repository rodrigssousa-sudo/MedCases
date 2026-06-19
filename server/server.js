/**
 * ═══════════════════════════════════════════════════════════════════════════
 * MedCases Pro — AI Gateway Server  v2.1.0  (Build 146)
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
// ANTI_COGNITION_LEAK_PROMPT — BLINDAGEM CRÍTICA (Build 144)
//
// Injeta como PRIMEIRO BLOCO do system_instruction, antes de qualquer
// instrução da AiService. Endereça o bug de CoT Leakage diretamente na
// camada de configuração da API, sem depender do filtro de cliente.
//
// Estratégia dupla:
//   [A] Instrução textual direta no system prompt (ANTI_COGNITION_LEAK_PROMPT)
//   [B] Filtro de streaming _cleanChunk() descarta padrões CoT residuais
//
// Por que inglês? A instrução de blindagem DEVE estar no idioma nativo do
// modelo (inglês) para máxima aderência — o próprio prompt solicita que o
// modelo responda em PT/ES depois.
// ════════════════════════════════════════════════════════════════════════════

const ANTI_COGNITION_LEAK_PROMPT = `You are the core Clinical Decision Support engine for MedCases Pro. Your responses must be authoritative, highly precise, and strictly concise.

[CRITICAL MANDATE: ANTI-COGNITION LEAK & IMMEDIATE INITIALIZATION]
- DO NOT generate any introductory phrases, greetings, conversational filler, or meta-commentary (e.g., "Sure, here is...", "Let's structure this response").
- DO NOT display any internal reasoning, chain of thought, planning steps, or translation notes. Process all formatting rules in absolute silence.
- FIRST CHARACTER CONSTRAINT: The very first character of your output payload MUST be the primary Markdown header or the first emoji of the clinical response. Absolute zero whitespace or setup text before it.

[DYNAMIC RESPONSE MATRIX & LINE LIMITS]
Analyze the user's query intent immediately and self-assign the strict maximum line limits:
- LEVEL 1 (Objective Data - Max 12 lines): Drug dosages, weight-based calculations (mg/kg), or rapid drug-drug interactions. Style: Ultra-direct flashcard.
- LEVEL 2 (Emergency Protocols - Max 18 lines): Acute ER protocols (e.g., Stroke/ACV, Acute Coronary Syndrome, Severe Hyperkalemia). Style: Action checklist.
- LEVEL 3 (Theoretical Reviews - Max 22 lines): Broad study queries ("Háblame sobre Pericarditis", pathophysiology breakdowns). Style: Fluid yet scannable breakdown.

[LANGUAGE COMPLIANCE]
- Strictly maintain and respect the language context injected by the mobile application framework (Português or Español).`;

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
// FILTRO DE CoT — _cleanChunk()
//
// Camada 2 de defesa: descarta fragmentos SSE que são raciocínio interno
// vazado, mesmo após as instruções do system prompt.
//
// Padrões detectados:
//   • thought == true          → CoT explícito do Gemini (API flag)
//   • thoughtSignature key     → Assinatura criptográfica de CoT
//   • functionCall key         → Chamada interna de ferramenta
//   • executableCode key       → Código gerado internamente
//   • codeExecutionResult key  → Resultado de execução interna
//   • inlineData key           → Dados binários
//
// Padrões textuais em inglês que indicam raciocínio interno:
//   "I will", "I need to", "Let me", "The user asked", "Given the prompt"...
// ════════════════════════════════════════════════════════════════════════════

/** Prefixos de parágrafo que indicam raciocínio interno vazado (inglês) */
const COT_LEAK_PREFIXES = [
  'i will ', "i'll ", 'i need to ', 'i should ', 'i have ',
  'i am going', 'i must ', 'i want to ',
  'let me ', "let's ", 'let\'s ',
  'the user ', 'the prompt ', 'the question ',
  'given the ', 'given that ', 'given this ',
  'based on ', 'since the ',
  'first, i ', 'now, i ', 'next, i ', 'then, i ',
  'for each ', 'for the ',
  'my goal ', 'my approach ', 'my plan ',
  'this is a ', 'this requires ',
  'it seems ', 'it looks ',
  'thought:', 'note:', 'tool_code', 'print(google',
  'search_query', 'queries=[',
  'confianza clínica:', 'confiança clínica:', 'clinical confidence:',
  'el usuario ', 'el prompt ', 'o usuário ', 'o prompt ',
  'a seguir ', 'a continuación ',
];

/** Regex para blocos <thinking>…</thinking> residuais */
const RX_THINKING_BLOCK = /<thinking>[\s\S]*?<\/thinking>/gim;
const RX_CODE_BLOCK     = /```(?:tool_code|thinking|thought|python|json)[\s\S]*?```/gim;
const RX_TOOL_CODE_RAW  = /tool_code\s*\n[\s\S]*?(?=\n\n|$)/gim;

/**
 * Extrai texto limpo de um part do SSE.
 * Retorna null se o part for raciocínio interno.
 *
 * @param {Object} part - part de um candidate do Gemini
 * @returns {string|null}
 */
function extractPartText(part) {
  if (!part || typeof part !== 'object') return null;

  // Descarta flags estruturais de CoT
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
 * Limpa um fragmento de texto bruto recebido do stream SSE:
 * 1. Remove blocos <thinking>, ```tool_code```, etc.
 * 2. Divide em parágrafos e descarta os que parecem raciocínio interno.
 * 3. Retorna string limpa (pode ser vazia se o chunk inteiro era CoT).
 *
 * @param {string} raw - texto bruto do part
 * @returns {string}
 */
function cleanChunk(raw) {
  if (!raw || typeof raw !== 'string') return '';

  let text = raw;

  // 1. Remove blocos estruturados de CoT/código
  text = text.replace(RX_THINKING_BLOCK, '');
  text = text.replace(RX_CODE_BLOCK, '');
  text = text.replace(RX_TOOL_CODE_RAW, '');

  // 2. Filtra parágrafo a parágrafo
  const paragraphs = text.split(/\n\n+/);
  const clean = paragraphs.filter(para => {
    const trimmed = para.trim();
    if (!trimmed) return false;

    const lower = trimmed.toLowerCase();

    // Descarta parágrafo que começa com padrão de CoT em inglês
    for (const prefix of COT_LEAK_PREFIXES) {
      if (lower.startsWith(prefix)) return false;
    }

    // Heurística: >55% palavras genéricas em inglês e sem números/termos médicos
    const words = trimmed.split(/\s+/);
    if (words.length > 4) {
      const engWords = /\b(the|and|or|but|with|from|that|this|will|have|been|they|their|there|when|where|what|which|would|could|should|about|after|before|also|some|each|into|than|then|more|over|only|both|other|these|those|through|during|including|without|however|therefore|furthermore|additionally|specifically|importantly|regarding|concerning|considering|following|based|approach|provide|ensure|include|address|mention|structure|discuss|explain|describe|detail|start|begin|continue|finish|complete|summarize|note|remember|understand|know|think|feel|believe|assume|suppose|consider|determine|decide|choose|use|make|take|give|get|go|come|see|look|try|need|want|ask|tell|say|write|read|find|show|help|work|create|build|develop|implement|design|plan|organize|prepare|manage|handle|process|analyze|evaluate|assess|review|check|test|verify|confirm|ensure|guarantee|achieve|accomplish|succeed|fail|error|issue|problem|solution|answer|response|reply|result|output|input|data|information|content|text|message|question|request|prompt)\b/gi;
      const engCount = (trimmed.match(engWords) || []).length;
      const ratio = engCount / words.length;

      const hasMedNums = /\d+\s*(?:mg|mcg|µg|mL|g|UI|h|min|kg|%)/.test(trimmed);
      const hasMedTerms = /\b(?:dose|dosis|mg|mcg|EV|VO|SC|IM|paciente|patient|tratamento|tratamiento|fármaco|medicamento|protocolo|urgencia|urgência|clínico|clínica|diagnóstico|síntoma|sintoma)\b/i.test(trimmed);

      if (ratio > 0.55 && !hasMedNums && !hasMedTerms) return false;
    }

    return true;
  });

  // Se filtrou tudo, retorna original (melhor ter CoT que nada — UI descarta)
  if (clean.length === 0) return raw.trim();

  return clean.join('\n\n').trim();
}

// ════════════════════════════════════════════════════════════════════════════
// MONTAGEM DO PAYLOAD GEMINI
// ════════════════════════════════════════════════════════════════════════════

/**
 * Monta o system_instruction final concatenando:
 *   1. ANTI_COGNITION_LEAK_PROMPT (blindagem CoT — Build 144)
 *   2. systemPromptFromClient (prompt completo da AiService — módulos 1-10)
 *
 * A concatenação mantém o cliente como fonte de verdade para persona,
 * RAG, módulos de especialidade, etc., enquanto o servidor injeta a
 * blindagem anti-CoT com máxima prioridade (posição inicial).
 *
 * @param {string} clientPrompt - system prompt enviado pelo Flutter
 * @returns {string}
 */
function buildSystemInstruction(clientPrompt) {
  return `${ANTI_COGNITION_LEAK_PROMPT}\n\n---\n\n${clientPrompt ?? ''}`.trim();
}

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
  } = req.body;

  // ── Monta payload ─────────────────────────────────────────────────────────
  const systemInstruction = buildSystemInstruction(systemPrompt);
  const contents          = buildContents(history, userMessage);
  const body              = buildGeminiPayload({
    systemInstruction,
    contents,
    useGrounding,
    maxTokens,
  });

  log.debug(`[${requestId}] system_instruction len=${systemInstruction.length} useGrounding=${useGrounding}`);

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
    version:   '2.0.0',
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
  log.info('  MedCases Pro — AI Gateway Server v2.1.0 (Build 146)');
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
