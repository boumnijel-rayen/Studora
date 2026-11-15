'use strict';

const crypto = require('node:crypto');

const ALLOWED_PROFILE_FIELDS = [
  'firstName',
  'lastName',
  'email',
  'phone',
  'university',
  'program',
  'year',
  'bio',
];

function sanitizeProfilePayload(body = {}) {
  const data = body && typeof body.data === 'object' ? body.data : body;
  const out = {};
  for (const key of ALLOWED_PROFILE_FIELDS) {
    if (data[key] !== undefined) {
      out[key] = data[key];
    }
  }
  return out;
}

module.exports = (plugin) => {
  const originalUpdate = plugin.controllers.user.update;

  // Surcharge de POST /api/auth/forgot-password pour éviter l'erreur 500
  // ("Internal Server Error") lorsque aucun fournisseur SMTP / sendmail n'est configuré.
  plugin.controllers.auth.forgotPassword = async (ctx) => {
    const { email } = ctx.request.body || {};
    if (!email || typeof email !== 'string' || !email.includes('@')) {
      return ctx.badRequest('Veuillez fournir une adresse e-mail valide.');
    }

    const cleanEmail = email.trim().toLowerCase();
    const user = await strapi.db.query('plugin::users-permissions.user').findOne({
      where: { email: cleanEmail },
    });

    if (!user || user.blocked) {
      return ctx.badRequest('Aucun compte actif n\'est associé à cette adresse e-mail.');
    }

    const resetPasswordToken = String(crypto.randomInt(100000, 1000000));

    await strapi.db.query('plugin::users-permissions.user').update({
      where: { id: user.id },
      data: { resetPasswordToken },
    });

    // Tente l'envoi d'e-mail si un provider est configuré, sans faire échouer la requête (500)
    // lorsque sendmail / SMTP est absent (ex. environnement local ou Render gratuit).
    try {
      const emailService = strapi.plugin('email')?.service('email');
      if (emailService && process.env.EMAIL_PROVIDER) {
        await emailService.send({
          to: user.email,
          subject: 'Votre code de vérification Studora (OTP)',
          text: `Votre code de vérification à 6 chiffres Studora est : ${resetPasswordToken}`,
          html: `<p>Votre code de vérification à 6 chiffres Studora est : <strong>${resetPasswordToken}</strong></p>`,
        });
      }
    } catch (err) {
      strapi.log.warn(
        `[forgotPassword] Envoi d'e-mail ignoré (aucun serveur SMTP/sendmail disponible) : ${err.message}`,
      );
    }

    ctx.send({
      ok: true,
      otpPreview: resetPasswordToken,
    });
  };

  // Surcharge de POST /api/auth/reset-password pour garantir le hachage du mot de passe
  // via le service officiel users-permissions et retourner un JWT + profil nettoyé.
  plugin.controllers.auth.resetPassword = async (ctx) => {
    const { code, password, passwordConfirmation } = ctx.request.body || {};

    if (!code || typeof code !== 'string' || !code.trim()) {
      return ctx.badRequest('Code de réinitialisation manquant ou invalide.');
    }
    if (!password || typeof password !== 'string' || password.length < 6) {
      return ctx.badRequest('Le mot de passe doit contenir au moins 6 caractères.');
    }
    if (password !== passwordConfirmation) {
      return ctx.badRequest('Les mots de passe ne correspondent pas.');
    }

    const user = await strapi.db.query('plugin::users-permissions.user').findOne({
      where: { resetPasswordToken: code.trim() },
    });

    if (!user || user.blocked) {
      return ctx.badRequest('Ce code de réinitialisation est invalide ou a déjà été utilisé.');
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

    ctx.send({
      jwt,
      user: safeUser,
    });
  };

  // Endpoint dédié PUT /api/users/me (et sécurisation de PUT /api/users/:id)
  plugin.controllers.user.updateMe = async (ctx) => {
    const authUser = ctx.state.user;
    if (!authUser) {
      return ctx.unauthorized('Authentification requise.');
    }

    const payload = sanitizeProfilePayload(ctx.request.body);
    if (payload.email) {
      const existing = await strapi.db.query('plugin::users-permissions.user').findOne({
        where: {
          email: payload.email.toLowerCase(),
          id: { $ne: authUser.id },
        },
      });
      if (existing) {
        return ctx.badRequest('Cette adresse e-mail est déjà utilisée.');
      }
      payload.email = payload.email.toLowerCase();
    }

    const updated = await strapi.db.query('plugin::users-permissions.user').update({
      where: { id: authUser.id },
      data: payload,
      populate: ['role'],
    });

    const { password, resetPasswordToken, confirmationToken, ...safeUser } = updated;
    ctx.body = safeUser;
  };

  plugin.controllers.user.update = async (ctx) => {
    const authUser = ctx.state.user;
    if (!authUser) {
      return ctx.unauthorized('Authentification requise.');
    }
    const targetId = String(ctx.params.id);
    if (targetId !== String(authUser.id) && authUser.role?.type !== 'admin') {
      return ctx.forbidden('Vous ne pouvez modifier que votre propre profil.');
    }
    ctx.request.body = sanitizeProfilePayload(ctx.request.body);
    return originalUpdate(ctx);
  };

  plugin.routes['content-api'].routes.unshift({
    method: 'PUT',
    path: '/users/me',
    handler: 'user.updateMe',
    config: {
      prefix: '',
    },
  });

  return plugin;
};

