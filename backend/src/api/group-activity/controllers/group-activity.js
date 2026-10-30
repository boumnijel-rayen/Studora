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

    const allowed = await isMemberOfGroup(strapi, groupId, user.id);
    if (!allowed) {
      return ctx.forbidden('Vous devez être membre de ce groupe pour consulter ses activités.');
    }

    const entries = await strapi.documents(UID).findMany({
      filters: { groupId: { $eq: groupId } },
      sort: { date: 'asc' },
    });

    return { data: entries, meta: { count: entries.length } };
  },

  async create(ctx) {
    const user = requireUser(ctx);
    if (!user) return;

    const raw = ctx.request.body?.data || ctx.request.body || {};
    const allowed = await isMemberOfGroup(strapi, raw.groupId, user.id);
    if (!allowed) {
      return ctx.forbidden('Vous devez rejoindre ce groupe avant de planifier une activité.');
    }

    const created = await strapi.documents(UID).create({
      data: {
        title: raw.title,
        description: raw.description || '',
        date: raw.date || new Date().toISOString(),
        location: raw.location || '',
        groupId: raw.groupId,
        participantNames: raw.participantNames || [],
      },
    });

    ctx.status = 201;
    return { data: created };
  },
}));
