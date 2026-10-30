'use strict';

const { createCoreController } = require('@strapi/strapi').factories;
const { requireUser } = require('../../../utils/ownership');

const UID = 'api::study-group.study-group';

function userDisplayName(user) {
  const full = `${user.firstName || ''} ${user.lastName || ''}`.trim();
  return full || user.username || user.email || 'Étudiant';
}

function serializeGroup(group, userId) {
  const members = Array.isArray(group.members) ? group.members : [];
  const isJoined =
    group.creator?.id === userId ||
    members.some((m) => m.id === userId);
  const namesFromRelation = members.map(userDisplayName);
  const storedNames = Array.isArray(group.memberNames) ? group.memberNames : [];
  const memberNames = Array.from(new Set([...storedNames, ...namesFromRelation]));

  return {
    ...group,
    memberNames,
    isJoined,
  };
}

module.exports = createCoreController(UID, ({ strapi }) => ({
  async find(ctx) {
    const user = requireUser(ctx);
    if (!user) return;

    const entries = await strapi.documents(UID).findMany({
      ...ctx.query,
      populate: { creator: true, members: true, subject: true },
    });

    return {
      data: entries.map((g) => serializeGroup(g, user.id)),
      meta: { count: entries.length },
    };
  },

  async findOne(ctx) {
    const user = requireUser(ctx);
    if (!user) return;

    const entry = await strapi.documents(UID).findOne({
      documentId: ctx.params.id,
      populate: { creator: true, members: true, subject: true },
    });

    if (!entry) return ctx.notFound('Groupe introuvable.');
    return { data: serializeGroup(entry, user.id) };
  },

  async create(ctx) {
    const user = requireUser(ctx);
    if (!user) return;

    const raw = ctx.request.body?.data || ctx.request.body || {};
    const displayName = userDisplayName(user);
    const code = (raw.code || `GRP${Date.now().toString().slice(-4)}`).toUpperCase();

    const created = await strapi.documents(UID).create({
      data: {
        name: raw.name,
        description: raw.description || '',
        subjectId: raw.subjectId || '',
        subjectName: raw.subjectName || '',
        code,
        colorIndex: raw.colorIndex ?? 6,
        memberNames: [displayName],
        creator: user.id,
        members: [user.id],
      },
      populate: { creator: true, members: true, subject: true },
    });

    ctx.status = 201;
    return { data: serializeGroup(created, user.id) };
  },

  async joinByCode(ctx) {
    const user = requireUser(ctx);
    if (!user) return;

    const raw = ctx.request.body?.data || ctx.request.body || {};
    const code = String(raw.code || '').trim().toUpperCase();
    if (!code) {
      return ctx.badRequest('Code de groupe requis.');
    }

    const group = await strapi.documents(UID).findFirst({
      filters: { code: { $eqi: code } },
      populate: { creator: true, members: true, subject: true },
    });

    if (!group) {
      return ctx.notFound('Aucun groupe ne correspond à ce code d\'invitation.');
    }

    const existingMemberIds = (group.members || []).map((m) => m.id);
    if (!existingMemberIds.includes(user.id)) {
      existingMemberIds.push(user.id);
    }

    const displayName = userDisplayName(user);
    const storedNames = Array.isArray(group.memberNames) ? group.memberNames : [];
    const updatedNames = Array.from(new Set([...storedNames, displayName]));

    const updated = await strapi.documents(UID).update({
      documentId: group.documentId,
      data: {
        members: existingMemberIds,
        memberNames: updatedNames,
      },
      populate: { creator: true, members: true, subject: true },
    });

    return { data: serializeGroup(updated, user.id) };
  },

  async delete(ctx) {
    const user = requireUser(ctx);
    if (!user) return;

    const existing = await strapi.documents(UID).findOne({
      documentId: ctx.params.id,
      populate: { creator: true },
    });

    if (!existing) return ctx.notFound('Groupe introuvable.');
    if (existing.creator?.id !== user.id) {
      return ctx.forbidden('Seul le créateur du groupe peut le supprimer.');
    }

    await strapi.documents(UID).delete({ documentId: existing.documentId });
    return { data: { documentId: existing.documentId, deleted: true } };
  },
}));

