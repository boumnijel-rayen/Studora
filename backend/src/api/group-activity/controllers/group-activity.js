'use strict';

const { createCoreController } = require('@strapi/strapi').factories;
const { requireUser } = require('../../../utils/ownership');

const UID = 'api::group-activity.group-activity';

module.exports = createCoreController(UID, ({ strapi }) => ({
  async find(ctx) {
    const user = requireUser(ctx);
    if (!user) return;

    const groupId = ctx.query?.groupId || ctx.query?.filters?.groupId?.$eq;
    const entries = await strapi.documents(UID).findMany({
      filters: groupId ? { groupId: { $eq: groupId } } : (ctx.query?.filters || {}),
      sort: { date: 'asc' },
    });

    return { data: entries, meta: { count: entries.length } };
  },

  async create(ctx) {
    const user = requireUser(ctx);
    if (!user) return;

    const raw = ctx.request.body?.data || ctx.request.body || {};
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

