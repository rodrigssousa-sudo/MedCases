/**
 * Cloud Functions — MedCases Pro  (firebase-functions v6 / Node 22)
 *
 * 1. onNewUserRegistered  → onCreate  → notifica admin quando novo usuário se cadastra
 * 2. onUserApproved       → onUpdate  → e-mail de boas-vindas ao usuário aprovado
 * 3. onUserUnblocked      → onUpdate  → e-mail de reativação ao usuário desbloqueado
 * 4. geminiPaidProxy      → onRequest → proxy seguro Gemini Paid (Build 226)
 *
 * Secrets (configurar UMA vez no terminal do Mac):
 *   firebase functions:secrets:set GMAIL_PASS
 *   firebase functions:secrets:set ADMIN_EMAIL
 *   firebase functions:secrets:set GEMINI_PAID_API_KEY   ← Build 226
 *
 * SEGURANÇA Build 226:
 *   GEMINI_PAID_API_KEY NUNCA é retornada ao cliente.
 *   NUNCA é logada. NUNCA aparece no bundle web.
 *   Apenas lida server-side no geminiPaidProxy.
 */

const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin      = require('firebase-admin');
const nodemailer = require('nodemailer');
const https      = require('https');

admin.initializeApp();

// ── Secrets (substitui o functions.config() depreciado) ───────────────────────
const GMAIL_USER        = 'medcasespro@gmail.com';
const GMAIL_PASS        = defineSecret('GMAIL_PASS');
const ADMIN_EMAIL       = defineSecret('ADMIN_EMAIL');
const GEMINI_PAID_KEY   = defineSecret('GEMINI_PAID_API_KEY'); // Build 226 — NUNCA exposta ao cliente

// ── Helper: cria transporter com a senha do secret ────────────────────────────
function getTransporter(gmailPass) {
  if (!gmailPass) {
    console.error('❌ Secret GMAIL_PASS não definido. Rode: firebase functions:secrets:set GMAIL_PASS');
    return null;
  }
  return nodemailer.createTransport({
    service: 'gmail',
    auth: { user: GMAIL_USER, pass: gmailPass },
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// 1. NOVO USUÁRIO → notifica admin
// ══════════════════════════════════════════════════════════════════════════════
exports.onNewUserRegistered = onDocumentCreated(
  { document: 'users/{uid}', region: 'us-central1', secrets: [GMAIL_PASS, ADMIN_EMAIL] },
  async (event) => {
    const data = event.data?.data();
    if (!data) return null;

    // Ignora admin (já aprovado automaticamente)
    if (data.status === 'approved') {
      console.log('Admin ou usuário auto-aprovado — ignorando notificação.');
      return null;
    }

    const userName        = data.displayName  || 'Usuário';
    const userEmail       = data.email        || '(sem e-mail)';
    const userProfession  = data.profession   || '—';
    const userInstitution = data.institution  || '—';
    const uid             = event.params.uid;
    const createdAt       = new Date().toLocaleString('pt-BR', { timeZone: 'America/Sao_Paulo' });

    const adminEmail  = ADMIN_EMAIL.value() || 'rodrigssousa@gmail.com';
    const transporter = getTransporter(GMAIL_PASS.value());
    if (!transporter) return null;

    try {
      await transporter.sendMail({
        from:    `"MedCases Pro" <${GMAIL_USER}>`,
        to:      adminEmail,
        subject: `🆕 Novo pedido de acesso — ${userName}`,
        html:    buildAdminNotificationHtml({ userName, userEmail, userProfession, userInstitution, uid, createdAt }),
      });
      console.log(`✅ Admin notificado sobre novo cadastro de ${userEmail}`);
    } catch (err) {
      console.error('❌ Erro ao notificar admin:', err);
    }

    return null;
  }
);

// ══════════════════════════════════════════════════════════════════════════════
// 2. USUÁRIO APROVADO → e-mail de boas-vindas
//    Cobre: pending → approved  (qualquer status exceto blocked → approved)
// ══════════════════════════════════════════════════════════════════════════════
exports.onUserApproved = onDocumentUpdated(
  { document: 'users/{uid}', region: 'us-central1', secrets: [GMAIL_PASS] },
  async (event) => {
    const before = event.data?.before.data();
    const after  = event.data?.after.data();
    if (!before || !after) return null;

    // Só dispara: qualquer status (exceto blocked) → approved
    if (after.status !== 'approved') return null;
    if (before.status === 'approved') return null;
    if (before.status === 'blocked') return null; // tratado por onUserUnblocked

    const userName  = after.displayName || 'Médico(a)';
    const userEmail = after.email       || '';
    const userLang  = after.lang        || 'pt';

    if (!userEmail) { console.log('Usuário sem e-mail, ignorando.'); return null; }

    const transporter = getTransporter(GMAIL_PASS.value());
    if (!transporter) return null;

    const isEs = userLang === 'es';
    try {
      await transporter.sendMail({
        from:    `"MedCases Pro" <${GMAIL_USER}>`,
        to:      userEmail,
        subject: isEs ? '✅ Tu acceso a MedCases Pro fue aprobado' : '✅ Seu acesso ao MedCases Pro foi aprovado',
        html:    buildUserEmailHtml(userName, isEs, false),
      });
      console.log(`✅ E-mail de aprovação enviado para ${userEmail}`);
    } catch (err) {
      console.error(`❌ Erro ao enviar e-mail de aprovação para ${userEmail}:`, err);
    }

    return null;
  }
);

// ══════════════════════════════════════════════════════════════════════════════
// 3. USUÁRIO DESBLOQUEADO → e-mail de reativação (blocked → approved)
// ══════════════════════════════════════════════════════════════════════════════
exports.onUserUnblocked = onDocumentUpdated(
  { document: 'users/{uid}', region: 'us-central1', secrets: [GMAIL_PASS] },
  async (event) => {
    const before = event.data?.before.data();
    const after  = event.data?.after.data();
    if (!before || !after) return null;

    if (before.status !== 'blocked' || after.status !== 'approved') return null;

    const userName  = after.displayName || 'Médico(a)';
    const userEmail = after.email       || '';
    const userLang  = after.lang        || 'pt';

    if (!userEmail) return null;

    const transporter = getTransporter(GMAIL_PASS.value());
    if (!transporter) return null;

    const isEs = userLang === 'es';
    try {
      await transporter.sendMail({
        from:    `"MedCases Pro" <${GMAIL_USER}>`,
        to:      userEmail,
        subject: isEs ? '🔓 Tu acceso a MedCases Pro fue restaurado' : '🔓 Seu acesso ao MedCases Pro foi restaurado',
        html:    buildUserEmailHtml(userName, isEs, true),
      });
      console.log(`✅ E-mail de desbloqueio enviado para ${userEmail}`);
    } catch (err) {
      console.error('❌ Erro ao enviar e-mail de desbloqueio:', err);
    }

    return null;
  }
);

// ══════════════════════════════════════════════════════════════════════════════
// 4. GEMINI PAID PROXY — Build 226
//
// ENDPOINT: POST /geminiPaidProxy
//
// SEGURANÇA:
//   • GEMINI_PAID_API_KEY lida do Firebase Secret — NUNCA retornada ao cliente
//   • Valida autenticação Firebase (token obrigatório)
//   • Valida status do usuário no Firestore (approved)
//   • Valida budget diário (paidFallbackMaxPerDay) e por usuário/hora
//   • Responde APENAS com o texto gerado pelo Gemini — jamais com a chave
//   • Nunca loga a chave (nem parcialmente)
//
// PAYLOAD (cliente → função):
//   { userMessage, systemPrompt, history, mode, requestId, lang }
//
// RESPOSTA (função → cliente):
//   { text, model, inputTokensApprox, outputTokensApprox, durationMs }
//   ou { error: 'reason' }  (sem a chave)
//
// MODELO PREFERENCIAL: gemini-2.5-flash
// ══════════════════════════════════════════════════════════════════════════════

// ── Constantes de budget ───────────────────────────────────────────────────
const PAID_MAX_PER_DAY          = 4000;  // limite diário global
const PAID_MAX_PER_USER_PER_HOUR = 20;   // limite por usuário por hora
const GEMINI_PAID_MODEL         = 'gemini-2.5-flash';
const GEMINI_API_BASE           = 'generativelanguage.googleapis.com';

// ── CORS: origens permitidas para geminiPaidProxy ─────────────────────────────
// Authorization header obriga uso de origem explícita — wildcard '*' é rejeitado
// pelo browser quando credentials (Authorization) estão presentes no request.
const PAID_PROXY_ALLOWED_ORIGINS = [
  'https://medcasespro.com',
  'https://www.medcasespro.com',
];

/**
 * Resolve a origem CORS para o response.
 * - Se a origem do request está na allowlist → reflete ela (necessário para Auth header).
 * - Se é localhost / 127.0.0.1 (qualquer porta) → permite para debug local.
 * - Caso contrário → não emite o header (browser bloqueará).
 */
function resolveCorsOrigin(reqOrigin) {
  if (!reqOrigin) return null;
  if (PAID_PROXY_ALLOWED_ORIGINS.includes(reqOrigin)) return reqOrigin;
  // Permite qualquer porta de localhost para desenvolvimento local
  if (/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(reqOrigin)) return reqOrigin;
  return null;
}

/** Aplica os headers CORS obrigatórios em toda resposta. */
function setCorsHeaders(req, res) {
  const origin = resolveCorsOrigin(req.headers.origin);
  if (origin) {
    res.set('Access-Control-Allow-Origin',  origin);
    res.set('Vary', 'Origin'); // instrui caches a variar por origin
  }
  res.set('Access-Control-Allow-Methods',  'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers',  'Authorization, Content-Type');
  res.set('Access-Control-Max-Age',        '86400'); // 24h — reduz preflights
}

exports.geminiPaidProxy = onRequest(
  {
    region:         'us-central1',
    secrets:        [GEMINI_PAID_KEY],
    // cors: false — gerenciamos CORS manualmente para suportar origem explícita
    // (necessário quando o request usa Authorization header com credentials).
    cors:           false,
    timeoutSeconds: 60,
    memory:         '256MiB',
  },
  async (req, res) => {
    const startMs = Date.now();

    // ── CORS: aplicar headers ANTES de qualquer lógica ou retorno ───────────
    // Regra: nenhum throw/return pode acontecer antes daqui.
    setCorsHeaders(req, res);

    // ── CORS preflight (OPTIONS) ─────────────────────────────────────────────
    // O browser envia OPTIONS antes do POST real quando há custom headers
    // (ex: Authorization). Deve retornar 204 imediatamente, sem autenticar.
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).json({ error: 'method_not_allowed' });
      return;
    }

    // ── 1. Autenticação Firebase ────────────────────────────────────────────
    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) {
      console.warn('[PAID_PROXY] unauthenticated request');
      res.status(401).json({ error: 'unauthenticated' });
      return;
    }
    const idToken = authHeader.split('Bearer ')[1];
    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (e) {
      console.warn('[PAID_PROXY] token inválido:', e.code);
      res.status(401).json({ error: 'invalid_token' });
      return;
    }
    const uid = decodedToken.uid;

    // ── 2. Valida status do usuário (approved) ──────────────────────────────
    let userDoc;
    try {
      userDoc = await admin.firestore().collection('users').doc(uid).get();
    } catch (e) {
      console.error('[PAID_PROXY] erro ao buscar usuário:', e.message);
      res.status(500).json({ error: 'user_check_failed' });
      return;
    }
    if (!userDoc.exists || userDoc.data().status !== 'approved') {
      console.warn('[PAID_PROXY] usuário não aprovado uid=' + uid);
      res.status(403).json({ error: 'user_not_approved' });
      return;
    }

    // ── 3. Verifica se fallback pago está ativado no config ─────────────────
    let paidEnabled = false;
    try {
      const cfgDoc = await admin.firestore()
        .collection('app_config').doc('global').get();
      paidEnabled = cfgDoc.exists && cfgDoc.data().geminiPaidEnabled === true;
    } catch (e) {
      console.error('[PAID_PROXY] erro ao ler config:', e.message);
    }
    if (!paidEnabled) {
      console.log('[PAID_PROXY] fallback pago desativado no config');
      res.status(503).json({ error: 'paid_fallback_disabled' });
      return;
    }

    // ── 4. Budget guard ─────────────────────────────────────────────────────
    const todayKey = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
    const hourKey  = new Date().toISOString().slice(0, 13); // YYYY-MM-DDTHH
    const budgetRef = admin.firestore().collection('app_config').doc('paid_budget');
    let budgetData  = {};
    try {
      const budgetDoc = await budgetRef.get();
      budgetData = budgetDoc.exists ? budgetDoc.data() : {};
    } catch (e) {
      console.error('[PAID_PROXY] erro ao ler budget:', e.message);
    }

    const dailyCount       = (budgetData.dailyCount   || 0);
    const dailyDate        = (budgetData.dailyDate     || '');
    const effectiveDailyCount = dailyDate === todayKey ? dailyCount : 0;

    const userHourKey      = `${uid}_${hourKey}`;
    const userHourCount    = (budgetData[userHourKey]  || 0);

    const budgetOk = effectiveDailyCount < PAID_MAX_PER_DAY &&
                     userHourCount       < PAID_MAX_PER_USER_PER_HOUR;

    console.log('[BUDGET_GUARD] '
      + `allowed=${budgetOk} `
      + `paidFallbackCountToday=${effectiveDailyCount} `
      + `paidFallbackMaxPerDay=${PAID_MAX_PER_DAY} `
      + `userHourCount=${userHourCount} `
      + `paidFallbackMaxPerUserPerHour=${PAID_MAX_PER_USER_PER_HOUR}`);

    if (!budgetOk) {
      console.log('[BUDGET_GUARD] reason=paid_budget_guard_triggered uid=' + uid);
      res.status(429).json({ error: 'paid_budget_guard_triggered' });
      return;
    }

    // ── 5. Valida payload ───────────────────────────────────────────────────
    const { userMessage, systemPrompt, history = [], mode = 'plantao', requestId = '', lang = 'pt' } = req.body || {};
    if (!userMessage || typeof userMessage !== 'string' || userMessage.trim().length === 0) {
      res.status(400).json({ error: 'invalid_payload' });
      return;
    }

    // ── 6. Lê a chave paga do Secret (NUNCA retornada ao cliente) ───────────
    const paidApiKey = GEMINI_PAID_KEY.value();
    if (!paidApiKey || paidApiKey.trim().length === 0) {
      console.error('[PAID_PROXY] GEMINI_PAID_API_KEY secret não configurado');
      res.status(503).json({ error: 'paid_key_not_configured' });
      return;
    }

    // ── 7. Monta payload Gemini ─────────────────────────────────────────────
    const contents = [];
    // Histórico (máx 4 pares para reduzir tokens)
    const recentHistory = Array.isArray(history) ? history.slice(-8) : [];
    for (const turn of recentHistory) {
      if (turn.role === 'user' || turn.role === 'model') {
        contents.push({ role: turn.role, parts: [{ text: turn.content || turn.text || '' }] });
      }
    }
    // Mensagem atual
    contents.push({ role: 'user', parts: [{ text: userMessage.trim() }] });

    const geminiPayload = {
      system_instruction: {
        parts: [{ text: systemPrompt || '' }],
      },
      contents,
      generationConfig: {
        temperature:     0.3,
        maxOutputTokens: 1024,
        topP:            0.9,
        topK:            40,
      },
      safetySettings: [
        { category: 'HARM_CATEGORY_HARASSMENT',        threshold: 'BLOCK_NONE' },
        { category: 'HARM_CATEGORY_HATE_SPEECH',       threshold: 'BLOCK_NONE' },
        { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_NONE' },
        { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_NONE' },
      ],
    };

    const payloadStr   = JSON.stringify(geminiPayload);
    const inputTokensApprox = Math.ceil(payloadStr.length / 4);

    // ── 8. Chama Gemini Paid ────────────────────────────────────────────────
    const path = `/v1beta/models/${GEMINI_PAID_MODEL}:generateContent?key=${paidApiKey}`;
    let responseText = '';
    let httpStatus   = 200;

    try {
      responseText = await new Promise((resolve, reject) => {
        const postData = payloadStr;
        const options  = {
          hostname: GEMINI_API_BASE,
          port:     443,
          path,
          method:   'POST',
          headers:  {
            'Content-Type':   'application/json',
            'Content-Length': Buffer.byteLength(postData),
          },
        };
        const apiReq = https.request(options, (apiRes) => {
          httpStatus = apiRes.statusCode;
          let body   = '';
          apiRes.on('data', (chunk) => { body += chunk; });
          apiRes.on('end', () => { resolve(body); });
        });
        apiReq.on('error', reject);
        apiReq.setTimeout(45000, () => { apiReq.destroy(new Error('timeout')); });
        apiReq.write(postData);
        apiReq.end();
      });
    } catch (e) {
      const durationMs = Date.now() - startMs;
      console.error('[PAID_PROXY] requestId=' + requestId + ' error=' + e.message + ' durationMs=' + durationMs);
      res.status(502).json({ error: 'upstream_error' });
      return;
    }

    const durationMs = Date.now() - startMs;

    // ── 9. Parse resposta Gemini ────────────────────────────────────────────
    if (httpStatus !== 200) {
      console.error('[PAID_PROXY] requestId=' + requestId
        + ' gemini_status=' + httpStatus
        + ' durationMs=' + durationMs);
      // Não loga o body (pode conter info sensível em erros de autenticação)
      res.status(502).json({ error: 'gemini_error', status: httpStatus });
      return;
    }

    let parsedText = '';
    try {
      const parsed = JSON.parse(responseText);
      parsedText = parsed?.candidates?.[0]?.content?.parts?.[0]?.text || '';
    } catch (e) {
      console.error('[PAID_PROXY] parse error requestId=' + requestId);
      res.status(502).json({ error: 'parse_error' });
      return;
    }

    if (!parsedText || parsedText.trim().length === 0) {
      console.warn('[PAID_PROXY] resposta vazia requestId=' + requestId);
      res.status(502).json({ error: 'empty_response' });
      return;
    }

    const outputTokensApprox = Math.ceil(parsedText.length / 4);

    // ── 10. Atualiza contadores de budget (fire-and-forget) ─────────────────
    try {
      const newDailyCount = (dailyDate === todayKey ? effectiveDailyCount : 0) + 1;
      const newUserHour   = userHourCount + 1;
      await budgetRef.set({
        dailyCount:    newDailyCount,
        dailyDate:     todayKey,
        [userHourKey]: newUserHour,
        lastRequestId: requestId,
        lastUpdatedAt: new Date().toISOString(),
        estimatedPaidCostUsd: ((newDailyCount * (inputTokensApprox + outputTokensApprox)) / 1_000_000 * 0.30).toFixed(6),
      }, { merge: true });
    } catch (e) {
      console.warn('[PAID_PROXY] budget update error:', e.message);
      // Não bloqueia a resposta — budget update é best-effort
    }

    // ── 11. Log de auditoria (SEM chave) ────────────────────────────────────
    console.log('[PAID_PROXY] '
      + `requestId=${requestId} `
      + `success=true `
      + `status=200 `
      + `model=${GEMINI_PAID_MODEL} `
      + `mode=${mode} `
      + `lang=${lang} `
      + `inputTokensApprox=${inputTokensApprox} `
      + `outputTokensApprox=${outputTokensApprox} `
      + `durationMs=${durationMs}`);

    console.log('[PROVIDER_ROUTER] '
      + `requestId=${requestId} `
      + `mode=${mode} `
      + `primary=gemini_free `
      + `fallback=gemini_paid `
      + `usedProvider=gemini_paid `
      + `status=success `
      + `inputTokensApprox=${inputTokensApprox} `
      + `outputTokensApprox=${outputTokensApprox} `
      + `durationMs=${durationMs}`);

    // ── 12. Responde com APENAS o texto — NUNCA com a chave ─────────────────
    res.status(200).json({
      text:              parsedText,
      model:             GEMINI_PAID_MODEL,
      inputTokensApprox,
      outputTokensApprox,
      durationMs,
    });
  }
);

// ══════════════════════════════════════════════════════════════════════════════
// TEMPLATE: E-MAIL PARA O ADMIN (novo cadastro)
// ══════════════════════════════════════════════════════════════════════════════
function buildAdminNotificationHtml({ userName, userEmail, userProfession, userInstitution, uid, createdAt }) {
  return `
<!DOCTYPE html>
<html lang="pt-br" xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="light only">
  <meta name="supported-color-schemes" content="light only">
  <title>Novo pedido de acesso</title>
  <style>
    :root { color-scheme: light only; }
    @media (prefers-color-scheme: dark) {
      body, table, td, div, p, a, span, h1, h2, h3 {
        color: inherit !important;
        background-color: inherit !important;
      }
    }
  </style>
</head>
<body style="margin:0;padding:0;background-color:#f0f4f1;font-family:Arial,sans-serif;" bgcolor="#f0f4f1">
  <table width="100%" cellpadding="0" cellspacing="0" bgcolor="#f0f4f1" style="background-color:#f0f4f1;padding:32px 16px;">
    <tr><td align="center">
      <table width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;">

        <tr><td style="background:linear-gradient(135deg,#0f1c14 0%,#1b3d2a 50%,#1f6b48 100%);border-radius:18px 18px 0 0;padding:36px 32px 28px;text-align:center;">
          <div style="display:inline-block;background:rgba(197,163,101,0.15);border:1.5px solid rgba(197,163,101,0.4);border-radius:14px;padding:10px 18px;margin-bottom:16px;">
            <span style="font-size:22px;font-weight:900;color:#FFE8A6 !important;">M+</span>
            <span style="font-size:13px;font-weight:700;color:#F0C97A !important;margin-left:8px;letter-spacing:1px;">MEDCASES PRO</span>
          </div>
          <div style="font-size:36px;margin-bottom:12px;">🆕</div>
          <h1 style="margin:0;font-size:22px;font-weight:900;color:#ffffff !important;">Novo pedido de acesso</h1>
          <p style="margin:8px 0 0;font-size:13px;color:rgba(255,255,255,0.75) !important;">${createdAt} (Horário de Brasília)</p>
        </td></tr>

        <tr><td bgcolor="#ffffff" style="background-color:#ffffff !important;padding:32px 32px 24px;">
          <p style="font-size:15px;color:#1a1a1a !important;margin:0 0 20px;">Um novo usuário solicitou acesso ao <strong style="color:#1a1a1a !important;">MedCases Pro</strong>. Revise os dados abaixo e aprove no painel admin.</p>
          <div style="background:#f7faf8 !important;border:1px solid #d1e8da;border-radius:12px;padding:20px 24px;margin-bottom:28px;">
            <p style="font-size:11px;font-weight:900;color:#1f6b48 !important;letter-spacing:1.5px;margin:0 0 16px;">DADOS DO SOLICITANTE</p>
            <table width="100%" cellpadding="0" cellspacing="0">
              <tr><td style="padding:6px 0;font-size:12px;color:#555555 !important;width:110px;">Nome</td><td style="padding:6px 0;font-size:14px;color:#1a1a1a !important;font-weight:700;">${userName}</td></tr>
              <tr><td style="padding:6px 0;font-size:12px;color:#555555 !important;">E-mail</td><td style="padding:6px 0;font-size:14px;color:#1a1a1a !important;">${userEmail}</td></tr>
              <tr><td style="padding:6px 0;font-size:12px;color:#555555 !important;">Profissão</td><td style="padding:6px 0;font-size:14px;color:#1a1a1a !important;">${userProfession}</td></tr>
              <tr><td style="padding:6px 0;font-size:12px;color:#555555 !important;">Instituição</td><td style="padding:6px 0;font-size:14px;color:#1a1a1a !important;">${userInstitution}</td></tr>
              <tr><td style="padding:6px 0;font-size:12px;color:#555555 !important;">UID</td><td style="padding:6px 0;font-size:11px;color:#888888 !important;font-family:monospace;">${uid}</td></tr>
            </table>
          </div>
          <table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center">
            <a href="https://medcasespro.com" style="display:inline-block;background:linear-gradient(135deg,#d4af5a,#c5a365);color:#0f1c14 !important;font-size:15px;font-weight:900;text-decoration:none;padding:14px 40px;border-radius:12px;">Ir para o Painel Admin →</a>
          </td></tr></table>
        </td></tr>

        <tr><td bgcolor="#f7faf8" style="background-color:#f7faf8 !important;border:1px solid #e5ebe7;border-top:none;border-radius:0 0 18px 18px;padding:20px 32px;text-align:center;">
          <p style="font-size:12px;color:#888888 !important;margin:0 0 4px;">Esta é uma notificação automática do MedCases Pro.</p>
          <p style="font-size:12px;font-weight:700;color:#1f6b48 !important;margin:0;">Equipe MedCases Pro</p>
        </td></tr>

      </table>
    </td></tr>
  </table>
</body></html>`;
}

// ══════════════════════════════════════════════════════════════════════════════
// TEMPLATE: E-MAIL PARA O USUÁRIO (aprovação / reativação)
// ══════════════════════════════════════════════════════════════════════════════
function buildUserEmailHtml(userName, isEs, isUnblock = false) {
  const firstName = userName.split(' ')[0];
  const greeting  = isEs ? `¡Hola, ${firstName}!` : `Olá, ${firstName}!`;
  const headline  = isUnblock
    ? (isEs ? 'Tu acceso fue restaurado'  : 'Seu acesso foi restaurado')
    : (isEs ? '¡Tu acceso fue aprobado!' : 'Seu acesso foi aprovado!');
  const body1 = isUnblock
    ? (isEs
        ? 'Tu cuenta en <strong>MedCases Pro</strong> fue reactivada. Ya puedes acceder a todos los recursos clínicos.'
        : 'Sua conta no <strong>MedCases Pro</strong> foi reativada. Você já pode acessar todos os recursos clínicos.')
    : (isEs
        ? 'Tu solicitud de acceso a <strong>MedCases Pro</strong> fue revisada y aprobada por nuestro equipo.'
        : 'Sua solicitação de acesso ao <strong>MedCases Pro</strong> foi revisada e aprovada pela nossa equipe.');

  const features = isEs ? [
    '📋 Casos clínicos comentados por especialistas',
    '💊 Base de datos de medicamentos con dosis',
    '🤖 Asistente clínico con IA (GPT-4o mini)',
    '📝 Crea y comparte tus propios casos',
    '⚙️ Herramientas clínicas: calculadoras y escalas',
  ] : [
    '📋 Casos clínicos comentados por especialistas',
    '💊 Base de dados de medicamentos com doses',
    '🤖 Assistente clínico com IA (GPT-4o mini)',
    '📝 Crie e compartilhe seus próprios casos',
    '⚙️ Ferramentas clínicas: calculadoras e escalas',
  ];

  const featuresHtml = features.map(f => `
    <tr><td style="padding:7px 0;font-size:14px;color:#1a3a28 !important;font-family:Arial,sans-serif;">${f}</td></tr>`).join('');

  const ctaLabel = isEs ? 'Acceder ahora' : 'Acessar agora';
  const footer1  = isEs ? 'Si tienes dudas, responde este e-mail.' : 'Em caso de dúvidas, responda este e-mail.';
  const footer2  = isEs ? 'Equipo MedCases Pro' : 'Equipe MedCases Pro';

  return `
<!DOCTYPE html>
<html lang="${isEs ? 'es' : 'pt-br'}" xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="light only">
  <meta name="supported-color-schemes" content="light only">
  <title>${headline}</title>
  <style>
    :root { color-scheme: light only; }
    @media (prefers-color-scheme: dark) {
      body, table, td, div, p, a, span, h1, h2, h3 {
        color: inherit !important;
        background-color: inherit !important;
      }
    }
  </style>
</head>
<body style="margin:0;padding:0;background-color:#f0f4f1;font-family:Arial,sans-serif;" bgcolor="#f0f4f1">
  <table width="100%" cellpadding="0" cellspacing="0" bgcolor="#f0f4f1" style="background-color:#f0f4f1;padding:32px 16px;">
    <tr><td align="center">
      <table width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;">

        <tr><td style="background:linear-gradient(135deg,#0f1c14 0%,#1b3d2a 50%,#1f6b48 100%);border-radius:18px 18px 0 0;padding:36px 32px 28px;text-align:center;">
          <div style="display:inline-block;background:rgba(197,163,101,0.15);border:1.5px solid rgba(197,163,101,0.4);border-radius:14px;padding:10px 18px;margin-bottom:16px;">
            <span style="font-size:22px;font-weight:900;color:#FFE8A6 !important;">M+</span>
            <span style="font-size:13px;font-weight:700;color:#F0C97A !important;margin-left:8px;letter-spacing:1px;">MEDCASES PRO</span>
          </div>
          <div style="width:64px;height:64px;background:rgba(74,222,128,0.2);border:2px solid rgba(74,222,128,0.5);border-radius:50%;margin:0 auto 16px;font-size:28px;line-height:64px;text-align:center;">✅</div>
          <h1 style="margin:0;font-size:24px;font-weight:900;color:#ffffff !important;">${headline}</h1>
        </td></tr>

        <tr><td bgcolor="#ffffff" style="background-color:#ffffff !important;padding:32px 32px 24px;">
          <p style="font-size:16px;font-weight:700;color:#1a1a1a !important;margin:0 0 12px;">${greeting}</p>
          <p style="font-size:14px;color:#444444 !important;line-height:1.6;margin:0 0 24px;">${body1}</p>
          <div style="background:#f7faf8 !important;border:1px solid #d1e8da;border-radius:12px;padding:18px 20px;margin-bottom:28px;">
            <p style="font-size:11px;font-weight:900;color:#1f6b48 !important;letter-spacing:1.5px;margin:0 0 12px;">${isEs ? 'LO QUE TIENES DISPONIBLE' : 'O QUE VOCÊ TEM DISPONÍVEL'}</p>
            <table width="100%" cellpadding="0" cellspacing="0">${featuresHtml}</table>
          </div>
          <table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center">
            <a href="https://medcasespro.com" style="display:inline-block;background:linear-gradient(135deg,#d4af5a,#c5a365);color:#0f1c14 !important;font-size:15px;font-weight:900;text-decoration:none;padding:14px 40px;border-radius:12px;">${ctaLabel} →</a>
          </td></tr></table>
        </td></tr>

        <tr><td bgcolor="#f7faf8" style="background-color:#f7faf8 !important;border:1px solid #e5ebe7;border-top:none;border-radius:0 0 18px 18px;padding:20px 32px;text-align:center;">
          <p style="font-size:12px;color:#888888 !important;margin:0 0 4px;">${footer1}</p>
          <p style="font-size:12px;font-weight:700;color:#1f6b48 !important;margin:0;">${footer2}</p>
        </td></tr>

      </table>
    </td></tr>
  </table>
</body></html>`;
}
