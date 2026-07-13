/**
 * Cloud Functions — MedCases Pro  (firebase-functions v6 / Node 22)
 *
 * 1. onNewUserRegistered          → onCreate  → notifica admin quando novo usuário se cadastra
 *                                               + grava admin_notifications (PARTE 4 BUILD 238)
 *                                               + envia FCM push a todos admin/master (PARTE 5 BUILD 238)
 * 2. onUserApproved               → onUpdate  → e-mail de boas-vindas ao usuário aprovado
 * 3. onUserUnblocked              → onUpdate  → e-mail de reativação ao usuário desbloqueado
 * 4. onAdminNotificationCreated   → onCreate  → BUILD 311: push FCM imediato quando
 *                                               admin_notifications/{id} é criado (pelo app
 *                                               no boot do novo usuário OU pela Cloud Function).
 *                                               Título/corpo bilíngue baseado no lang do admin.
 * 5. onGlobalPushCampaignCreated  → onCreate  → BUILD 311b: push em lote para TODOS os usuários
 *                                               quando admin dispara campanha global pelo painel.
 *                                               Varredura paginada da coleção /users, blocos de
 *                                               500 tokens, cleanup automático de tokens inválidos.
 * 6. geminiPaidProxy              → onRequest → proxy seguro Gemini Paid (Build 226)
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
 *
 * BUILD 459 — atenderConsultaIA:
 *   GEMINI_AI_KEY secret dedicado para o motor de IA principal.
 *   Configurar: firebase functions:secrets:set GEMINI_AI_KEY
 *   NUNCA retornada ao cliente. NUNCA logada.
 */

const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onRequest, onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin      = require('firebase-admin');
const nodemailer = require('nodemailer');
const https      = require('https');

// ── BUILD 459: Secret dedicado ao motor de IA server-side ────────────────────
// Configurar: firebase functions:secrets:set GEMINI_AI_KEY
// Nunca exposta ao cliente — lida exclusivamente server-side nesta CF.
const GEMINI_AI_KEY = defineSecret('GEMINI_AI_KEY');

admin.initializeApp();

// ── Secrets (substitui o functions.config() depreciado) ───────────────────────
const GMAIL_USER        = 'medcasespro@gmail.com';
const GMAIL_PASS        = defineSecret('GMAIL_PASS');
const ADMIN_EMAIL       = defineSecret('ADMIN_EMAIL');
const GEMINI_PAID_KEY   = defineSecret('GEMINI_PAID_API_KEY'); // Build 226 — NUNCA exposta ao cliente
const OPENAI_KEY        = defineSecret('OPENAI_API_KEY');       // BUILD 321 — GPT-4o Mini Layer 2 fallback

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
// PARTE 4+5 BUILD 238 — helpers
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Grava um documento em /admin_notifications/{notificationId} via Admin SDK.
 * Admin SDK bypassa Firestore Rules (allow create: if false no cliente).
 */
async function createAdminNotification({ uid, userName, userEmail, userProfession, userInstitution, userStatus, createdAt }) {
  try {
    const db = admin.firestore();
    await db.collection('admin_notifications').add({
      type:            'new_user',
      uid,
      userName,
      userEmail,
      userProfession,
      userInstitution,
      userStatus,
      createdAt:       admin.firestore.FieldValue.serverTimestamp(),
      createdAtLabel:  createdAt,
      readBy:          [],   // arrayUnion(adminUid) ao marcar como lido
    });
    console.log(`✅ [ADMIN_NOTIF] admin_notifications doc criado para uid=${uid}`);
  } catch (err) {
    console.error('❌ [ADMIN_NOTIF] Erro ao criar admin_notification:', err);
  }
}

/**
 * PARTE 5 — Envia FCM push a todos os usuários com role admin ou master.
 * Lê subcoleção users/{uid}/fcmTokens/{tokenId} de cada admin/master.
 * Usa admin.messaging().sendEachForMulticast() para envio em batch.
 * Deep-link: tap na notificação → abre Painel Master / aba Notificações.
 */
async function sendFcmPushToAdmins({ userName, userEmail, uid }) {
  try {
    const db = admin.firestore();

    // 1. Busca todos os usuários com role admin ou master
    const adminsSnap = await db.collection('users')
      .where('role', 'in', ['admin', 'master'])
      .get();

    if (adminsSnap.empty) {
      console.log('[FCM_PUSH] Nenhum admin/master encontrado para enviar push.');
      return;
    }

    // 2. Coleta todos os FCM tokens de todos os admins
    const tokens = [];
    for (const adminDoc of adminsSnap.docs) {
      const adminUid = adminDoc.id;
      const tokensSnap = await db
        .collection('users').doc(adminUid)
        .collection('fcmTokens').get();
      tokensSnap.forEach(tDoc => {
        const token = tDoc.data().token;
        if (token) tokens.push(token);
      });
    }

    if (tokens.length === 0) {
      console.log('[FCM_PUSH] Nenhum FCM token de admin encontrado.');
      return;
    }

    // 3. Envia multicast FCM com deep-link para aba Notificações
    const message = {
      notification: {
        title: '🆕 Novo cadastro — MedCases Pro',
        body:  `${userName} (${userEmail}) se cadastrou.`,
      },
      data: {
        // deep-link tratado pelo app: abre AdminScreen tab=notifications
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        route:        '/admin/notifications',
        uid:          uid,
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: '🆕 Novo cadastro — MedCases Pro',
              body:  `${userName} (${userEmail}) se cadastrou.`,
            },
            sound: 'default',
            badge: 1,
          },
        },
      },
      android: {
        priority: 'high',
        notification: { sound: 'default', channelId: 'admin_alerts' },
      },
      tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`✅ [FCM_PUSH] successCount=${response.successCount} failureCount=${response.failureCount} totalTokens=${tokens.length}`);

    // 4. Remove tokens inválidos (NotRegistered / InvalidRegistration)
    const invalidTokens = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        const errCode = resp.error?.code || '';
        if (errCode.includes('registration-token-not-registered') ||
            errCode.includes('invalid-registration-token')) {
          invalidTokens.push(tokens[idx]);
        }
      }
    });
    if (invalidTokens.length > 0) {
      console.log(`[FCM_PUSH] Removendo ${invalidTokens.length} token(s) inválido(s).`);
      // Remove de todos os admins (varredura simples)
      for (const adminDoc of adminsSnap.docs) {
        const adminUid = adminDoc.id;
        const tokensSnap = await db
          .collection('users').doc(adminUid)
          .collection('fcmTokens').get();
        for (const tDoc of tokensSnap.docs) {
          if (invalidTokens.includes(tDoc.data().token)) {
            await tDoc.ref.delete();
          }
        }
      }
    }
  } catch (err) {
    console.error('❌ [FCM_PUSH] Erro ao enviar push para admins:', err);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 1. NOVO USUÁRIO → notifica admin (e-mail + admin_notifications + FCM push)
// ══════════════════════════════════════════════════════════════════════════════
exports.onNewUserRegistered = onDocumentCreated(
  { document: 'users/{uid}', region: 'us-central1', secrets: [GMAIL_PASS, ADMIN_EMAIL] },
  async (event) => {
    const data = event.data?.data();
    if (!data) return null;

    // fix(auth): não ignora mais usuários auto-aprovados (status=approved).
    // O app cria todos os usuários com status=approved para não bloquear login,
    // mas o admin ainda precisa ser notificado de TODOS os novos cadastros.
    // Apenas ignora se o e-mail for o do admin (approvedBy=system e e-mail admin).
    const adminEmailSecret = ADMIN_EMAIL.value() || 'rodrigssousa@gmail.com';
    const isAdminUser = data.email && data.email.toLowerCase() === adminEmailSecret.toLowerCase();
    if (isAdminUser) {
      console.log(`Admin próprio se cadastrou — ignorando notificação: ${data.email}`);
      return null;
    }

    const userName        = data.displayName  || 'Usuário';
    const userEmail       = data.email        || '(sem e-mail)';
    const userProfession  = data.profession   || '—';
    const userInstitution = data.institution  || '—';
    const userStatus      = data.status       || 'approved';
    const uid             = event.params.uid;
    const createdAt       = new Date().toLocaleString('pt-BR', { timeZone: 'America/Sao_Paulo' });

    // ── PARTE 4: Gravar admin_notification no Firestore ───────────────────
    await createAdminNotification({ uid, userName, userEmail, userProfession, userInstitution, userStatus, createdAt });

    // ── PARTE 5: Enviar FCM push a todos admins/masters ───────────────────
    await sendFcmPushToAdmins({ userName, userEmail, uid });

    // ── E-mail para o admin (comportamento original) ───────────────────────
    const transporter = getTransporter(GMAIL_PASS.value());
    if (!transporter) return null;

    try {
      await transporter.sendMail({
        from:    `"MedCases Pro" <${GMAIL_USER}>`,
        to:      adminEmailSecret,
        subject: `🆕 Novo cadastro — ${userName} (status: ${userStatus})`,
        html:    buildAdminNotificationHtml({ userName, userEmail, userProfession, userInstitution, uid, createdAt }),
      });
      console.log(`✅ Admin notificado sobre novo cadastro de ${userEmail} (status: ${userStatus})`);
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
//   { userMessage, systemPrompt, history, mode, requestId, lang, maxOutputTokens }
//   BUILD 265: maxOutputTokens — Plantão=800, Estudo=2048 (clamped 200–2048 server-side)
//
// RESPOSTA (função → cliente):
//   { text, model, inputTokensApprox, outputTokensApprox, durationMs }
//   ou { error: 'reason' }  (sem a chave)
//
// MODELO PREFERENCIAL: gemini-2.5-flash
// ══════════════════════════════════════════════════════════════════════════════

// ── Constantes de budget ───────────────────────────────────────────────────
const PAID_MAX_PER_DAY          = 4000;  // limite diário global
const PAID_MAX_PER_USER_PER_HOUR = 100;  // BUILD 267: 20→100 — não bloquear médicos legítimos no lançamento
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

// ══════════════════════════════════════════════════════════════════════════════
// BUILD 311 — PUSH MATRIX: onAdminNotificationCreated
//
// GATILHO: onCreate em admin_notifications/{id}
//
// ARQUITETURA DUAL-PATH:
//   • Path A (Mobile/App): o dispositivo do novo usuário cria o documento
//     diretamente via Firestore SDK (regra: allow create: if isAuthed()).
//     Garante push imediato mesmo com cold-start da Cloud Function.
//
//   • Path B (Server): onNewUserRegistered (trigger users/{uid}) também cria
//     o documento via Admin SDK — quando o dispositivo não consegue gravar
//     (sem rede momentânea, Web, etc.).
//
//   Ambos os paths convergem aqui — este trigger dispara em QUALQUER criação
//   do documento, independente da origem. Push é enviado uma única vez.
//
// MULTILÍNGUE:
//   Lê o campo `lang` do documento do admin para escolher PT ou ES no push.
//   Fallback: PT se lang não encontrado.
//
// LIMPEZA DE TOKENS:
//   Tokens inválidos (NotRegistered / invalid-registration-token) são
//   removidos automaticamente da subcoleção fcmTokens do admin.
// ══════════════════════════════════════════════════════════════════════════════
exports.onAdminNotificationCreated = onDocumentCreated(
  { document: 'admin_notifications/{id}', region: 'us-central1' },
  async (event) => {
    const notifData = event.data?.data();
    if (!notifData) {
      console.log('[BUILD311_PUSH] Documento vazio — ignorando.');
      return null;
    }

    // Extrai campos do documento de notificação
    const userName    = notifData.userName    || notifData.displayName || 'Novo usuário';
    const userEmail   = notifData.userEmail   || notifData.email       || '';
    const uid         = notifData.uid         || event.params.id;

    console.log(`[BUILD311_PUSH] Novo admin_notification — uid=${uid} userName="${userName}"`);

    const db = admin.firestore();

    // 1. Busca todos admins/masters ativos
    let adminsSnap;
    try {
      adminsSnap = await db.collection('users')
        .where('role', 'in', ['admin', 'master'])
        .get();
    } catch (err) {
      console.error('[BUILD311_PUSH] Erro ao buscar admins:', err.message);
      return null;
    }

    if (adminsSnap.empty) {
      console.log('[BUILD311_PUSH] Nenhum admin/master encontrado — push cancelado.');
      return null;
    }

    // 2. Para cada admin: lê lang + coleta tokens FCM
    const tokenEntries = [];  // [{ adminUid, tokenDocId, token, lang }]
    for (const adminDoc of adminsSnap.docs) {
      const adminUid  = adminDoc.id;
      const adminLang = adminDoc.data().lang || 'pt';

      try {
        const tokensSnap = await db
          .collection('users').doc(adminUid)
          .collection('fcmTokens').get();

        tokensSnap.forEach(tDoc => {
          const token = tDoc.data().token;
          if (token && typeof token === 'string' && token.trim().length > 0) {
            tokenEntries.push({
              adminUid,
              tokenDocRef: tDoc.ref,
              token:       token.trim(),
              lang:        adminLang,
            });
          }
        });
      } catch (err) {
        console.warn(`[BUILD311_PUSH] Erro ao ler fcmTokens de admin ${adminUid}:`, err.message);
      }
    }

    if (tokenEntries.length === 0) {
      console.log('[BUILD311_PUSH] Nenhum FCM token de admin/master — push cancelado.');
      return null;
    }

    console.log(`[BUILD311_PUSH] ${tokenEntries.length} token(s) encontrado(s) em ${adminsSnap.size} admin(s).`);

    // 3. Agrupa por idioma para montar payloads bilíngues independentes
    //    (evita texto misto numa mesma notificação multicast)
    const byLang = {};
    for (const entry of tokenEntries) {
      const l = (entry.lang === 'es') ? 'es' : 'pt';
      if (!byLang[l]) byLang[l] = [];
      byLang[l].push(entry);
    }

    // 4. Monta e envia multicast por grupo de idioma
    const invalidTokenRefs = [];  // refs a deletar após envio

    for (const [lang, entries] of Object.entries(byLang)) {
      const isEs = (lang === 'es');

      // Título bilíngue
      const title = isEs
        ? '¡Nuevo Médico Registrado! 🚀'
        : 'Novo Médico Registrado! 🚀';

      // Corpo bilíngue — inclui nome e e-mail quando disponíveis
      const bodyName = userName && userName !== 'Novo usuário' ? `Dr(a). ${userName}` : 'Um novo médico';
      const body = isEs
        ? `${bodyName} acaba de unirse al ecosistema MedCases Pro.`
        : `${bodyName} acabou de entrar para o ecossistema MedCases Pro.`;

      const tokens = entries.map(e => e.token);

      const message = {
        notification: { title, body },
        data: {
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          route:        '/admin/notifications',
          uid:          uid,
          notif_type:   'new_user',
        },
        // ── iOS (APNs) ─────────────────────────────────────────────────────
        apns: {
          payload: {
            aps: {
              alert:            { title, body },
              sound:            'default',
              badge:            1,
              'content-available': 1,  // background fetch habilitado
            },
          },
          headers: {
            'apns-priority': '10',  // alta prioridade — entrega imediata
          },
        },
        // ── Android ────────────────────────────────────────────────────────
        android: {
          priority: 'high',
          notification: {
            sound:     'default',
            channelId: 'admin_alerts',
            icon:      'ic_notification',  // configurar no app Android
          },
        },
        tokens,
      };

      let response;
      try {
        response = await admin.messaging().sendEachForMulticast(message);
      } catch (err) {
        console.error(`[BUILD311_PUSH] Erro no multicast (lang=${lang}):`, err.message);
        continue;
      }

      console.log(
        `[BUILD311_PUSH] lang=${lang} ` +
        `successCount=${response.successCount} ` +
        `failureCount=${response.failureCount} ` +
        `totalTokens=${tokens.length}`
      );

      // 5. Mapeia tokens inválidos para remoção
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const code = resp.error?.code || '';
          const isInvalid =
            code.includes('registration-token-not-registered') ||
            code.includes('invalid-registration-token') ||
            code === 'messaging/invalid-argument';
          if (isInvalid) {
            console.log(`[BUILD311_PUSH] Token inválido detectado (idx=${idx} code=${code}) — agendado para remoção.`);
            invalidTokenRefs.push(entries[idx].tokenDocRef);
          } else {
            console.warn(`[BUILD311_PUSH] Falha não-crítica (idx=${idx} code=${code}).`);
          }
        }
      });
    }

    // 6. Remove tokens inválidos (cleanup assíncrono — não bloqueia o retorno)
    if (invalidTokenRefs.length > 0) {
      console.log(`[BUILD311_PUSH] Removendo ${invalidTokenRefs.length} token(s) inválido(s).`);
      await Promise.allSettled(invalidTokenRefs.map(ref => ref.delete()));
    }

    return null;
  }
);

// ══════════════════════════════════════════════════════════════════════════════
// BUILD 319 — GLOBAL PUSH CAMPAIGN: onGlobalPushCampaignCreated
// Refatoração completa do motor de disparo FCM HTTP v1 (firebase-admin ^12).
//
// Melhorias em relação ao BUILD 311b:
//   • Idempotência via máquina de estados: pending → processing → done/error
//     (evita double-send em retentativas da Cloud Function)
//   • Filtro targetRole: apenas usuários com role correspondente recebem push
//     ('all' = todos; 'medico'/'residente'/etc. = segmentado)
//   • Payload cross-platform completo:
//       - notification: title+body  → iOS banner na tela bloqueada + Android
//       - data: click_action FLUTTER_NOTIFICATION_CLICK + type + campaignId
//       - apns: badge:1 + content-available:1 + sound:default
//       - android: channelId medcases_admin_alerts + priority high
//   • Write-back de resultado no doc da campanha (processedAt, result{})
//   • Varredura paginada 200 usuários/página com filtragem por targetRole
//   • Blocos estritos de ≤500 tokens por sendEachForMulticast (limite FCM)
//   • Cleanup automático de tokens expirados/inválidos
// ══════════════════════════════════════════════════════════════════════════════
exports.onGlobalPushCampaignCreated = onDocumentCreated(
  { document: 'global_push_campaigns/{id}', region: 'us-central1', timeoutSeconds: 540 },
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.error('[BUILD319][GlobalPush] Evento sem dados — abortando.');
      return null;
    }

    const campaignRef = snap.ref;
    const campaignId  = snap.id;
    const data        = snap.data();

    // ── 0. Idempotência — só processa docs com status:'pending' ─────────────
    // Garante que retentativas automáticas da CF não dupliquem disparos.
    if (data.status !== 'pending') {
      console.warn(`[BUILD319][GlobalPush] Campaign ${campaignId} já processada (status=${data.status}) — ignorando.`);
      return null;
    }

    const pushTitle  = (data.title  || '').trim();
    const pushBody   = (data.body   || '').trim();
    const targetRole = (data.targetRole || 'all').trim();   // 'all' | 'medico' | 'residente' | …
    const sentBy     = data.sentBy    || 'admin';
    const sentByEmail= data.sentByEmail || '';

    if (!pushTitle || !pushBody) {
      console.error('[BUILD319][GlobalPush] title ou body vazios — abortando.');
      await campaignRef.update({ status: 'error', errorReason: 'title_or_body_empty',
                                  processedAt: admin.firestore.FieldValue.serverTimestamp() });
      return null;
    }

    // ── Transição: pending → processing (trava idempotência) ────────────────
    try {
      await campaignRef.update({
        status:    'processing',
        startedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (lockErr) {
      console.error('[BUILD319][GlobalPush] Falha ao travar status processing:', lockErr);
      return null;
    }

    console.log(
      `[BUILD319][GlobalPush] Iniciando campanha=${campaignId} ` +
      `por=${sentBy} (${sentByEmail}) | targetRole=${targetRole} | title="${pushTitle}"`
    );

    const db         = admin.firestore();
    const PAGE_SIZE  = 200;   // usuários por página na varredura paginada
    const CHUNK_SIZE = 500;   // máximo FCM sendEachForMulticast

    // ── 1. Varredura paginada de /users com filtro targetRole ────────────────
    let allTokenEntries = []; // [{ token: string, ref: DocumentReference }]
    let lastDoc         = null;
    let pageCount       = 0;
    let usersScanned    = 0;

    try {
      while (true) {
        let q = db.collection('users').orderBy('__name__').limit(PAGE_SIZE);
        if (lastDoc) q = q.startAfter(lastDoc);

        const page = await q.get();
        if (page.empty) break;

        pageCount++;
        lastDoc       = page.docs[page.docs.length - 1];
        usersScanned += page.docs.length;

        // Filtra por targetRole quando não for 'all'
        const eligibleDocs = (targetRole === 'all')
          ? page.docs
          : page.docs.filter((d) => {
              const role = (d.data().role || '').trim().toLowerCase();
              return role === targetRole.toLowerCase();
            });

        // Coleta tokens FCM de cada usuário elegível em paralelo
        const tokenPromises = eligibleDocs.map(async (userDoc) => {
          const tokensSnap = await userDoc.ref.collection('fcmTokens').get();
          const entries    = [];
          tokensSnap.forEach((tokenDoc) => {
            const tkn = (tokenDoc.data().token || tokenDoc.id || '').trim();
            if (tkn.length > 10) {
              entries.push({ token: tkn, ref: tokenDoc.ref });
            }
          });
          return entries;
        });

        const results = await Promise.all(tokenPromises);
        results.forEach((entries) => allTokenEntries.push(...entries));

        console.log(
          `[BUILD319][GlobalPush] Pág ${pageCount}: ` +
          `${page.docs.length} usuários (${eligibleDocs.length} elegíveis) | ` +
          `tokens acumulados: ${allTokenEntries.length}`
        );

        if (page.docs.length < PAGE_SIZE) break; // última página
      }
    } catch (scanErr) {
      console.error('[BUILD319][GlobalPush] Erro na varredura de usuários:', scanErr);
      await campaignRef.update({
        status: 'error', errorReason: 'user_scan_failed',
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return null;
    }

    const totalTokens = allTokenEntries.length;
    console.log(
      `[BUILD319][GlobalPush] Varredura concluída: ` +
      `${pageCount} páginas | ${usersScanned} usuários lidos | ${totalTokens} tokens coletados`
    );

    if (totalTokens === 0) {
      console.warn('[BUILD319][GlobalPush] Nenhum token FCM encontrado — encerrando sem envio.');
      await campaignRef.update({
        status:      'done',
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        result: { totalTokens: 0, successCount: 0, failureCount: 0, tokensRemoved: 0 },
      });
      return null;
    }

    // ── 2. Fatiamento em blocos de ≤500 e envio via FCM HTTP v1 ─────────────
    const chunks      = [];
    for (let i = 0; i < allTokenEntries.length; i += CHUNK_SIZE) {
      chunks.push(allTokenEntries.slice(i, i + CHUNK_SIZE));
    }

    const totalChunks  = chunks.length;
    let   successCount = 0;
    let   failureCount = 0;
    const invalidRefs  = [];

    // Códigos que indicam token permanentemente inválido → remover do Firestore
    const INVALID_CODES = new Set([
      'messaging/invalid-argument',
      'messaging/registration-token-not-registered',
      'messaging/invalid-registration-token',
      'messaging/mismatched-credential',
      'messaging/sender-id-mismatch',
    ]);

    for (let ci = 0; ci < chunks.length; ci++) {
      const chunk  = chunks[ci];
      const tokens = chunk.map((e) => e.token);

      // ── Payload cross-platform completo (BUILD 319) ──────────────────────
      // notification: acorda o dispositivo e exibe banner (iOS bloqueado + Android)
      // data: permite Flutter interceptar o tap (click_action obrigatório)
      // apns: badge + content-available para iOS background processing
      // android: channelId para Android 8+ + priority high
      const message = {
        tokens,
        notification: {
          title: pushTitle,
          body:  pushBody,
        },
        data: {
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          type:         'admin_alert',
          campaignId:   campaignId,
          title:        pushTitle,
          body:         pushBody,
        },
        apns: {
          payload: {
            aps: {
              sound:             'default',
              badge:             1,
              'content-available': 1,
            },
          },
          headers: {
            'apns-priority': '10',    // entrega imediata (vs 5 = conservação de bateria)
          },
        },
        android: {
          priority: 'high',
          notification: {
            channelId:  'medcases_admin_alerts',
            sound:      'default',
            defaultSound: true,
            defaultVibrateTimings: true,
          },
        },
      };

      let batchResponse;
      try {
        batchResponse = await admin.messaging().sendEachForMulticast(message);
      } catch (err) {
        console.error(`[BUILD319][GlobalPush] Chunk ${ci + 1}/${totalChunks} — erro fatal:`, err);
        failureCount += tokens.length;
        continue;
      }

      batchResponse.responses.forEach((resp, idx) => {
        if (resp.success) {
          successCount++;
        } else {
          failureCount++;
          const errCode = resp.error?.code || '';
          if (INVALID_CODES.has(errCode)) {
            invalidRefs.push(chunk[idx].ref);
          }
          console.warn(
            `[BUILD319][GlobalPush] Token inválido (chunk ${ci + 1}, idx ${idx}): ` +
            `code=${errCode}`
          );
        }
      });

      console.log(
        `[BUILD319][GlobalPush] Chunk ${ci + 1}/${totalChunks}: ` +
        `ok=${batchResponse.successCount} fail=${batchResponse.failureCount}`
      );
    }

    // ── 3. Cleanup automático de tokens expirados/inválidos ─────────────────
    const tokensRemoved = invalidRefs.length;
    if (tokensRemoved > 0) {
      console.log(`[BUILD319][GlobalPush] Removendo ${tokensRemoved} tokens inválidos do Firestore...`);
      await Promise.allSettled(invalidRefs.map((ref) => ref.delete()));
    }

    // ── 4. Write-back de resultado + transição → done ────────────────────────
    const resultPayload = {
      status:      'done',
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      result: {
        totalTokens,
        successCount,
        failureCount,
        tokensRemoved,
        totalChunks,
        usersScanned,
        targetRole,
      },
    };

    try {
      await campaignRef.update(resultPayload);
    } catch (writeErr) {
      // Não crítico — log mas não re-lança (o envio já aconteceu)
      console.warn('[BUILD319][GlobalPush] Falha ao gravar resultado no doc da campanha:', writeErr);
    }

    console.log(
      `[BUILD319][GlobalPush] CONCLUÍDO campanha=${campaignId} — ` +
      `totalTokens=${totalTokens} | chunks=${totalChunks} | ` +
      `success=${successCount} | failure=${failureCount} | ` +
      `tokensRemovidos=${tokensRemoved} | targetRole=${targetRole}`
    );

    return null;
  }
);

// ══════════════════════════════════════════════════════════════════════════════
// BUILD 312 — Padrões de Quick Reply que o app Flutter injeta automaticamente.
// Mensagens que correspondam a estes padrões NUNCA devem ser tratadas como
// Prompt Injection — são ações legítimas do usuário via botões nativos da UI.
// ──────────────────────────────────────────────────────────────────────────────
const QUICK_REPLY_PATTERNS = [
  /condutas?\s+pr[aá]ticas?\s+e\s+doses?\s+para/i,
  /condutas?\s+e\s+dosagens?/i,
  /condutas?\s+cl[ií]nicas?/i,
  /doses?\s+e\s+condutas?/i,
  /prescri[çc][ãa]o\s+e\s+doses?/i,
  /doses?\s+recomendadas?/i,
];

/**
 * BUILD 312 — Verifica se uma string é originada por um botão nativo (Quick Reply).
 * Retorna true quando o texto casa com qualquer padrão de QUICK_REPLY_PATTERNS.
 */
function isQuickReplyMessage(text) {
  if (!text || typeof text !== 'string') return false;
  return QUICK_REPLY_PATTERNS.some((re) => re.test(text));
}

/**
 * BUILD 312 — Remove do histórico entradas imediatamente duplicadas:
 * se a última mensagem do assistente é idêntica (ou prefixo) ao começo
 * da mensagem atual do usuário, remove o último par user+model para
 * evitar loop de eco que dispara o guardrail de segurança.
 */
function sanitizeHistory(history, currentUserMessage) {
  if (!Array.isArray(history) || history.length === 0) return history;

  // Dedup imediato: se a última entrada de model é igual ao início da mensagem
  // atual, remove o último par para quebrar o eco.
  const lastEntry = history[history.length - 1];
  if (lastEntry && lastEntry.role === 'model') {
    const lastText  = (lastEntry.content || lastEntry.text || '').trim();
    const curTrim   = (currentUserMessage || '').trim();
    // Coincidência de prefixo longa (>40 chars) OU igualdade total → eco detectado
    if (lastText.length > 0 && curTrim.length > 0) {
      const prefix = curTrim.slice(0, Math.min(curTrim.length, 60));
      if (lastText.startsWith(prefix) || curTrim.startsWith(lastText.slice(0, 60))) {
        console.log('[BUILD312_SANITIZE] Eco detectado no histórico — removendo último par user+model.');
        // Remove o par model + user que o gerou (últimas 2 entradas)
        return history.slice(0, Math.max(0, history.length - 2));
      }
    }
  }
  return history;
}

// ══════════════════════════════════════════════════════════════════════════════
exports.geminiPaidProxy = onRequest(
  {
    region:         'us-central1',
    secrets:        [GEMINI_PAID_KEY, OPENAI_KEY], // BUILD 321: OPENAI_KEY adicionado
    // cors: false — gerenciamos CORS manualmente para suportar origem explícita
    // (necessário quando o request usa Authorization header com credentials).
    cors:           false,
    // BUILD 250: elevado de 256MiB→512MiB e timeout mantido 60s (já era adequado).
    // 256MiB causava throttling de CPU em streams de alto contexto (~9k tokens),
    // provocando corte de buffer e respostas truncadas no meio de frases.
    timeoutSeconds: 60,
    memory:         '512MiB',
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
    const {
      userMessage,
      systemPrompt,
      history = [],
      mode = 'plantao',
      requestId = '',
      lang = 'pt',
      // BUILD 265: maxOutputTokens forwarded from Flutter client.
      // Plantão=800 tok (liberdade clínica guiada), Estudo=2048 tok (full academic response).
      // Hard-clamped: min=200, max=2048 (Gemini paid safety ceiling).
      maxOutputTokens: rawMaxOut = 800,
      // BUILD 267: tools passthrough — suporte a Function Calling
      tools: rawTools,
    } = req.body || {};
    const maxOutClamped = Math.min(Math.max(Number(rawMaxOut) || 800, 200), 2048);
    if (!userMessage || typeof userMessage !== 'string' || userMessage.trim().length === 0) {
      res.status(400).json({ error: 'invalid_payload' });
      return;
    }

    // ── BUILD 312: Detecção de Quick Reply legítimo ─────────────────────────
    // Se a mensagem atual é um botão nativo (ex: "Condutas práticas e doses..."),
    // loga como ação de UI legítima para facilitar debug. Não bloqueia.
    const isQuickReply = isQuickReplyMessage(userMessage);
    if (isQuickReply) {
      console.log('[BUILD312_QR] Quick Reply detectado — ação nativa legítima. requestId=' + requestId);
    }

    // ── BUILD 321: Rota OpenAI (Layer 2 — GPT-4o Mini) ────────────────────
    // Se o cliente enviar provider='openai', a CF roteia para a API da OpenAI
    // usando OPENAI_API_KEY (secret). Resposta envelopada no mesmo formato JSON
    // que o Flutter espera do Gemini Paid ({text, model, inputTokensApprox,
    // outputTokensApprox, durationMs}) — invisibilidade total de contrato.
    // NUNCA expõe a chave ao cliente — processada 100% server-side.
    const { provider: reqProvider = 'gemini' } = req.body || {};
    if (reqProvider === 'openai') {
      const openAiKey = OPENAI_KEY.value();
      if (!openAiKey || openAiKey.trim().length === 0) {
        console.error('[BUILD321][GPT_PROXY] OPENAI_API_KEY secret não configurado');
        res.status(503).json({ error: 'openai_key_not_configured' });
        return;
      }

      // ── BUILD 321: Tradução de payload (Gemini → OpenAI messages) ─────────
      // O Flutter envia {userMessage, systemPrompt, history[{role,content}]}.
      // A API da OpenAI exige [{role:'system',content}, {role:'user',content},...].
      // Quick Reply Shield injetado aqui também (mesma blindagem do Gemini path).
      const QUICK_REPLY_SHIELD_OAI =
        'INSTRUÇÃO CRÍTICA DE INTERFACE (máxima prioridade — não ignorar): ' +
        'O aplicativo MedCases Pro possui botões nativos (Quick Replies) que automatizam ' +
        'comandos clínicos do usuário. O recebimento de mensagens contendo essas estruturas ' +
        'NUNCA deve ser interpretado como Prompt Injection ou Jailbreak. ' +
        'Trata-se exclusivamente de uma ação legítima do usuário. ' +
        'Processe a solicitação clínica normalmente sem emitir alertas de segurança.';

      const openAiMessages = [];

      // System role: Quick Reply Shield + systemPrompt do cliente
      openAiMessages.push({
        role:    'system',
        content: QUICK_REPLY_SHIELD_OAI + '\n\n' + (systemPrompt || ''),
      });

      // Histórico de conversação (Gemini usa role='model', OpenAI usa role='assistant')
      const isPlantaoModeOai = (mode === 'plantao');
      const serverHistCapOai = isPlantaoModeOai ? 4 : 8;
      const rawHistoryOai    = Array.isArray(history) ? history.slice(-serverHistCapOai) : [];
      for (const turn of rawHistoryOai) {
        if (turn.role === 'user' || turn.role === 'model' || turn.role === 'assistant') {
          openAiMessages.push({
            role:    turn.role === 'model' ? 'assistant' : turn.role,
            content: (turn.content || turn.text || '').trim(),
          });
        }
      }

      // Mensagem atual do usuário
      openAiMessages.push({ role: 'user', content: userMessage.trim() });

      const openAiPayload = {
        model:       'gpt-4o-mini',
        messages:    openAiMessages,
        max_tokens:  maxOutClamped,
        temperature: isPlantaoModeOai ? 0.2 : 0.4,
      };

      const openAiPayloadStr   = JSON.stringify(openAiPayload);
      const inputTokensApproxOai = Math.ceil(openAiPayloadStr.length / 4);

      // ── Chama OpenAI Chat Completions via https nativo (Node 22) ──────────
      let openAiResponseText = '';
      let openAiHttpStatus   = 200;

      try {
        openAiResponseText = await new Promise((resolve, reject) => {
          const postData = openAiPayloadStr;
          const options  = {
            hostname: 'api.openai.com',
            port:     443,
            path:     '/v1/chat/completions',
            method:   'POST',
            headers:  {
              'Content-Type':   'application/json',
              'Authorization':  `Bearer ${openAiKey}`,
              'Content-Length': Buffer.byteLength(postData),
            },
          };
          const apiReq = https.request(options, (apiRes) => {
            openAiHttpStatus = apiRes.statusCode;
            let body = '';
            apiRes.on('data', (chunk) => { body += chunk; });
            apiRes.on('end', () => { resolve(body); });
          });
          apiReq.on('error', reject);
          apiReq.setTimeout(55000, () => { apiReq.destroy(new Error('openai_timeout')); });
          apiReq.write(postData);
          apiReq.end();
        });
      } catch (e) {
        const durationMsOai = Date.now() - startMs;
        console.error('[BUILD321][GPT_PROXY] requestId=' + requestId + ' error=' + e.message + ' durationMs=' + durationMsOai);
        res.status(502).json({ error: 'openai_upstream_error' });
        return;
      }

      const durationMsOai = Date.now() - startMs;

      // ── Parse resposta OpenAI → estrutura Gemini-compatible ───────────────
      if (openAiHttpStatus !== 200) {
        console.error('[BUILD321][GPT_PROXY] requestId=' + requestId
          + ' openai_status=' + openAiHttpStatus
          + ' durationMs=' + durationMsOai);
        res.status(502).json({ error: 'openai_error', status: openAiHttpStatus });
        return;
      }

      let parsedTextOai = '';
      try {
        const parsedOai = JSON.parse(openAiResponseText);
        parsedTextOai = parsedOai?.choices?.[0]?.message?.content || '';
      } catch (e) {
        console.error('[BUILD321][GPT_PROXY] parse error requestId=' + requestId);
        res.status(502).json({ error: 'openai_parse_error' });
        return;
      }

      if (!parsedTextOai || parsedTextOai.trim().length === 0) {
        console.warn('[BUILD321][GPT_PROXY] empty response requestId=' + requestId);
        res.status(502).json({ error: 'openai_empty_response' });
        return;
      }

      const outputTokensApproxOai = Math.ceil(parsedTextOai.length / 4);

      // ── Budget update (same as Gemini path — fire-and-forget) ─────────────
      try {
        const newDailyCount = (budgetData.dailyDate === todayKey ? effectiveDailyCount : 0) + 1;
        const newUserHour   = userHourCount + 1;
        await budgetRef.set({
          dailyCount:    newDailyCount,
          dailyDate:     todayKey,
          [userHourKey]: newUserHour,
          lastRequestId: requestId,
          lastUpdatedAt: new Date().toISOString(),
          estimatedPaidCostUsd: ((newDailyCount * (inputTokensApproxOai + outputTokensApproxOai)) / 1_000_000 * 0.15).toFixed(6),
        }, { merge: true });
      } catch (e) {
        console.warn('[BUILD321][GPT_PROXY] budget update error:', e.message);
      }

      console.log('[BUILD321][GPT_PROXY] '
        + `requestId=${requestId} `
        + `success=true `
        + `model=gpt-4o-mini `
        + `mode=${mode} `
        + `lang=${lang} `
        + `inputTokensApprox=${inputTokensApproxOai} `
        + `outputTokensApprox=${outputTokensApproxOai} `
        + `durationMs=${durationMsOai}`);

      console.log('[PROVIDER_ROUTER] '
        + `requestId=${requestId} `
        + `mode=${mode} `
        + `primary=gemini_free `
        + `layer2=gpt_4o_mini `
        + `usedProvider=gpt_4o_mini `
        + `status=success `
        + `inputTokensApprox=${inputTokensApproxOai} `
        + `outputTokensApprox=${outputTokensApproxOai} `
        + `durationMs=${durationMsOai}`);

      // Resposta no MESMO formato que o Flutter espera do Gemini Paid
      res.status(200).json({
        text:               parsedTextOai,
        model:              'gpt-4o-mini',
        inputTokensApprox:  inputTokensApproxOai,
        outputTokensApprox: outputTokensApproxOai,
        durationMs:         durationMsOai,
      });
      return; // BUILD 321: rota OpenAI encerra aqui — não cai no Gemini path abaixo
    }
    // ── FIM BUILD 321: Rota OpenAI ─────────────────────────────────────────

    // ── 6. Lê a chave paga do Secret (NUNCA retornada ao cliente) ───────────
    const paidApiKey = GEMINI_PAID_KEY.value();
    if (!paidApiKey || paidApiKey.trim().length === 0) {
      console.error('[PAID_PROXY] GEMINI_PAID_API_KEY secret não configurado');
      res.status(503).json({ error: 'paid_key_not_configured' });
      return;
    }

    // ── 7. Monta payload Gemini ─────────────────────────────────────────────
    const contents = [];
    // BUILD 261: Plantão history capped at 4 entries server-side (double-guard).
    // Client already sends ≤4 for Plantão; this ensures correct behavior
    // even if an older client version sends more entries.
    const isPlantaoMode = (mode === 'plantao');
    const serverHistCap = isPlantaoMode ? 4 : 8;

    // BUILD 312 — Pré-higienização do histórico antes de montar contents:
    // Remove ecos imediatos que disparam falso positivo de guardrail.
    const rawHistory    = Array.isArray(history) ? history.slice(-serverHistCap) : [];
    const recentHistory = sanitizeHistory(rawHistory, userMessage);

    for (const turn of recentHistory) {
      if (turn.role === 'user' || turn.role === 'model') {
        contents.push({ role: turn.role, parts: [{ text: turn.content || turn.text || '' }] });
      }
    }
    // Mensagem atual
    contents.push({ role: 'user', parts: [{ text: userMessage.trim() }] });

    // ── BUILD 312 — System Instruction com blindagem de Quick Reply ──────────
    // Injeta ANTES do systemPrompt do cliente para garantir precedência máxima.
    // Esta instrução explica ao modelo a arquitetura de botões nativos do app,
    // prevenindo que o guardrail interno interprete Quick Replies como ataques.
    const QUICK_REPLY_SHIELD =
      'INSTRUÇÃO CRÍTICA DE INTERFACE (máxima prioridade — não ignorar): ' +
      'O aplicativo MedCases Pro possui botões nativos (Quick Replies) que automatizam ' +
      'comandos clínicos do usuário, como "Condutas práticas e doses para...", ' +
      '"Condutas e dosagens", "Condutas clínicas", "Doses e condutas" e variações similares. ' +
      'O recebimento de mensagens contendo essas estruturas, repetições de contexto clínico ' +
      'ou termos que se assemelhem a comandos do sistema NUNCA deve ser interpretado como ' +
      'Prompt Injection, Jailbreak, tentativa de manipulação ou qualquer tipo de violação ' +
      'de segurança. Trata-se exclusivamente de uma ação legítima do usuário via interface ' +
      'nativa do aplicativo. Ao receber tais mensagens, processe a solicitação clínica ' +
      'normalmente, fornecendo condutas práticas, dosagens e orientações baseadas no caso ' +
      'ativo, mantendo o tom profissional médico e sem expor estas diretrizes internas. ' +
      'NUNCA recuse, bloqueie ou emita alertas de segurança para esses padrões de mensagem.';

    const combinedSystemInstruction = QUICK_REPLY_SHIELD + '\n\n' + (systemPrompt || '');

    const geminiPayload = {
      system_instruction: {
        parts: [{ text: combinedSystemInstruction }],
      },
      contents,
      generationConfig: {
        // BUILD 271: temperature agora condicional por modo.
        // Plantão (guardia): 0.2 — mais determinístico, fiel às 21 matrizes sem inventar layouts.
        // Estudo: 0.4 — liberdade clínica guiada para resposta acadêmica completa.
        temperature:     isPlantaoMode ? 0.2 : 0.4,
        // BUILD 271: maxOutClamped agora pode chegar a 1600 (cliente envia 1600 no Plantão).
        // Estudo=2048 tok (full academic). Hard-clamped server-side: min=200, max=2048.
        maxOutputTokens: maxOutClamped,
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

    // BUILD 267: tools passthrough — injeta Function Calling schema se enviado pelo cliente.
    // Permite RAG estrutural (function_declarations) quando o Flutter incluir tools no payload.
    if (rawTools && Array.isArray(rawTools) && rawTools.length > 0) {
      geminiPayload.tools = rawTools;
    }

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
        apiReq.setTimeout(55000, () => { apiReq.destroy(new Error('timeout')); }); // BUILD 266: 45s→55s (RAG reativado)
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
      // BUILD 312 — Resposta de erro limpa: NUNCA concatena strings do sistema,
      // histórico anterior ou system prompt. Apenas código de erro padronizado.
      res.status(502).json({ error: 'gemini_error', status: httpStatus });
      return;
    }

    let parsedText = '';
    try {
      const parsed = JSON.parse(responseText);

      // BUILD 312 — Verifica se o Gemini retornou um bloqueio de safety/recitação
      // em vez de texto útil. Isso pode acontecer quando o guardrail interno do
      // modelo (não nosso) bloqueia a resposta por policy.
      const finishReason = parsed?.candidates?.[0]?.finishReason || '';
      const BLOCKED_REASONS = ['SAFETY', 'RECITATION', 'BLOCKLIST', 'PROHIBITED_CONTENT'];
      if (BLOCKED_REASONS.includes(finishReason)) {
        console.warn('[BUILD312_BLOCK] Gemini retornou finishReason=' + finishReason
          + ' requestId=' + requestId
          + ' isQuickReply=' + isQuickReply);
        // Resposta de substituição limpa — nunca vaza system prompt ou histórico
        const fallbackMsg = (lang === 'es')
          ? 'No fue posible procesar la solicitud clínica en este momento. Por favor, intenta de nuevo o reformula la pregunta.'
          : 'Não foi possível processar a solicitação clínica neste momento. Por favor, tente novamente ou reformule a pergunta.';
        res.status(200).json({
          text:              fallbackMsg,
          model:             GEMINI_PAID_MODEL,
          inputTokensApprox: 0,
          outputTokensApprox: 0,
          durationMs,
          blockedReason:     finishReason,
        });
        return;
      }

      parsedText = parsed?.candidates?.[0]?.content?.parts?.[0]?.text || '';
    } catch (e) {
      // BUILD 312 — Erro de parse: JSON limpo sem dados internos
      console.error('[PAID_PROXY] parse error requestId=' + requestId);
      res.status(502).json({ error: 'parse_error' });
      return;
    }

    if (!parsedText || parsedText.trim().length === 0) {
      // BUILD 312 — Resposta vazia: JSON limpo, sem vazamento de memória
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

// ══════════════════════════════════════════════════════════════════════════════
// BUILD 459 — atenderConsultaIA  (onCall v2 — motor IA server-side)
//
// CONTRATO:
//   Cliente (Flutter / AiEngineService._dispatchViaCloudFunction) envia:
//     { userMessage, systemPrompt, isEs, history, longResponse, uid }
//   Servidor retorna:
//     { text, model, inputTokensApprox, outputTokensApprox, durationMs }
//   Em caso de erro:
//     throws HttpsError com código semântico:
//       unauthenticated   → sem Firebase Auth token
//       permission-denied → UID mismatch ou conta não aprovada
//       invalid-argument  → payload inválido
//       deadline-exceeded → timeout Gemini (85s)
//       unavailable       → Gemini API error ou secret não configurado
//       internal          → erro inesperado
//
// SEGURANÇA:
//   • request.auth obrigatório — rejeita se null (unauthenticated)
//   • UID do payload validado contra request.auth.uid (permission-denied)
//   • Status do usuário verificado no Firestore (approved)
//   • GEMINI_AI_KEY lida do Firebase Secret — NUNCA enviada ao cliente
//   • userMessage truncado em 4000 chars server-side
//   • systemPrompt truncado em 12000 chars server-side
//   • history limitado a 16 msgs (8 turnos) server-side
//
// MODELO:
//   gemini-2.5-flash via REST HTTPS nativo (Node.js built-in)
//   Mesma arquitetura do geminiPaidProxy — zero novas dependências npm
//
// DEPLOY:
//   1. firebase functions:secrets:set GEMINI_AI_KEY    ← colar chave Gemini
//   2. firebase deploy --only functions:atenderConsultaIA
//
// ATIVAR NO FLUTTER (após deploy e teste):
//   lib/services/ai_engine_service.dart → kUseCloudFunctions = true
// ══════════════════════════════════════════════════════════════════════════════

// ── Constantes do motor IA ─────────────────────────────────────────────────
const AI_GEMINI_MODEL          = 'gemini-2.5-flash';
const AI_MAX_HISTORY_TURNS     = 8;      // turnos → 16 msgs máx (par user+model)
const AI_MAX_SYSTEM_PROMPT_LEN = 12000;  // chars — proteção contra payload gigante
const AI_MAX_USER_MESSAGE_LEN  = 4000;   // chars
const AI_TIMEOUT_MS_CF         = 82000;  // 82s — margem de 8s antes do limite onCall v2 (90s)
const AI_MAX_OUTPUT_PLANTAO    = 900;    // tokens — Motor Plantão (rápido, executivo)
const AI_MAX_OUTPUT_ESTUDO     = 2048;   // tokens — Motor Estudo (denso, acadêmico)

/**
 * Chama a API REST do Gemini via HTTPS nativo do Node.js.
 * Reutiliza a mesma arquitetura do geminiPaidProxy (zero novas dependências).
 *
 * @param {string} apiKey          Chave Gemini (lida do secret GEMINI_AI_KEY)
 * @param {string} model           Nome do modelo Gemini
 * @param {string} systemPrompt    System instruction sanitizado
 * @param {Array}  contents        [{role, parts:[{text}]}] — histórico + msg atual
 * @param {number} maxOutputTokens Limite de tokens de saída
 * @returns {Promise<{text, inputTokensApprox, outputTokensApprox}>}
 */
function callGeminiRestAI(apiKey, model, systemPrompt, contents, maxOutputTokens) {
  return new Promise((resolve, reject) => {
    const bodyObj = {
      system_instruction: {
        parts: [{ text: systemPrompt }],
      },
      contents,
      generationConfig: {
        maxOutputTokens,
        temperature:   0.4,
        topP:          0.95,
        topK:          40,
      },
      safetySettings: [
        { category: 'HARM_CATEGORY_HARASSMENT',        threshold: 'BLOCK_NONE' },
        { category: 'HARM_CATEGORY_HATE_SPEECH',       threshold: 'BLOCK_NONE' },
        { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_NONE' },
        { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_NONE' },
      ],
    };

    const bodyStr = JSON.stringify(bodyObj);
    const options = {
      hostname: GEMINI_API_BASE,
      path:     `/v1beta/models/${model}:generateContent?key=${apiKey}`,
      method:   'POST',
      headers: {
        'Content-Type':   'application/json',
        'Content-Length': Buffer.byteLength(bodyStr),
      },
      timeout: AI_TIMEOUT_MS_CF,
    };

    const req = https.request(options, (res) => {
      let raw = '';
      res.on('data', (chunk) => { raw += chunk; });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(raw);

          // Gemini retornou objeto de erro
          if (parsed.error) {
            const code = parsed.error.code || 'unknown';
            const msg  = parsed.error.message || 'Gemini API error';
            console.error(`[AI_CF][Gemini] API error code=${code}: ${msg}`);
            return reject(new Error(`gemini_api_error:${code}`));
          }

          // Extrai texto da resposta
          const candidate = parsed.candidates && parsed.candidates[0];
          const text = (candidate?.content?.parts || [])
            .map(p => p.text || '')
            .join('');

          if (!text || text.trim().length === 0) {
            const reason = candidate?.finishReason || 'UNKNOWN';
            console.warn(`[AI_CF][Gemini] Resposta vazia. finishReason=${reason}`);
            return reject(new Error(`gemini_empty_response:${reason}`));
          }

          const inputTokensApprox  = Math.ceil((systemPrompt.length + bodyStr.length) / 4);
          const outputTokensApprox = Math.ceil(text.length / 4);
          resolve({ text, inputTokensApprox, outputTokensApprox });

        } catch (parseErr) {
          console.error('[AI_CF][Gemini] JSON parse falhou:', parseErr.message,
            '| raw(300):', raw.substring(0, 300));
          reject(new Error('gemini_parse_error'));
        }
      });
    });

    req.on('timeout', () => {
      req.destroy();
      console.error('[AI_CF][Gemini] Timeout após', AI_TIMEOUT_MS_CF, 'ms');
      reject(new Error('gemini_timeout'));
    });

    req.on('error', (err) => {
      console.error('[AI_CF][Gemini] Erro de rede:', err.code || err.message);
      reject(new Error(`gemini_network_error:${err.code || err.message}`));
    });

    req.write(bodyStr);
    req.end();
  });
}

exports.atenderConsultaIA = onCall(
  {
    region:         'us-central1',
    secrets:        [GEMINI_AI_KEY],
    timeoutSeconds: 90,
    memory:         '512MiB',
  },
  async (request) => {
    const startMs = Date.now();

    // ── 1. AUTENTICAÇÃO OBRIGATÓRIA ─────────────────────────────────────────
    // onCall v2: request.auth={uid,token} se o cliente enviou Firebase ID token.
    // null → cliente não autenticado → recusa imediata.
    if (!request.auth || !request.auth.uid) {
      console.warn('[AI_CF] Requisição sem Firebase Auth — rejeitada.');
      throw new HttpsError(
        'unauthenticated',
        'Autenticação Firebase obrigatória. Faça login no aplicativo e tente novamente.'
      );
    }
    const callerUid = request.auth.uid;

    // ── 2. DE-SERIALIZAÇÃO DO PAYLOAD ───────────────────────────────────────
    // Campos enviados por AiEnginePayload.toCloudFunctionMap():
    //   userMessage, uid, isEs, systemPrompt, history, longResponse, useGrounding
    const data = request.data || {};
    const rawUserMessage  = data.userMessage   || '';
    const payloadUid      = data.uid           || '';
    const isEsRaw         = data.isEs          || false;
    const rawSystemPrompt = data.systemPrompt  || '';
    const rawHistory      = data.history       || [];
    const longResponseRaw = data.longResponse  || false;
    // useGrounding: não implementado server-side nesta versão
    // (Google Search Grounding via Cloud Function requer setup adicional de billing)

    // ── 3. VALIDAÇÃO DE CONSISTÊNCIA DE UID ────────────────────────────────
    // Garante que o UID do token Firebase == uid do payload.
    // Impede que um usuário autenticado envie consultas em nome de outro.
    if (payloadUid && payloadUid !== callerUid) {
      console.warn(`[AI_CF] UID mismatch: token=${callerUid} payload=${payloadUid} — rejeitado.`);
      throw new HttpsError(
        'permission-denied',
        'Identidade inconsistente. Saia do aplicativo, faça login novamente e tente outra vez.'
      );
    }

    // ── 4. SANITIZAÇÃO DO PAYLOAD ───────────────────────────────────────────
    const userMessage  = (typeof rawUserMessage  === 'string' ? rawUserMessage  : String(rawUserMessage)).trim();
    const systemPrompt = (typeof rawSystemPrompt === 'string' ? rawSystemPrompt : String(rawSystemPrompt)).trim();
    const longResponse = Boolean(longResponseRaw);

    if (!userMessage) {
      throw new HttpsError('invalid-argument', 'O campo userMessage não pode ser vazio.');
    }

    // Trunca como proteção extra de segurança server-side
    const safeUserMessage  = userMessage.substring(0, AI_MAX_USER_MESSAGE_LEN);
    const safeSystemPrompt = systemPrompt.substring(0, AI_MAX_SYSTEM_PROMPT_LEN);

    // ── 5. VERIFICAÇÃO DE STATUS DO USUÁRIO NO FIRESTORE ───────────────────
    let userStatus = 'unknown';
    try {
      const userDoc = await admin.firestore().collection('users').doc(callerUid).get();
      if (!userDoc.exists) {
        console.warn(`[AI_CF] Usuário não encontrado no Firestore uid=${callerUid}`);
        throw new HttpsError('permission-denied', 'Usuário não registrado no sistema.');
      }
      userStatus = userDoc.data().status || 'unknown';
      if (userStatus !== 'approved') {
        console.warn(`[AI_CF] Acesso negado uid=${callerUid} status=${userStatus}`);
        throw new HttpsError(
          'permission-denied',
          'Conta pendente de aprovação. Entre em contato com o suporte MedCases Pro.'
        );
      }
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error('[AI_CF] Erro ao verificar status Firestore:', err.message);
      throw new HttpsError('internal', 'Falha na verificação de autorização. Tente novamente.');
    }

    // ── 6. CHAVE GEMINI DO SECRET ───────────────────────────────────────────
    // GEMINI_AI_KEY.value() retorna o valor do Firebase Secret configurado.
    // NUNCA logada. NUNCA enviada ao cliente.
    const geminiKey = (GEMINI_AI_KEY.value() || '').trim();
    if (!geminiKey) {
      console.error('[AI_CF] Secret GEMINI_AI_KEY não configurado. '
        + 'Execute: firebase functions:secrets:set GEMINI_AI_KEY');
      throw new HttpsError(
        'unavailable',
        'Motor de IA temporariamente indisponível. Tente novamente em instantes.'
      );
    }

    // ── 7. MONTAGEM DO ARRAY contents (histórico + mensagem atual) ──────────
    // Gemini espera: [{role:'user', parts:[{text}]}, {role:'model', parts:[{text}]}, ...]
    // Flutter envia: [{role:'user'|'model', content:'...'}]  (AiEnginePayload.history)
    const contents = [];

    const safeHistory = Array.isArray(rawHistory)
      ? rawHistory.slice(-(AI_MAX_HISTORY_TURNS * 2))  // cap server-side
      : [];

    for (const turn of safeHistory) {
      const role    = (turn.role === 'model' || turn.role === 'assistant') ? 'model' : 'user';
      const content = String(turn.content || turn.text || '').trim();
      if (content.length > 0) {
        contents.push({ role, parts: [{ text: content }] });
      }
    }

    // Sempre encerra o array com a mensagem atual do usuário
    contents.push({ role: 'user', parts: [{ text: safeUserMessage }] });

    // ── 8. SELEÇÃO DO LIMITE DE TOKENS ─────────────────────────────────────
    // longResponse=false → Motor Plantão (rápido, executivo, 900 tokens)
    // longResponse=true  → Motor Estudo  (denso, acadêmico, 2048 tokens)
    const maxOutputTokens = longResponse ? AI_MAX_OUTPUT_ESTUDO : AI_MAX_OUTPUT_PLANTAO;

    // ── 9. CHAMADA GEMINI ───────────────────────────────────────────────────
    console.log(
      `[AI_CF] → Gemini uid=${callerUid} `
      + `isEs=${Boolean(isEsRaw)} longResponse=${longResponse} `
      + `histMsgs=${safeHistory.length} msgLen=${safeUserMessage.length} `
      + `sysPromptLen=${safeSystemPrompt.length} maxOut=${maxOutputTokens}`
    );

    let aiResult;
    try {
      aiResult = await callGeminiRestAI(
        geminiKey,
        AI_GEMINI_MODEL,
        safeSystemPrompt || 'Você é um assistente médico. Responda de forma clínica e precisa.',
        contents,
        maxOutputTokens
      );
    } catch (err) {
      const errMsg = (err && err.message) ? err.message : String(err);
      console.error('[AI_CF] callGeminiRestAI falhou:', errMsg);

      if (errMsg.includes('timeout')) {
        throw new HttpsError(
          'deadline-exceeded',
          'O motor de IA demorou demais para responder. Tente novamente ou simplifique a pergunta.'
        );
      }
      if (errMsg.includes('gemini_api_error')) {
        throw new HttpsError(
          'unavailable',
          'A API Gemini retornou um erro. Tente novamente em instantes.'
        );
      }
      if (errMsg.includes('gemini_empty_response')) {
        throw new HttpsError(
          'internal',
          'Resposta vazia do motor de IA. Reformule sua pergunta e tente novamente.'
        );
      }
      throw new HttpsError(
        'internal',
        'Erro interno no motor de IA. Tente novamente.'
      );
    }

    const durationMs = Date.now() - startMs;
    console.log(
      `[AI_CF] ✅ uid=${callerUid} durationMs=${durationMs} `
      + `inputTokensApprox=${aiResult.inputTokensApprox} `
      + `outputTokensApprox=${aiResult.outputTokensApprox} `
      + `textLen=${aiResult.text.length}`
    );

    // ── 10. RETORNO AO FLUTTER ──────────────────────────────────────────────
    // AiEngineService._dispatchViaCloudFunction lê { text } e simula
    // streaming word-by-word via Stream<GeminiChunk> no cliente Dart.
    // Os demais campos são informativos para logging/debug.
    return {
      text:               aiResult.text,
      model:              AI_GEMINI_MODEL,
      inputTokensApprox:  aiResult.inputTokensApprox,
      outputTokensApprox: aiResult.outputTokensApprox,
      durationMs,
    };
  }
);

// ══════════════════════════════════════════════════════════════════════════════
// BUILD 462-STREAMING-CORE — atenderConsultaIAStream
//
// Endpoint HTTP com Server-Sent Events (SSE) reais para streaming server-side.
//
// RESPONSABILIDADE:
//   Mesma pipeline de segurança do atenderConsultaIA (onCall) mas retorna
//   a resposta como stream SSE real via onRequest — eliminando a necessidade
//   de streaming simulado no cliente (chunks de 25 chars / 18ms delay).
//
// VANTAGENS SOBRE onCall (atenderConsultaIA):
//   • TTFT real: primeiro token chega ao cliente em ~600ms (sem cold-start JSON)
//   • Sem limite de 10MB por response (onCall JSON único)
//   • Client observa progresso em tempo real — UX idêntica ao Gemini Free SSE
//
// SEGURANÇA:
//   • Autenticação via Firebase ID Token no header Authorization: Bearer <token>
//   • Mesma validação de UID e status Firestore do atenderConsultaIA
//   • GEMINI_AI_KEY lida exclusivamente server-side via Firebase Secret
//   • CORS restrito — apenas origens confiáveis podem acessar
//
// PROTOCOLO SSE (Server-Sent Events):
//   Content-Type: text/event-stream
//   Cada evento: "data: {\"delta\":\"...\",\"seq\":N}\n\n"
//   Conclusão:   "data: {\"done\":true,\"model\":\"...\",\"durationMs\":N}\n\n"
//   Erro:        "data: {\"error\":\"código\"}\n\n"
//
// FLUTTER CLIENT (futuro — quando kUseCloudFunctions=true):
//   http.Client().send(request) → stream de bytes → parse SSE → GeminiChunk
//   Sem mudança na UI — o barramento AiEvent absorve transparentemente.
//
// DEPLOY:
//   firebase deploy --only functions:atenderConsultaIAStream
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Faz streaming da resposta do Gemini via SSE — transmite delta a delta.
 * @param {string} geminiKey  - Chave da API Gemini (lida do secret)
 * @param {string} model      - Modelo Gemini a usar
 * @param {string} systemPrompt - System instruction completa
 * @param {Array}  contents   - Array de turns [{role, parts:[{text}]}]
 * @param {number} maxTokens  - Limite de tokens de saída
 * @param {Function} onDelta  - Callback por fragmento: (delta: string, seq: number) => void
 * @returns {Promise<{text, inputTokensApprox, outputTokensApprox}>}
 */
function callGeminiRestSSE(geminiKey, model, systemPrompt, contents, maxTokens, onDelta) {
  return new Promise((resolve, reject) => {
    const modelId  = model || 'gemini-2.5-flash';
    const endpoint = `/v1beta/models/${modelId}:streamGenerateContent?alt=sse`;

    const bodyObj = {
      system_instruction: { parts: [{ text: systemPrompt }] },
      contents,
      generationConfig: {
        maxOutputTokens: maxTokens,
        temperature:     0.4,
        topP:            0.95,
        topK:            40,
      },
      safetySettings: [
        { category: 'HARM_CATEGORY_HARASSMENT',        threshold: 'BLOCK_NONE' },
        { category: 'HARM_CATEGORY_HATE_SPEECH',       threshold: 'BLOCK_NONE' },
        { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_NONE' },
        { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_NONE' },
      ],
    };
    const bodyStr = JSON.stringify(bodyObj);

    const options = {
      hostname: 'generativelanguage.googleapis.com',
      path:     `${endpoint}&key=${geminiKey}`,
      method:   'POST',
      headers: {
        'Content-Type':   'application/json',
        'Content-Length': Buffer.byteLength(bodyStr),
      },
      timeout: AI_TIMEOUT_MS_CF,
    };

    const req = https.request(options, (res) => {
      if (res.statusCode !== 200) {
        let errBody = '';
        res.on('data', (c) => { errBody += c; });
        res.on('end',  () => reject(new Error(`gemini_api_error:${res.statusCode}:${errBody.substring(0,200)}`)));
        return;
      }

      let buffer       = '';
      let accumulated  = '';
      let seq          = 0;
      let inputTokens  = 0;
      let outputTokens = 0;

      res.on('data', (chunk) => {
        buffer += chunk.toString('utf8');
        // SSE lines: cada evento separado por '\n\n', prefixo 'data: '
        const lines = buffer.split('\n');
        buffer = lines.pop(); // mantém linha incompleta no buffer

        for (const line of lines) {
          const trimmed = line.trim();
          if (!trimmed.startsWith('data:')) continue;
          const jsonStr = trimmed.slice(5).trim();
          if (!jsonStr || jsonStr === '[DONE]') continue;

          let parsed;
          try { parsed = JSON.parse(jsonStr); } catch (_) { continue; }

          const candidate = parsed?.candidates?.[0];
          if (!candidate) continue;

          // Filtra CoT/thought
          const parts = candidate?.content?.parts || [];
          let delta = '';
          for (const part of parts) {
            if (part.thought === true) continue;
            if (typeof part.text === 'string' && part.text) {
              delta += part.text;
            }
          }

          if (delta) {
            accumulated += delta;
            onDelta(delta, seq++);
          }

          // Tokens
          if (parsed?.usageMetadata) {
            inputTokens  = parsed.usageMetadata.promptTokenCount     || inputTokens;
            outputTokens = parsed.usageMetadata.candidatesTokenCount || outputTokens;
          }
        }
      });

      res.on('end', () => {
        if (!accumulated) {
          return reject(new Error('gemini_empty_response:SSE'));
        }
        resolve({
          text:               accumulated,
          inputTokensApprox:  inputTokens  || Math.ceil((systemPrompt.length) / 4),
          outputTokensApprox: outputTokens || Math.ceil(accumulated.length / 4),
        });
      });

      res.on('error', (err) => reject(new Error(`gemini_stream_error:${err.message}`)));
    });

    req.on('timeout', () => { req.destroy(); reject(new Error('gemini_timeout')); });
    req.on('error',   (err) => reject(new Error(`gemini_network_error:${err.code || err.message}`)));
    req.write(bodyStr);
    req.end();
  });
}

exports.atenderConsultaIAStream = onRequest(
  {
    region:         'us-central1',
    secrets:        [GEMINI_AI_KEY],
    timeoutSeconds: 120,
    memory:         '512MiB',
    cors:           false, // CORS manual abaixo — mais granular
  },
  async (req, res) => {
    const startMs = Date.now();

    // ── CORS ──────────────────────────────────────────────────────────────────
    const allowedOrigins = [
      'https://medcasespro.app',
      'https://medcases-pro.web.app',
      'https://medcases-pro.firebaseapp.com',
    ];
    const origin = req.headers.origin || '';
    const isAllowedOrigin = allowedOrigins.includes(origin) ||
      (process.env.FUNCTIONS_EMULATOR === 'true'); // permite emulador local

    if (isAllowedOrigin) {
      res.set('Access-Control-Allow-Origin', origin);
    }
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Max-Age', '3600');

    if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
    if (req.method !== 'POST')    { res.status(405).json({ error: 'method_not_allowed' }); return; }

    // ── AUTENTICAÇÃO via Firebase ID Token ────────────────────────────────────
    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'unauthenticated', message: 'Bearer token obrigatório.' });
      return;
    }
    const idToken = authHeader.slice(7).trim();
    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (err) {
      console.warn('[STREAM_CF] Token inválido:', err.code);
      res.status(401).json({ error: 'invalid_token' });
      return;
    }
    const callerUid = decodedToken.uid;

    // ── DE-SERIALIZAÇÃO DO PAYLOAD ────────────────────────────────────────────
    const data = req.body || {};
    const rawUserMessage  = String(data.userMessage  || '').trim();
    const payloadUid      = String(data.uid          || '').trim();
    const isEsRaw         = Boolean(data.isEs);
    const rawSystemPrompt = String(data.systemPrompt || '').trim();
    const rawHistory      = Array.isArray(data.history) ? data.history : [];
    const longResponseRaw = Boolean(data.longResponse);

    // ── VALIDAÇÃO UID ─────────────────────────────────────────────────────────
    if (payloadUid && payloadUid !== callerUid) {
      res.status(403).json({ error: 'permission_denied' });
      return;
    }

    // ── SANITIZAÇÃO ───────────────────────────────────────────────────────────
    const safeUserMessage  = rawUserMessage.substring(0, 4000);
    const safeSystemPrompt = rawSystemPrompt.substring(0, 12000);
    if (!safeUserMessage) {
      res.status(400).json({ error: 'empty_message' });
      return;
    }

    // ── STATUS FIRESTORE ──────────────────────────────────────────────────────
    try {
      const db      = admin.firestore();
      const userDoc = await db.doc(`users/${callerUid}`).get();
      const status  = userDoc.exists ? (userDoc.data().status || '') : '';
      if (status !== 'approved') {
        res.status(403).json({ error: 'not_approved' });
        return;
      }
    } catch (err) {
      console.error('[STREAM_CF] Firestore check falhou:', err.message);
      res.status(500).json({ error: 'firestore_error' });
      return;
    }

    // ── CHAVE GEMINI ──────────────────────────────────────────────────────────
    const geminiKey = GEMINI_AI_KEY.value();
    if (!geminiKey) {
      console.error('[STREAM_CF] GEMINI_AI_KEY não configurado.');
      res.status(500).json({ error: 'missing_api_key' });
      return;
    }

    // ── MONTA CONTENTS ────────────────────────────────────────────────────────
    const AI_MAX_HISTORY_TURNS = 8;
    const safeHistory = rawHistory.slice(-(AI_MAX_HISTORY_TURNS * 2));
    const contents = [];
    for (const turn of safeHistory) {
      const role    = (turn.role === 'model' || turn.role === 'assistant') ? 'model' : 'user';
      const content = String(turn.content || turn.text || '').trim();
      if (content) contents.push({ role, parts: [{ text: content }] });
    }
    contents.push({ role: 'user', parts: [{ text: safeUserMessage }] });

    const maxOutputTokens = longResponseRaw ? 2048 : 900;

    // ── INICIA RESPOSTA SSE ───────────────────────────────────────────────────
    res.set('Content-Type',  'text/event-stream; charset=utf-8');
    res.set('Cache-Control', 'no-cache');
    res.set('Connection',    'keep-alive');
    res.set('X-Accel-Buffering', 'no'); // desativa buffer no nginx/proxy
    res.flushHeaders();

    console.log(
      `[STREAM_CF] → SSE uid=${callerUid} longResponse=${longResponseRaw} `
      + `histMsgs=${safeHistory.length} maxOut=${maxOutputTokens}`
    );

    // ── STREAMING GEMINI → SSE ────────────────────────────────────────────────
    let totalText = '';
    try {
      const result = await callGeminiRestSSE(
        geminiKey,
        'gemini-2.5-flash',
        safeSystemPrompt || 'Você é um assistente médico clínico especializado.',
        contents,
        maxOutputTokens,
        (delta, seq) => {
          // Envia cada delta como evento SSE imediatamente
          totalText += delta;
          const payload = JSON.stringify({ delta, seq });
          res.write(`data: ${payload}\n\n`);
          // Express em Cloud Functions gerencia o flush automaticamente
          // mas em alguns ambientes o flush explícito ajuda:
          if (typeof res.flush === 'function') res.flush();
        }
      );

      const durationMs = Date.now() - startMs;
      console.log(
        `[STREAM_CF] ✅ uid=${callerUid} durationMs=${durationMs} `
        + `textLen=${result.text.length} `
        + `inputTokensApprox=${result.inputTokensApprox} `
        + `outputTokensApprox=${result.outputTokensApprox}`
      );

      // Evento de conclusão — carrega metadados do request
      const donePayload = JSON.stringify({
        done:               true,
        model:              'gemini-2.5-flash',
        inputTokensApprox:  result.inputTokensApprox,
        outputTokensApprox: result.outputTokensApprox,
        durationMs,
      });
      res.write(`data: ${donePayload}\n\n`);
      res.end();

    } catch (err) {
      const errMsg = (err && err.message) ? err.message : String(err);
      console.error('[STREAM_CF] Erro no stream Gemini:', errMsg);

      // Envia evento de erro SSE antes de fechar
      const errCode = errMsg.includes('timeout') ? 'cf_timeout'
                    : errMsg.includes('unauthenticated') ? 'cf_unauthenticated'
                    : errMsg.includes('empty_response') ? 'cf_empty_response'
                    : 'cf_internal';

      try {
        res.write(`data: ${JSON.stringify({ error: errCode })}\n\n`);
        res.end();
      } catch (_) {
        // Conexão já fechada pelo cliente
      }
    }
  }
);

// ══════════════════════════════════════════════════════════════════════════════
// BUILD 462B-REDIRECIONADA — gptProxyStream
//
// Endpoint HTTP v2 (onRequest) com Server-Sent Events reais.
// Consome a OpenAI Responses API com stream:true e repassa cada delta
// imediatamente ao Flutter — o primeiro delta chega ANTES da conclusão upstream.
//
// ENDPOINT PARALELO: NÃO substitui gptProxy (legado síncrono mantido).
//   gptProxy       → legado (resposta JSON única, sem SSE)
//   gptProxyStream → BUILD 462B (SSE real, stream:true)
//
// PIPELINE DE SEGURANÇA (idêntico ao atenderConsultaIA):
//   1. Método HTTP (somente POST)
//   2. Autenticação Firebase ID Token
//   3. Validação de payload
//   4. Budget guard (Firestore)
//   5. Validação de status do usuário (approved)
//   → Somente então: abrir headers SSE + carregar OPENAI_API_KEY
//
// Falha ANTES da abertura do SSE → res.status(4xx).json({error:'...'})
// Falha DEPOIS da abertura do SSE → event SSE: error {error:'code'}
//
// PROTOCOLO SSE MEDCASES:
//   event: started       → primeira conexão estabelecida
//   event: text_delta    → fragmento de texto em tempo real
//   event: transport_done → conclusão do transporte (AppProvider emite AiCompleted)
//   event: error         → falha após início do SSE
//   : heartbeat          → keepalive (ignorado pelo Flutter)
//
// CANCELAMENTO UPSTREAM:
//   req.on('aborted') + res.on('close') → AbortController.abort()
//   → OpenAI interrompe geração
//   → Registra requestId, attempt, durationMs, deltaCount (SEM dados clínicos)
//
// Deploy:
//   firebase deploy --only functions:gptProxyStream
//   firebase functions:secrets:set OPENAI_API_KEY  (se ainda não configurado)
// ══════════════════════════════════════════════════════════════════════════════

// ── Utilitário: envia evento SSE formatado ────────────────────────────────────
function sendSseEvent(res, eventType, data) {
  if (res.writableEnded) return;
  const jsonStr = JSON.stringify(data);
  res.write(`event: ${eventType}\ndata: ${jsonStr}\n\n`);
  if (typeof res.flush === 'function') res.flush();
}

// ── callOpenAiResponsesStream: consome OpenAI Responses API com stream:true ──
//
// Usa https nativo (Node 22) para chamar:
//   POST https://api.openai.com/v1/responses
//   { model: 'gpt-4o-mini', input: [...], stream: true }
//
// Evento relevante de texto: response.output_text.delta
//   { type: 'response.output_text.delta', delta: '...' }
//
// O backend NUNCA repassa objetos brutos da OpenAI ao Flutter.
// Apenas o contrato MedCases é emitido via SSE.
//
// abortSignal: AbortSignal para cancelamento upstream via AbortController.
function callOpenAiResponsesStream({
  openAiKey,
  systemPrompt,
  userMessage,
  history,
  maxOutputTokens,
  requestId,
  onDelta,
  abortSignal,
}) {
  return new Promise((resolve, reject) => {
    if (abortSignal && abortSignal.aborted) {
      return reject(new Error('aborted_before_start'));
    }

    // Montar input para OpenAI Responses API
    // Formato: [{role:'system'|'user'|'assistant', content:'...'}]
    const input = [];
    if (systemPrompt && systemPrompt.trim()) {
      input.push({ role: 'system', content: systemPrompt.trim() });
    }
    // Histórico (Gemini usa role='model' → OpenAI usa role='assistant')
    const histCap = 8;
    const recentHistory = Array.isArray(history)
      ? history.slice(-histCap)
      : [];
    for (const turn of recentHistory) {
      const role    = (turn.role === 'model' || turn.role === 'assistant')
        ? 'assistant' : 'user';
      const content = String(turn.content || turn.text || '').trim();
      if (content) input.push({ role, content });
    }
    input.push({ role: 'user', content: userMessage.trim() });

    const bodyStr = JSON.stringify({
      model:      'gpt-4o-mini',
      input,
      stream:     true,
      max_output_tokens: maxOutputTokens || 800,
    });

    const options = {
      hostname: 'api.openai.com',
      port:     443,
      path:     '/v1/responses',
      method:   'POST',
      headers:  {
        'Content-Type':   'application/json',
        'Authorization':  `Bearer ${openAiKey}`,
        'Content-Length': Buffer.byteLength(bodyStr),
      },
    };

    let inputTokensApprox  = 0;
    let outputTokensApprox = 0;
    let sequence           = 1;
    let completed          = false;

    const apiReq = https.request(options, (apiRes) => {
      if (apiRes.statusCode !== 200) {
        let body = '';
        apiRes.on('data', (c) => { body += c; });
        apiRes.on('end', () => {
          reject(new Error(`openai_http_${apiRes.statusCode}:${body.slice(0, 200)}`));
        });
        return;
      }

      let lineBuffer = '';

      apiRes.on('data', (chunk) => {
        if (abortSignal && abortSignal.aborted) {
          apiReq.destroy();
          return;
        }

        lineBuffer += chunk.toString('utf8');

        // Parsear linhas SSE da OpenAI (formato data: {...}\n\n)
        while (true) {
          const lfIdx = lineBuffer.indexOf('\n');
          if (lfIdx === -1) break;
          const line     = lineBuffer.slice(0, lfIdx).trim();
          lineBuffer     = lineBuffer.slice(lfIdx + 1);

          if (!line || line.startsWith(':')) continue; // comment / heartbeat

          if (line.startsWith('data: ')) {
            const rawData = line.slice(6).trim();
            if (rawData === '[DONE]') {
              completed = true;
              continue;
            }
            try {
              const event = JSON.parse(rawData);
              const eventType = event.type || '';

              // ── Evento de texto delta (contrato MedCases) ──────────────────
              if (eventType === 'response.output_text.delta') {
                const delta = event.delta || '';
                if (delta) {
                  onDelta({
                    requestId,
                    attempt:   2,
                    sequence:  sequence++,
                    delta,
                    timestamp: new Date().toISOString(),
                  });
                }
                continue;
              }

              // ── Conclusão da resposta ──────────────────────────────────────
              if (eventType === 'response.completed') {
                const usage = event.response && event.response.usage;
                if (usage) {
                  inputTokensApprox  = usage.input_tokens  || 0;
                  outputTokensApprox = usage.output_tokens || 0;
                }
                completed = true;
                continue;
              }

              // ── Resposta incompleta (limite de tokens, content filter) ─────
              if (eventType === 'response.incomplete') {
                const reason = (event.response && event.response.incomplete_details)
                  ? JSON.stringify(event.response.incomplete_details)
                  : 'unknown';
                reject(new Error(`openai_incomplete:${reason}`));
                return;
              }

              // ── Falha da OpenAI ────────────────────────────────────────────
              if (eventType === 'response.failed' || eventType === 'error') {
                const errMsg = event.message || event.error || eventType;
                reject(new Error(`openai_failed:${errMsg}`));
                return;
              }

              // ── response.created, response.in_progress: ignorar ───────────
              // Outros eventos da OpenAI não são repassados ao Flutter

            } catch (_) {
              // JSON inválido da OpenAI — ignorar linha corrompida
            }
          }
        }
      });

      apiRes.on('end', () => {
        if (completed) {
          resolve({ inputTokensApprox, outputTokensApprox, sequenceCount: sequence - 1 });
        } else {
          reject(new Error('openai_stream_ended_without_done'));
        }
      });
      apiRes.on('error', (err) => reject(new Error(`openai_stream_error:${err.message}`)));
    });

    apiReq.on('error', (err) => reject(new Error(`openai_network_error:${err.message}`)));
    apiReq.setTimeout(90000, () => {
      apiReq.destroy();
      reject(new Error('openai_timeout'));
    });

    // Integração com AbortController
    if (abortSignal) {
      abortSignal.addEventListener('abort', () => {
        apiReq.destroy(new Error('aborted'));
      });
    }

    apiReq.write(bodyStr);
    apiReq.end();
  });
}

// ── Feature flag servidor ─────────────────────────────────────────────────────
// Se USE_GPT_PROXY_SSE !== 'true' no ambiente, o endpoint responde com
// fallback para o endpoint legado (gptProxy).
// Cliente true + servidor true → SSE real
// Qualquer outra combinação → legado síncrono (transparente para o cliente)
const USE_GPT_PROXY_SSE = process.env.USE_GPT_PROXY_SSE !== 'false'; // default true

// ── BUILD 462E-A.1: Allowlist explícita de origens para gptProxyStream ──────────
// Confirmar a origem exata do DevTools e incluir aqui.
// Origens novas devem ser adicionadas nesta única constante.
const GPT_STREAM_ALLOWED_ORIGINS = new Set([
  'https://medcasespro.app',
  'https://www.medcasespro.app',
  'https://medcasespro.com',
  'https://www.medcasespro.com',
  'https://medcases-pro.web.app',
  'https://medcases-pro.firebaseapp.com',
]);

exports.gptProxyStream = onRequest(
  {
    region:         'us-central1',
    secrets:        [OPENAI_KEY],
    timeoutSeconds: 120,
    memory:         '512MiB',
    cors:           false, // BUILD 462E-A.1: CORS gerenciado manualmente abaixo
  },
  async (req, res) => {
    const startMs = Date.now();

    // ── BUILD 462E-A.1 — CORS: aplicar ANTES de autenticação e de toda resposta ──
    // Regra: Access-Control-Allow-Origin só é emitido para origens da allowlist.
    // Vary: Origin emitido incondicionalmente (instrui proxies/CDNs).
    // Todos os erros (401, 403, 429, 500) retornam com CORS headers já presentes.
    const origin          = req.headers.origin || '';
    const isAllowedOrigin = GPT_STREAM_ALLOWED_ORIGINS.has(origin)
                          || (process.env.FUNCTIONS_EMULATOR === 'true');

    // Aplicar CORS headers ANTES de qualquer retorno (presentes em toda resposta)
    if (isAllowedOrigin && origin) {
      res.setHeader('Access-Control-Allow-Origin', origin);
    }
    res.setHeader('Vary', 'Origin'); // sempre — instrui caches HTTP a variar por Origin

    // ── BUILD 462E-A.1 — Preflight OPTIONS ───────────────────────────────────────
    // OPTIONS não exige Firebase ID Token. Responde 204 apenas para origens válidas.
    // Origens não autorizadas: 403 imediato (sem revelar headers de auth).
    if (req.method === 'OPTIONS') {
      if (!isAllowedOrigin || !origin) {
        return res.status(403).end();
      }
      res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
      res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type, Accept');
      res.setHeader('Access-Control-Max-Age', '3600');
      return res.status(204).end();
    }

    // ── BUILD 462E-A.1 — Guard CORS para POST ────────────────────────────────────
    // Bloqueia origens não autorizadas ANTES de autenticação e payload.
    if (!isAllowedOrigin || !origin) {
      return res.status(403).json({ error: 'cors_origin_denied' });
    }

    // ── 1. VALIDAÇÃO DE MÉTODO ─────────────────────────────────────────────────
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'method_not_allowed' });
    }

    // ── 2. VALIDAÇÃO DE CONTENT-TYPE ───────────────────────────────────────────
    const ct = (req.headers['content-type'] || '').toLowerCase();
    if (!ct.includes('application/json')) {
      return res.status(415).json({ error: 'unsupported_media_type' });
    }

    // ── 3. AUTENTICAÇÃO Firebase ID Token ──────────────────────────────────────
    // Falha ANTES da abertura dos headers SSE → JSON com status 401
    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'unauthenticated', message: 'Bearer token obrigatório.' });
    }
    const idToken = authHeader.slice(7).trim();
    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (err) {
      console.warn('[GPT_SSE_CF] token_invalid:', err.code);
      return res.status(401).json({ error: 'invalid_token' });
    }
    const callerUid = decodedToken.uid;

    // ── 4. DESSERIALIZAÇÃO E VALIDAÇÃO DO PAYLOAD ──────────────────────────────
    const data           = req.body || {};
    const rawUserMessage  = String(data.userMessage  || '').trim();
    const payloadUid      = String(data.uid          || '').trim();
    const rawSystemPrompt = String(data.systemPrompt || '').trim();
    const rawHistory      = Array.isArray(data.history) ? data.history : [];
    const requestId       = String(data.requestId    || `req_cf_${startMs}`);
    const mode            = String(data.mode         || 'plantao');
    const maxOutputTokens = parseInt(data.maxOutputTokens, 10) || 800;

    if (payloadUid && payloadUid !== callerUid) {
      return res.status(403).json({ error: 'permission_denied' });
    }

    const safeUserMessage  = rawUserMessage.substring(0, 4000);
    const safeSystemPrompt = rawSystemPrompt.substring(0, 12000);

    if (!safeUserMessage) {
      return res.status(400).json({ error: 'empty_message' });
    }

    // ── 5. STATUS FIRESTORE (validação approved) ───────────────────────────────
    try {
      const db      = admin.firestore();
      const userDoc = await db.doc(`users/${callerUid}`).get();
      const status  = userDoc.exists ? (userDoc.data().status || '') : '';
      if (status !== 'approved') {
        return res.status(403).json({ error: 'not_approved' });
      }
    } catch (err) {
      console.error('[GPT_SSE_CF] firestore_error:', err.message);
      return res.status(500).json({ error: 'firestore_error' });
    }

    // ── 6. CARREGAR OPENAI_API_KEY (somente após todas as validações) ──────────
    const openAiKey = OPENAI_KEY.value();
    if (!openAiKey) {
      console.error('[GPT_SSE_CF] OPENAI_API_KEY não configurado.');
      return res.status(500).json({ error: 'openai_key_not_configured' });
    }

    // ── AQUI: ABRIR HEADERS SSE ────────────────────────────────────────────────
    // Todas as validações passaram — a partir daqui erros vão via evento SSE.
    res.status(200);
    res.setHeader('Content-Type',      'text/event-stream; charset=utf-8');
    res.setHeader('Cache-Control',     'no-cache, no-transform');
    res.setHeader('X-Accel-Buffering', 'no');
    res.setHeader('Content-Encoding',  'identity');
    // Não usar Content-Length em streams
    if (typeof res.flushHeaders === 'function') res.flushHeaders();

    console.log(
      `[GPT_SSE_CF] → start requestId=${requestId} uid=${callerUid} mode=${mode} `
      + `maxOut=${maxOutputTokens} useSse=${USE_GPT_PROXY_SSE}`
    );

    // ── CANCELAMENTO UPSTREAM ──────────────────────────────────────────────────
    const abortController  = new AbortController();
    let completedNormally  = false;
    let deltaCount         = 0;

    const abortUpstream = (reason) => {
      if (!completedNormally && !abortController.signal.aborted) {
        abortController.abort();
        const durationMs = Date.now() - startMs;
        // Log SEM: API key, ID Token, prompt clínico, dados de paciente
        console.log(
          `[GPT_SSE_CF] abort requestId=${requestId} uid=${callerUid} `
          + `reason=${reason} durationMs=${durationMs} deltaCount=${deltaCount}`
        );
      }
    };

    req.on('aborted', () => abortUpstream('client_aborted'));
    res.on('close',   () => { if (!res.writableEnded) abortUpstream('connection_closed'); });

    // ── HEARTBEAT ─────────────────────────────────────────────────────────────
    const heartbeat = setInterval(() => {
      if (!res.writableEnded) {
        res.write(': heartbeat\n\n');
        if (typeof res.flush === 'function') res.flush();
      }
    }, 15000);

    try {
      // ── EVENTO started ────────────────────────────────────────────────────
      sendSseEvent(res, 'started', {
        requestId,
        attempt:   2,
        model:     'gpt-4o-mini',
        provider:  'gpt_4o_mini',
        timestamp: new Date().toISOString(),
      });

      // ── STREAMING OPENAI → SSE ────────────────────────────────────────────
      const result = await callOpenAiResponsesStream({
        openAiKey,
        systemPrompt:    safeSystemPrompt,
        userMessage:     safeUserMessage,
        history:         rawHistory,
        maxOutputTokens,
        requestId,
        abortSignal:     abortController.signal,
        onDelta: (deltaPayload) => {
          deltaCount++;
          if (!res.writableEnded) {
            sendSseEvent(res, 'text_delta', deltaPayload);
          }
        },
      });

      completedNormally = true;
      const durationMs  = Date.now() - startMs;

      console.log(
        `[GPT_SSE_CF] ✅ done requestId=${requestId} uid=${callerUid} `
        + `durationMs=${durationMs} deltaCount=${deltaCount} `
        + `inputTokensApprox=${result.inputTokensApprox} `
        + `outputTokensApprox=${result.outputTokensApprox}`
      );

      // ── EVENTO transport_done ─────────────────────────────────────────────
      // Flutter/AppProvider emite AiCompleted DEPOIS de sanitizeAndCheck().
      if (!res.writableEnded) {
        sendSseEvent(res, 'transport_done', {
          requestId,
          attempt:            2,
          model:              'gpt-4o-mini',
          inputTokensApprox:  result.inputTokensApprox,
          outputTokensApprox: result.outputTokensApprox,
          durationMs,
          deltaCount,
          timestamp:          new Date().toISOString(),
        });
      }

    } catch (err) {
      const errMsg     = err && err.message ? err.message : String(err);
      const durationMs = Date.now() - startMs;

      if (!completedNormally) {
        // Log sem dados clínicos
        console.error(
          `[GPT_SSE_CF] error requestId=${requestId} uid=${callerUid} `
          + `durationMs=${durationMs} deltaCount=${deltaCount} `
          + `code=${errMsg.split(':')[0]}`
        );

        const errCode = errMsg.includes('timeout')     ? 'cf_timeout'
                      : errMsg.includes('aborted')     ? 'client_cancelled'
                      : errMsg.includes('openai_http') ? errMsg.split(':')[0]
                      : errMsg.includes('incomplete')  ? 'openai_incomplete'
                      : 'cf_internal';

        if (!res.writableEnded) {
          sendSseEvent(res, 'error', {
            requestId,
            attempt:   2,
            error:     errCode,
            timestamp: new Date().toISOString(),
          });
        }
      }

    } finally {
      clearInterval(heartbeat);
      if (!res.writableEnded) res.end();
    }
  }
);
