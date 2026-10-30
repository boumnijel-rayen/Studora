'use strict';

/**
 * Helpers réutilisables pour l'isolation stricte des données par utilisateur
 * (propriétaire `owner`) sur les Content Types Strapi 5.
 */
const { stripPrivateFields } = require('./sanitize');

function requireUser(ctx) {
  const user = ctx.state.user;
  if (!user) {
    ctx.unauthorized('Authentification requise.');
    return null;
  }
  return user;
}

function createOwnedController(
  uid,
  { defaultPopulate = {}, beforeCreate, beforeUpdate, extraActions } = {},
) {
  const { createCoreController } = require('@strapi/strapi').factories;

  return createCoreController(uid, ({ strapi }) => ({
    ...(typeof extraActions === 'function' ? extraActions({ strapi }) : extraActions || {}),

    async find(ctx) {
      const user = requireUser(ctx);
      if (!user) return;

      const entries = await strapi.documents(uid).findMany({
        ...ctx.query,
        filters: {
          ...(ctx.query?.filters || {}),
          owner: { id: user.id },
        },
        populate: defaultPopulate,
      });

      return { data: stripPrivateFields(entries), meta: { count: entries.length } };
    },

    async findOne(ctx) {
      const user = requireUser(ctx);
      if (!user) return;

      const documentId = ctx.params.id;
      const entry = await strapi.documents(uid).findOne({
        documentId,
        populate: { ...defaultPopulate, owner: true },
      });

      if (!entry || entry.owner?.id !== user.id) {
        return ctx.notFound('Ressource introuvable ou accès refusé.');
      }

      const { owner, ...safeEntry } = entry;
      return { data: stripPrivateFields(safeEntry) };
    },

    async create(ctx) {
      const user = requireUser(ctx);
      if (!user) return;

      const rawData = ctx.request.body?.data || ctx.request.body || {};
      const cleanData = { ...rawData };
      delete cleanData.owner;
      delete cleanData.id;
      delete cleanData.documentId;

      if (beforeCreate) {
        await beforeCreate(cleanData, { user, strapi, ctx });
      }

      const created = await strapi.documents(uid).create({
        data: {
          ...cleanData,
          owner: user.id,
        },
        populate: defaultPopulate,
      });

      ctx.status = 201;
      return { data: stripPrivateFields(created) };
    },

    async update(ctx) {
      const user = requireUser(ctx);
      if (!user) return;

      const documentId = ctx.params.id;
      const existing = await strapi.documents(uid).findOne({
        documentId,
        populate: { owner: true },
      });

      if (!existing || existing.owner?.id !== user.id) {
        return ctx.notFound('Ressource introuvable ou accès refusé.');
      }

      const rawData = ctx.request.body?.data || ctx.request.body || {};
      const cleanData = { ...rawData };
      delete cleanData.owner;
      delete cleanData.id;
      delete cleanData.documentId;

      if (beforeUpdate) {
        await beforeUpdate(cleanData, { user, existing, strapi, ctx });
      }

      const updated = await strapi.documents(uid).update({
        documentId,
        data: cleanData,
        populate: defaultPopulate,
      });

      return { data: stripPrivateFields(updated) };
    },

    async delete(ctx) {
      const user = requireUser(ctx);
      if (!user) return;

      const documentId = ctx.params.id;
      const existing = await strapi.documents(uid).findOne({
        documentId,
        populate: { owner: true },
      });

      if (!existing || existing.owner?.id !== user.id) {
        return ctx.notFound('Ressource introuvable ou accès refusé.');
      }

      await strapi.documents(uid).delete({ documentId });
      return { data: { documentId, deleted: true } };
    },
  }));
}

module.exports = {
  requireUser,
  createOwnedController,
};
