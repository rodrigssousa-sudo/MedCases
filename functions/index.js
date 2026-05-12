/**
 * Cloud Function — MedCases Pro
 * Trigger: quando status do usuário muda para "approved" no Firestore
 * Ação: envia e-mail de boas-vindas via Gmail (Nodemailer)
 */

const functions  = require('firebase-functions');
const admin      = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// ── Configuração do remetente Gmail ──────────────────────────────────────────
// Preencha com suas credenciais no Firebase (via environment config)
// firebase functions:config:set gmail.user="medcasespro@gmail.com" gmail.pass="SUA_APP_PASSWORD"
const gmailUser = functions.config().gmail?.user || 'medcasespro@gmail.com';
const gmailPass = functions.config().gmail?.pass || '';

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: gmailUser,
    pass: gmailPass,
  },
});

// ── Trigger: onUpdate do documento users/{uid} ───────────────────────────────
exports.onUserApproved = functions
  .region('us-central1')
  .firestore
  .document('users/{uid}')
  .onUpdate(async (change, context) => {

    const before = change.before.data();
    const after  = change.after.data();

    // Só dispara quando status muda de outro valor para "approved"
    if (before.status === 'approved' || after.status !== 'approved') {
      return null;
    }

    const userName  = after.displayName || 'Médico(a)';
    const userEmail = after.email        || '';
    const userLang  = after.lang         || 'pt';

    if (!userEmail) {
      console.log('Usuário sem e-mail, ignorando.');
      return null;
    }

    const isEs = userLang === 'es';

    // ── Conteúdo do e-mail ───────────────────────────────────────────────────
    const subject = isEs
      ? '✅ Tu acceso a MedCases Pro fue aprobado'
      : '✅ Seu acesso ao MedCases Pro foi aprovado';

    const html = buildEmailHtml(userName, isEs);

    // ── Envio ────────────────────────────────────────────────────────────────
    try {
      await transporter.sendMail({
        from:    `"MedCases Pro" <${gmailUser}>`,
        to:      userEmail,
        subject: subject,
        html:    html,
      });
      console.log(`✅ E-mail enviado para ${userEmail}`);
    } catch (err) {
      console.error(`❌ Erro ao enviar e-mail para ${userEmail}:`, err);
    }

    return null;
  });

// ── Trigger: onUpdate para desbloqueio ───────────────────────────────────────
// Cobre o caso onde usuário bloqueado é dessbloqueado (volta a approved)
exports.onUserUnblocked = functions
  .region('us-central1')
  .firestore
  .document('users/{uid}')
  .onUpdate(async (change, context) => {

    const before = change.before.data();
    const after  = change.after.data();

    // Só dispara quando vem especificamente de "blocked" para "approved"
    if (before.status !== 'blocked' || after.status !== 'approved') {
      return null;
    }

    const userName  = after.displayName || 'Médico(a)';
    const userEmail = after.email        || '';
    const userLang  = after.lang         || 'pt';

    if (!userEmail) return null;

    const isEs = userLang === 'es';

    const subject = isEs
      ? '🔓 Tu acceso a MedCases Pro fue restaurado'
      : '🔓 Seu acesso ao MedCases Pro foi restaurado';

    const html = buildEmailHtml(userName, isEs, true);

    try {
      await transporter.sendMail({
        from:    `"MedCases Pro" <${gmailUser}>`,
        to:      userEmail,
        subject: subject,
        html:    html,
      });
      console.log(`✅ E-mail de desbloqueio enviado para ${userEmail}`);
    } catch (err) {
      console.error(`❌ Erro ao enviar e-mail:`, err);
    }

    return null;
  });

// ══════════════════════════════════════════════════════════════════════════════
// TEMPLATE HTML DO E-MAIL
// ══════════════════════════════════════════════════════════════════════════════
function buildEmailHtml(userName, isEs, isUnblock = false) {
  const firstName = userName.split(' ')[0];

  const greeting = isEs
    ? `¡Hola, ${firstName}!`
    : `Olá, ${firstName}!`;

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

  const footer2 = isEs
    ? 'Equipo MedCases Pro'
    : 'Equipe MedCases Pro';

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

          <!-- HEADER VERDE -->
          <tr>
            <td style="
              background: linear-gradient(135deg, #0f1c14 0%, #1b3d2a 50%, #1f6b48 100%);
              border-radius: 18px 18px 0 0;
              padding: 36px 32px 28px 32px;
              text-align: center;
            ">
              <!-- Logo / Marca -->
              <div style="
                display: inline-block;
                background: rgba(197,163,101,0.15);
                border: 1.5px solid rgba(197,163,101,0.4);
                border-radius: 14px;
                padding: 10px 18px;
                margin-bottom: 16px;
              ">
                <span style="
                  font-size: 22px;
                  font-weight: 900;
                  color: #FFE8A6;
                  letter-spacing: -0.5px;
                ">M+</span>
                <span style="
                  font-size: 13px;
                  font-weight: 700;
                  color: rgba(255,232,166,0.7);
                  margin-left: 8px;
                  letter-spacing: 1px;
                ">MEDCASES PRO</span>
              </div>

              <!-- Ícone de check -->
              <div style="
                width: 64px;
                height: 64px;
                background: rgba(74,222,128,0.15);
                border: 2px solid rgba(74,222,128,0.4);
                border-radius: 50%;
                display: inline-flex;
                align-items: center;
                justify-content: center;
                margin: 0 auto 16px auto;
                font-size: 28px;
                line-height: 64px;
              ">✅</div>

              <h1 style="
                margin: 0;
                font-size: 24px;
                font-weight: 900;
                color: #ffffff;
                letter-spacing: -0.5px;
              ">${headline}</h1>
            </td>
          </tr>

          <!-- CORPO BRANCO -->
          <tr>
            <td style="
              background: #ffffff;
              padding: 32px 32px 24px 32px;
            ">
              <p style="
                font-size: 16px;
                font-weight: 700;
                color: #0f1c14;
                margin: 0 0 12px 0;
              ">${greeting}</p>

              <p style="
                font-size: 14px;
                color: #4b5563;
                line-height: 1.6;
                margin: 0 0 24px 0;
              ">${body1}</p>

              <!-- Box de recursos -->
              <div style="
                background: #f7faf8;
                border: 1px solid #d1e8da;
                border-radius: 12px;
                padding: 18px 20px;
                margin-bottom: 28px;
              ">
                <p style="
                  font-size: 11px;
                  font-weight: 900;
                  color: #1f6b48;
                  letter-spacing: 1.5px;
                  margin: 0 0 12px 0;
                ">${isEs ? 'LO QUE TIENES DISPONIBLE' : 'O QUE VOCÊ TEM DISPONÍVEL'}</p>
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
              <p style="
                font-size: 12px;
                color: #9ca3af;
                margin: 0 0 4px 0;
              ">${footer1}</p>
              <p style="
                font-size: 12px;
                font-weight: 700;
                color: #1f6b48;
                margin: 0;
              ">${footer2}</p>
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
