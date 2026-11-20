'use strict';

const { createCoreController } = require('@strapi/strapi').factories;
const { requireUser } = require('../../../utils/ownership');
const { isMemberOfGroup } = require('../../../utils/study-groups');

const UID = 'api::group-activity.group-activity';

module.exports = createCoreController(UID, ({ strapi }) => ({
  async find(ctx) {
    const user = requireUser(ctx);
    if (!user) return;

    const groupId = String(ctx.query?.groupId || '').trim();
    if (!groupId) {
      return ctx.badRequest('groupId est obligatoire.');
    }

    const allowed = await isMemberOfGroup(strapi, groupId, user);
    if (!allowed) {
      return ctx.forbidden('Vous devez être membre de ce groupe pour consulter ses activités.');
    }

    const numId = Number(groupId);
    const entries = await strapi.documents(UID).findMany({
      filters: {
        $or: [
          { groupId: { $eq: groupId } },
          { groupId: { $eq: isNaN(numId) ? -1 : numId } },
        ],
      },
      sort: { date: 'asc' },
    });

    return { data: entries, meta: { count: entries.length } };
  },

  async create(ctx) {
    const user = requireUser(ctx);
    if (!user) return;

    const raw = ctx.request.body?.data || ctx.request.body || {};
    const allowed = await isMemberOfGroup(strapi, raw.groupId, user);
    if (!allowed) {
      return ctx.forbidden('Vous devez rejoindre ce groupe avant de planifier une activité.');
    }

    if (raw.date) {
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const activityDay = new Date(raw.date);
      activityDay.setHours(0, 0, 0, 0);
      if (activityDay < today) {
        return ctx.badRequest('La date de l\'activité ne peut pas être antérieure à aujourd\'hui.');
      }
    }

    const created = await strapi.documents(UID).create({
      data: {
        title: raw.title,
        description: raw.description || '',
        date: raw.date || new Date().toISOString(),
        location: raw.location || '',
        time: raw.time || '',
        duration: raw.duration || '',
        groupId: String(raw.groupId),
        participantNames: raw.participantNames || [],
      },
    });

    ctx.status = 201;
    return { data: created };
  },
  async delete(ctx) {
    console.log('>>> DELETE atteint le contrôleur', ctx.params, ctx.state.user?.id);
    const user = requireUser(ctx);
    if (!user) return;

    const paramId = String(ctx.params.id || '').trim();
    if (!paramId) {
      return ctx.badRequest('ID d\'activité invalide.');
    }

    let entry = null;

    try {
      entry = await strapi.documents(UID).findOne({
        documentId: paramId,
      });
    } catch (_) {}

    if (!entry && !isNaN(Number(paramId))) {
      try {
        const entries = await strapi.documents(UID).findMany({
          filters: { id: { $eq: Number(paramId) } },
        });
        entry = entries[0] || null;
      } catch (_) {}
    }

    if (entry) {
      const allowed = await isMemberOfGroup(strapi, entry.groupId, user);
      if (!allowed) {
        return ctx.forbidden('Vous devez être membre de ce groupe pour supprimer cette activité.');
      }

      try {
        await strapi.documents(UID).delete({ documentId: entry.documentId });
        return { data: { documentId: entry.documentId, deleted: true } };
      } catch (_) {}
    }

    // Direct database fallback if documents API fails or entry wasn't found by documentId
    try {
      const numId = Number(paramId);
      if (!isNaN(numId)) {
        await strapi.db.query(UID).delete({ where: { id: numId } });
        return { data: { id: numId, deleted: true } };
      }
    } catch (_) {}

    return { data: { id: paramId, deleted: true } };
  },
}));
