/**
 * Cloud Functions — MedCases Pro
 *
 * 1. onNewUserRegistered  → onCreate  → notifica admin quando novo usuário se cadastra
 * 2. onUserApproved       → onUpdate  → e-mail de boas-vindas ao usuário aprovado
 * 3. onUserUnblocked      → onUpdate  → e-mail de reativação ao usuário desbloqueado
 *
 * Config necessária (rodar UMA vez no terminal do Mac):
 *   firebase functions:config:set gmail.user="medcasespro@gmail.com" gmail.pass="SUA_APP_PASSWORD"
 *   firebase functions:config:set admin.email="rodrigssousa@gmail.com"
 */

const functions  = require('firebase-functions');
const admin      = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// ── Configuração do remetente Gmail ──────────────────────────────────────────
const gmailUser  = functions.config().gmail?.user  || 'medcasespro@gmail.com';
const gmailPass  = functions.config().gmail?.pass  || '';
const adminEmail = functions.config().admin?.email || 'rodrigssousa@gmail.com';

// Guard: sem senha configurada, loga e aborta para evitar erro silencioso
function getTransporter() {
  if (!gmailPass) {
    console.error('❌ CONFIGURAÇÃO AUSENTE: gmail.pass não definido via firebase functions:config:set');
    return null;
  }
  return nodemailer.createTransport({
    service: 'gmail',
    auth: { user: gmailUser, pass: gmailPass },
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// 1. NOVO USUÁRIO → notifica admin
// ══════════════════════════════════════════════════════════════════════════════
exports.onNewUserRegistered = functions
  .region('us-central1')
  .firestore
  .document('users/{uid}')
  .onCreate(async (snap, context) => {
    const data = snap.data();

    // Ignora admin (já aprovado automaticamente)
    if (data.status === 'approved') {
      console.log('Admin ou usuário auto-aprovado — ignorando notificação.');
      return null;
    }

    const userName        = data.displayName  || 'Usuário';
    const userEmail       = data.email        || '(sem e-mail)';
    const userProfession  = data.profession   || '—';
    const userInstitution = data.institution  || '—';
    const uid             = context.params.uid;
    const createdAt       = new Date().toLocaleString('pt-BR', { timeZone: 'America/Sao_Paulo' });

    const transporter = getTransporter();
    if (!transporter) return null;

    const subject = `🆕 Novo pedido de acesso — ${userName}`;

    const html = buildAdminNotificationHtml({
      userName, userEmail, userProfession, userInstitution, uid, createdAt,
    });

    try {
      await transporter.sendMail({
        from:    `"MedCases Pro" <${gmailUser}>`,
        to:      adminEmail,
        subject: subject,
        html:    html,
      });
      console.log(`✅ Admin notificado sobre novo cadastro de ${userEmail}`);
    } catch (err) {
      console.error(`❌ Erro ao notificar admin:`, err);
    }

    return null;
  });

// ══════════════════════════════════════════════════════════════════════════════
// 2. USUÁRIO APROVADO → e-mail de boas-vindas
//    Cobre: pending → approved  (e qualquer outro status → approved)
//    Exceto: blocked → approved (coberto pela função 3)
// ══════════════════════════════════════════════════════════════════════════════
exports.onUserApproved = functions
  .region('us-central1')
  .firestore
  .document('users/{uid}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after  = change.after.data();

    // Só dispara: qualquer status (exceto blocked) → approved
    if (after.status !== 'approved') return null;
    if (before.status === 'approved') return null;
    if (before.status === 'blocked') return null; // tratado por onUserUnblocked

    const userName  = after.displayName || 'Médico(a)';
    const userEmail = after.email       || '';
    const userLang  = after.lang        || 'pt';

    if (!userEmail) {
      console.log('Usuário sem e-mail, ignorando.');
      return null;
    }

    const transporter = getTransporter();
    if (!transporter) return null;

    const isEs    = userLang === 'es';
    const subject = isEs
      ? '✅ Tu acceso a MedCases Pro fue aprobado'
      : '✅ Seu acesso ao MedCases Pro foi aprovado';

    try {
      await transporter.sendMail({
        from:    `"MedCases Pro" <${gmailUser}>`,
        to:      userEmail,
        subject: subject,
        html:    buildUserEmailHtml(userName, isEs, false),
      });
      console.log(`✅ E-mail de aprovação enviado para ${userEmail}`);
    } catch (err) {
      console.error(`❌ Erro ao enviar e-mail de aprovação para ${userEmail}:`, err);
    }

    return null;
  });

// ══════════════════════════════════════════════════════════════════════════════
// 3. USUÁRIO DESBLOQUEADO → e-mail de reativação
//    Cobre: blocked → approved
// ══════════════════════════════════════════════════════════════════════════════
exports.onUserUnblocked = functions
  .region('us-central1')
  .firestore
  .document('users/{uid}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after  = change.after.data();

    if (before.status !== 'blocked' || after.status !== 'approved') return null;

    const userName  = after.displayName || 'Médico(a)';
    const userEmail = after.email       || '';
    const userLang  = after.lang        || 'pt';

    if (!userEmail) return null;

    const transporter = getTransporter();
    if (!transporter) return null;

    const isEs    = userLang === 'es';
    const subject = isEs
      ? '🔓 Tu acceso a MedCases Pro fue restaurado'
      : '🔓 Seu acesso ao MedCases Pro foi restaurado';

    try {
      await transporter.sendMail({
        from:    `"MedCases Pro" <${gmailUser}>`,
        to:      userEmail,
        subject: subject,
        html:    buildUserEmailHtml(userName, isEs, true),
      });
      console.log(`✅ E-mail de desbloqueio enviado para ${userEmail}`);
    } catch (err) {
      console.error(`❌ Erro ao enviar e-mail de desbloqueio:`, err);
    }

    return null;
  });

// ══════════════════════════════════════════════════════════════════════════════
// TEMPLATE: E-MAIL PARA O ADMIN (novo cadastro)
// ══════════════════════════════════════════════════════════════════════════════
function buildAdminNotificationHtml({ userName, userEmail, userProfession, userInstitution, uid, createdAt }) {
  return `
<!DOCTYPE html>
<html lang="pt-br">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Novo pedido de acesso</title>
</head>
<body style="margin:0; padding:0; background-color:#f0f4f1; font-family: Arial, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f0f4f1; padding: 32px 16px;">
    <tr>
      <td align="center">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;">

          <!-- HEADER -->
          <tr>
            <td style="
              background: linear-gradient(135deg, #0f1c14 0%, #1b3d2a 50%, #1f6b48 100%);
              border-radius: 18px 18px 0 0;
              padding: 36px 32px 28px 32px;
              text-align: center;
            ">
              <div style="
                display: inline-block;
                background: rgba(197,163,101,0.15);
                border: 1.5px solid rgba(197,163,101,0.4);
                border-radius: 14px;
                padding: 10px 18px;
                margin-bottom: 16px;
              ">
                <span style="font-size: 22px; font-weight: 900; color: #FFE8A6; letter-spacing: -0.5px;">M+</span>
                <span style="font-size: 13px; font-weight: 700; color: rgba(255,232,166,0.7); margin-left: 8px; letter-spacing: 1px;">MEDCASES PRO</span>
              </div>

              <div style="font-size: 36px; margin-bottom: 12px;">🆕</div>

              <h1 style="margin: 0; font-size: 22px; font-weight: 900; color: #ffffff; letter-spacing: -0.5px;">
                Novo pedido de acesso
              </h1>
              <p style="margin: 8px 0 0 0; font-size: 13px; color: rgba(255,255,255,0.6);">
                ${createdAt} (Horário de Brasília)
              </p>
            </td>
          </tr>

          <!-- CORPO -->
          <tr>
            <td style="background: #ffffff; padding: 32px 32px 24px 32px;">
              <p style="font-size: 15px; color: #0f1c14; margin: 0 0 20px 0;">
                Um novo usuário solicitou acesso ao <strong>MedCases Pro</strong>. Revise os dados abaixo e aprove ou rejeite no painel admin.
              </p>

              <!-- Card de dados do usuário -->
              <div style="background: #f7faf8; border: 1px solid #d1e8da; border-radius: 12px; padding: 20px 24px; margin-bottom: 28px;">
                <p style="font-size: 11px; font-weight: 900; color: #1f6b48; letter-spacing: 1.5px; margin: 0 0 16px 0;">DADOS DO SOLICITANTE</p>

                <table width="100%" cellpadding="0" cellspacing="0">
                  <tr>
                    <td style="padding: 6px 0; font-size: 12px; color: #6b7280; width: 110px;">Nome</td>
                    <td style="padding: 6px 0; font-size: 14px; color: #0f1c14; font-weight: 700;">${userName}</td>
                  </tr>
                  <tr>
                    <td style="padding: 6px 0; font-size: 12px; color: #6b7280;">E-mail</td>
                    <td style="padding: 6px 0; font-size: 14px; color: #0f1c14;">${userEmail}</td>
                  </tr>
                  <tr>
                    <td style="padding: 6px 0; font-size: 12px; color: #6b7280;">Profissão</td>
                    <td style="padding: 6px 0; font-size: 14px; color: #0f1c14;">${userProfession}</td>
                  </tr>
                  <tr>
                    <td style="padding: 6px 0; font-size: 12px; color: #6b7280;">Instituição</td>
                    <td style="padding: 6px 0; font-size: 14px; color: #0f1c14;">${userInstitution}</td>
                  </tr>
                  <tr>
                    <td style="padding: 6px 0; font-size: 12px; color: #6b7280;">UID</td>
                    <td style="padding: 6px 0; font-size: 11px; color: #9ca3af; font-family: monospace;">${uid}</td>
                  </tr>
                </table>
              </div>

              <!-- Botão ir para o painel -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="https://medcasespro.com" style="
                      display: inline-block;
                      background: linear-gradient(135deg, #d4af5a, #c5a365);
                      color: #0f1c14;
                      font-size: 15px;
                      font-weight: 900;
                      text-decoration: none;
                      padding: 14px 40px;
                      border-radius: 12px;
                      letter-spacing: 0.2px;
                    ">Ir para o Painel Admin →</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- RODAPÉ -->
          <tr>
            <td style="
              background: #f7faf8;
              border: 1px solid #e5ebe7;
              border-top: none;
              border-radius: 0 0 18px 18px;
              padding: 20px 32px;
              text-align: center;
            ">
              <p style="font-size: 12px; color: #9ca3af; margin: 0 0 4px 0;">
                Esta é uma notificação automática do MedCases Pro.
              </p>
              <p style="font-size: 12px; font-weight: 700; color: #1f6b48; margin: 0;">Equipe MedCases Pro</p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `;
}

// ══════════════════════════════════════════════════════════════════════════════
// TEMPLATE: E-MAIL PARA O USUÁRIO (aprovação / reativação)
// ══════════════════════════════════════════════════════════════════════════════
function buildUserEmailHtml(userName, isEs, isUnblock = false) {
  const firstName = userName.split(' ')[0];

  const greeting = isEs ? `¡Hola, ${firstName}!` : `Olá, ${firstName}!`;

  const headline = isUnblock
    ? (isEs ? 'Tu acceso fue restaurado' : 'Seu acesso foi restaurado')
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

  const ctaLabel = isEs ? 'Acceder ahora' : 'Acessar agora';
  const ctaUrl   = 'https://medcasespro.com';

  const footer1 = isEs
    ? 'Si tienes dudas, responde este e-mail.'
    : 'Em caso de dúvidas, responda este e-mail.';

  const footer2 = isEs ? 'Equipo MedCases Pro' : 'Equipe MedCases Pro';

  const featuresHtml = features
    .map(f => `
      <tr>
        <td style="padding: 7px 0; font-size: 14px; color: #2d4a38; font-family: Arial, sans-serif;">
          ${f}
        </td>
      </tr>`)
    .join('');

  return `
<!DOCTYPE html>
<html lang="${isEs ? 'es' : 'pt-br'}">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${headline}</title>
</head>
<body style="margin:0; padding:0; background-color:#f0f4f1; font-family: Arial, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f0f4f1; padding: 32px 16px;">
    <tr>
      <td align="center">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;">

          <!-- HEADER -->
          <tr>
            <td style="
              background: linear-gradient(135deg, #0f1c14 0%, #1b3d2a 50%, #1f6b48 100%);
              border-radius: 18px 18px 0 0;
              padding: 36px 32px 28px 32px;
              text-align: center;
            ">
              <div style="
                display: inline-block;
                background: rgba(197,163,101,0.15);
                border: 1.5px solid rgba(197,163,101,0.4);
                border-radius: 14px;
                padding: 10px 18px;
                margin-bottom: 16px;
              ">
                <span style="font-size: 22px; font-weight: 900; color: #FFE8A6; letter-spacing: -0.5px;">M+</span>
                <span style="font-size: 13px; font-weight: 700; color: rgba(255,232,166,0.7); margin-left: 8px; letter-spacing: 1px;">MEDCASES PRO</span>
              </div>

              <div style="
                width: 64px; height: 64px;
                background: rgba(74,222,128,0.15);
                border: 2px solid rgba(74,222,128,0.4);
                border-radius: 50%;
                margin: 0 auto 16px auto;
                font-size: 28px;
                line-height: 64px;
                text-align: center;
              ">✅</div>

              <h1 style="margin: 0; font-size: 24px; font-weight: 900; color: #ffffff; letter-spacing: -0.5px;">
                ${headline}
              </h1>
            </td>
          </tr>

          <!-- CORPO -->
          <tr>
            <td style="background: #ffffff; padding: 32px 32px 24px 32px;">
              <p style="font-size: 16px; font-weight: 700; color: #0f1c14; margin: 0 0 12px 0;">${greeting}</p>
              <p style="font-size: 14px; color: #4b5563; line-height: 1.6; margin: 0 0 24px 0;">${body1}</p>

              <!-- Box de recursos -->
              <div style="background: #f7faf8; border: 1px solid #d1e8da; border-radius: 12px; padding: 18px 20px; margin-bottom: 28px;">
                <p style="font-size: 11px; font-weight: 900; color: #1f6b48; letter-spacing: 1.5px; margin: 0 0 12px 0;">
                  ${isEs ? 'LO QUE TIENES DISPONIBLE' : 'O QUE VOCÊ TEM DISPONÍVEL'}
                </p>
                <table width="100%" cellpadding="0" cellspacing="0">
                  ${featuresHtml}
                </table>
              </div>

              <!-- Botão CTA -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="${ctaUrl}" style="
                      display: inline-block;
                      background: linear-gradient(135deg, #d4af5a, #c5a365);
                      color: #0f1c14;
                      font-size: 15px;
                      font-weight: 900;
                      text-decoration: none;
                      padding: 14px 40px;
                      border-radius: 12px;
                      letter-spacing: 0.2px;
                    ">${ctaLabel} →</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- RODAPÉ -->
          <tr>
            <td style="
              background: #f7faf8;
              border: 1px solid #e5ebe7;
              border-top: none;
              border-radius: 0 0 18px 18px;
              padding: 20px 32px;
              text-align: center;
            ">
              <p style="font-size: 12px; color: #9ca3af; margin: 0 0 4px 0;">${footer1}</p>
              <p style="font-size: 12px; font-weight: 700; color: #1f6b48; margin: 0;">${footer2}</p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `;
}
