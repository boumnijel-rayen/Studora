'use strict';

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

