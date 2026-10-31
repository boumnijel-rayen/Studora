'use strict';

const { createCoreController } = require('@strapi/strapi').factories;
const { userDisplayName } = require('../../../utils/sanitize');
const { MESSAGE_UID, requireMembership, byColocation } = require('../../../utils/colocation');

const MAX_MESSAGES = 200;

function serializeMessage(message, userId) {
  return {
    documentId: message.documentId,
    text: message.text,
    senderName: message.senderName,
    timestamp: message.timestamp,
    senderId: message.sender?.id ?? null,
    isMe: message.sender?.id === userId,
  };
}

module.exports = createCoreController(MESSAGE_UID, ({ strapi }) => ({
  async find(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const entries = await strapi.documents(MESSAGE_UID).findMany({
      filters: byColocation(membership.colocation),
      sort: { timestamp: 'desc' },
      limit: MAX_MESSAGES,
      populate: { sender: true },
    });

    return {
      data: entries.reverse().map((m) => serializeMessage(m, membership.user.id)),
      meta: { count: entries.length },
    };
  },

  async create(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const raw = ctx.request.body?.data || ctx.request.body || {};
    const text = String(raw.text || '').trim();
    if (!text) {
      return ctx.badRequest('Le message ne peut pas être vide.');
    }

    const created = await strapi.documents(MESSAGE_UID).create({
      data: {
        text,
        senderName: userDisplayName(membership.user),
        timestamp: new Date().toISOString(),
        colocation: membership.colocation.documentId,
        sender: membership.user.id,
      },
      populate: { sender: true },
    });

    ctx.status = 201;
    return { data: serializeMessage(created, membership.user.id) };
  },
}));
