'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const nodemailer = require('nodemailer');

function readEnvVars() {
  const vars = { ...process.env };
  try {
    const envPath = path.resolve(process.cwd(), '.env');
    if (fs.existsSync(envPath)) {
      const lines = fs.readFileSync(envPath, 'utf8').split(/\r?\n/);
      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith('#')) continue;
        const eqIdx = trimmed.indexOf('=');
        if (eqIdx === -1) continue;
        const key = trimmed.slice(0, eqIdx).trim();
        let val = trimmed.slice(eqIdx + 1).trim();
        if (
          (val.startsWith('"') && val.endsWith('"')) ||
          (val.startsWith("'") && val.endsWith("'"))
        ) {
          val = val.slice(1, -1);
        }
        if (!vars[key]) {
          vars[key] = val;
        }
      }
    }
  } catch (_) {}
  return vars;
}

function extractPayload(ctx) {
  const raw = ctx.request.body;
  if (raw && typeof raw === 'object') {
    return raw.data && typeof raw.data === 'object' ? raw.data : raw;
  }
  if (typeof raw === 'string' && raw.trim().startsWith('{')) {
    try {
      const parsed = JSON.parse(raw);
      return parsed.data && typeof parsed.data === 'object' ? parsed.data : parsed;
    } catch (_) {
      return {};
    }
  }
  return {};
}

async function sendOtpEmail(strapi, toEmail, otpCode) {
  const env = readEnvVars();
  const smtpHost = env.SMTP_HOST;
  const smtpUser = env.SMTP_USER;
  const smtpPass = env.SMTP_PASS ? env.SMTP_PASS.replace(/\s+/g, '') : '';

  if (!smtpHost || !smtpUser || !smtpPass) {
    throw new Error(
      'Serveur SMTP non configuré sur le backend (SMTP_HOST, SMTP_USER, SMTP_PASS manquants dans .env).',
    );
  }

  const subject = 'Votre code de vérification Studora (OTP)';
  const text = `Bonjour,\n\nVotre code de vérification à 6 chiffres pour réinitialiser votre mot de passe Studora est : ${otpCode}\n\nCe code est personnel et confidentiel.`;
  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 24px; border: 1px solid #e5e7eb; border-radius: 12px;">
      <h2 style="color: #111827; margin-top: 0;">Réinitialisation de mot de passe</h2>
      <p style="color: #4b5563;">Utilisez le code de vérification à 6 chiffres ci-dessous dans l'application <strong>Studora</strong> pour valider votre adresse e-mail :</p>
      <div style="background: #f3f4f6; padding: 16px; text-align: center; border-radius: 8px; margin: 20px 0;">
        <span style="font-size: 28px; font-weight: bold; letter-spacing: 6px; color: #2563eb;">${otpCode}</span>
      </div>
      <p style="color: #6b7280; font-size: 13px;">Si vous n'avez pas demandé cette réinitialisation, vous pouvez ignorer cet e-mail.</p>
    </div>
  `;

  const port = Number(env.SMTP_PORT || 587);
  const transporter = nodemailer.createTransport({
    host: smtpHost,
    port,
    secure: port === 465,
    auth: {
      user: smtpUser,
      pass: smtpPass,
    },
  });

  await transporter.sendMail({
    from: `"Studora" <${smtpUser}>`,
    to: toEmail,
    subject,
    text,
    html,
  });

  strapi.log.info(`[OTP] E-mail OTP envoyé avec succès à ${toEmail} via SMTP (${smtpHost}).`);
}

module.exports = (_config, { strapi }) => {
  return async (ctx, next) => {
    const reqPath = (ctx.path || '').replace(/\/+$/, '');

    // Étape 1 : Demande de réinitialisation -> Génère et envoie un OTP à 6 chiffres par e-mail uniquement
    if (ctx.method === 'POST' && reqPath === '/api/auth/forgot-password') {
      const payload = extractPayload(ctx);
      const email = payload.email || ctx.query?.email;
      if (!email || typeof email !== 'string' || !email.includes('@')) {
        return ctx.badRequest('Veuillez fournir une adresse e-mail valide.');
      }

      const cleanEmail = email.trim().toLowerCase();
      const user = await strapi.db.query('plugin::users-permissions.user').findOne({
        where: { email: cleanEmail },
      });

      if (!user || user.blocked) {
        return ctx.badRequest("Aucun compte actif n'est associé à cette adresse e-mail.");
      }

      // Génère un code OTP à 6 chiffres (ex. "482915")
      const otpCode = String(crypto.randomInt(100000, 1000000));

      await strapi.db.query('plugin::users-permissions.user').update({
        where: { id: user.id },
        data: { resetPasswordToken: otpCode },
      });

      try {
        await sendOtpEmail(strapi, user.email, otpCode);
      } catch (err) {
        strapi.log.error(`[OTP] Échec de l'envoi d'e-mail vers ${user.email} : ${err.message}`);
        return ctx.badRequest(
          `Impossible d'envoyer l'e-mail de vérification : ${err.message}`,
        );
      }

      ctx.status = 200;
      ctx.body = {
        ok: true,
        emailSent: true,
      };
      return;
    }

    // Étape 2 : Vérification du code OTP à 6 chiffres avant d'afficher le formulaire de nouveau mot de passe
    if (ctx.method === 'POST' && reqPath === '/api/auth/verify-otp') {
      const payload = extractPayload(ctx);
      const email = (payload.email || '').toString().trim().toLowerCase();
      const code = (payload.code || '').toString().trim();

      if (!email || !code || !/^\d{6}$/.test(code)) {
        return ctx.badRequest('Veuillez saisir le code à 6 chiffres reçu par e-mail.');
      }

      const user = await strapi.db.query('plugin::users-permissions.user').findOne({
        where: {
          email,
          resetPasswordToken: code,
        },
      });

      if (!user || user.blocked) {
        return ctx.badRequest('Code de vérification invalide ou expiré.');
      }

      ctx.status = 200;
      ctx.body = {
        ok: true,
        verified: true,
      };
      return;
    }

    // Étape 3 : Réinitialisation du mot de passe après validation du code OTP
    if (ctx.method === 'POST' && reqPath === '/api/auth/reset-password') {
      const payload = extractPayload(ctx);
      const { code, password, passwordConfirmation, email } = payload;

      if (!code || typeof code !== 'string' || !code.trim()) {
        return ctx.badRequest('Code de vérification manquant ou invalide.');
      }
      if (!password || typeof password !== 'string' || password.length < 6) {
        return ctx.badRequest('Le mot de passe doit contenir au moins 6 caractères.');
      }
      if (password !== passwordConfirmation) {
        return ctx.badRequest('Les mots de passe ne correspondent pas.');
      }

      const whereClause = { resetPasswordToken: code.trim() };
      if (email && typeof email === 'string' && email.trim()) {
        whereClause.email = email.trim().toLowerCase();
      }

      const user = await strapi.db.query('plugin::users-permissions.user').findOne({
        where: whereClause,
      });

      if (!user || user.blocked) {
        return ctx.badRequest('Ce code de vérification est invalide ou a déjà été utilisé.');
      }

      const userService = strapi.plugin('users-permissions').service('user');
      await userService.edit(user.id, {
        resetPasswordToken: null,
        password,
      });

      const updated = await strapi.db.query('plugin::users-permissions.user').findOne({
        where: { id: user.id },
        populate: ['role'],
      });

      const jwt = strapi.plugin('users-permissions').service('jwt').issue({ id: user.id });
      const {
        password: _p,
        resetPasswordToken: _r,
        confirmationToken: _c,
        ...safeUser
      } = updated || user;

      ctx.status = 200;
      ctx.body = {
        jwt,
        user: safeUser,
      };
      return;
    }

    return next();
  };
};
