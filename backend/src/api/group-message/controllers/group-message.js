'use strict';

const { createCoreController } = require('@strapi/strapi').factories;
const { requireUser } = require('../../../utils/ownership');

const UID = 'api::group-message.group-message';
const GROUP_UID = 'api::study-group.study-group';

function userDisplayName(user) {
  const full = `${user.firstName || ''} ${user.lastName || ''}`.trim();
  return full || user.username || user.email || 'Étudiant';
}

async function isMemberOfGroup(strapi, groupId, userId) {
  if (!groupId) return false;
  const group = await strapi.documents(GROUP_UID).findOne({
    documentId: groupId,
    populate: { creator: true, members: true },
  });
  if (!group) return false;
  return (
    group.creator?.id === userId ||
    (group.members || []).some((m) => m.id === userId)
  );
}

module.exports = createCoreController(UID, ({ strapi }) => ({
  async find(ctx) {
    const user = requireUser(ctx);
    if (!user) return;

    const groupId = ctx.query?.groupId || ctx.query?.filters?.groupId?.$eq;
    if (groupId) {
      const allowed = await isMemberOfGroup(strapi, groupId, user.id);
      if (!allowed) {
        return ctx.forbidden('Vous devez être membre de ce groupe pour consulter ses messages.');
      }
    }

    const entries = await strapi.documents(UID).findMany({
      filters: groupId ? { groupId: { $eq: groupId } } : (ctx.query?.filters || {}),
      sort: { timestamp: 'asc' },
      populate: { sender: true, group: true },
    });

    return {
      data: entries.map((m) => ({
        ...m,
        isMe: m.sender?.id === user.id,
      })),
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
    return {
      data: {
        ...created,
        isMe: true,
      },
    };
  },
}));

