'use strict';

const { createCoreController } = require('@strapi/strapi').factories;
const { requireUser } = require('../../../utils/ownership');
const { userDisplayName } = require('../../../utils/sanitize');
const { isMemberOfGroup } = require('../../../utils/study-groups');

const UID = 'api::group-message.group-message';

function serializeMessage(message, userId) {
  const { sender, group, ...fields } = message;
  return {
    ...fields,
    senderId: sender?.id ?? null,
    isMe: sender?.id === userId,
  };
}

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
      return ctx.forbidden('Vous devez être membre de ce groupe pour consulter ses messages.');
    }

    const entries = await strapi.documents(UID).findMany({
      filters: { groupId: { $eq: groupId } },
      sort: { timestamp: 'asc' },
      populate: { sender: true },
    });

    return {
      data: entries.map((m) => serializeMessage(m, user.id)),
      meta: { count: entries.length },
    };
  },

  async create(ctx) {
    const user = requireUser(ctx);
    if (!user) return;

    const raw = ctx.request.body?.data || ctx.request.body || {};
    const groupId = String(raw.groupId || '').trim();
    const text = String(raw.text || '').trim();

    if (!groupId || !text) {
      return ctx.badRequest('groupId et text sont obligatoires.');
    }

    const allowed = await isMemberOfGroup(strapi, groupId, user.id);
    if (!allowed) {
      return ctx.forbidden('Vous devez rejoindre ce groupe avant d\'envoyer un message.');
    }

    const created = await strapi.documents(UID).create({
      data: {
        groupId,
        text,
        senderName: userDisplayName(user),
        timestamp: new Date().toISOString(),
        sender: user.id,
      },
      populate: { sender: true },
    });

    ctx.status = 201;
    return { data: serializeMessage(created, user.id) };
  },
}));
