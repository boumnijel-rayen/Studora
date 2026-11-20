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

    const numId = Number(groupId);
    const entries = await strapi.documents(UID).findMany({
      filters: {
        $or: [
          { groupId: { $eq: groupId } },
          { group: { documentId: { $eq: groupId } } },
          { group: { id: { $eq: isNaN(numId) ? -1 : numId } } },
        ],
      },
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
    const groupId = String(raw.groupId || raw.group || '').trim();
    const text = String(raw.text || '').trim();
    const attachmentName = raw.attachmentName ? String(raw.attachmentName).trim() : null;
    const attachmentUrl = raw.attachmentUrl ? String(raw.attachmentUrl).trim() : null;
    const attachmentType = raw.attachmentType ? String(raw.attachmentType).trim() : null;
    const attachmentSize = typeof raw.attachmentSize === 'number'
        ? Number(raw.attachmentSize)
        : (raw.attachmentSize ? Number(raw.attachmentSize) : null);

    if (!groupId || (!text && !attachmentName)) {
      return ctx.badRequest('groupId et au moins un texte ou une pièce jointe sont obligatoires.');
    }

    const allowed = await isMemberOfGroup(strapi, groupId, user.id);
    if (!allowed) {
      return ctx.forbidden('Vous devez rejoindre ce groupe avant d\'envoyer un message.');
    }

    const created = await strapi.documents(UID).create({
      data: {
        groupId,
        text: text || (attachmentName ? `📄 Document joint : ${attachmentName}` : ''),
        senderName: userDisplayName(user),
        timestamp: new Date().toISOString(),
        sender: user.id,
        attachmentName,
        attachmentUrl,
        attachmentType,
        attachmentSize,
      },
      populate: { sender: true },
    });

    ctx.status = 201;
    return { data: serializeMessage(created, user.id) };
  },
}));
