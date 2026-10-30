'use strict';

const { createCoreController } = require('@strapi/strapi').factories;
const {
  MEMBER_UID,
  requireMembership,
  listMembers,
  findColocationMember,
  removeMember,
} = require('../../../utils/colocation');

function serializeMember(member, { user, colocation }) {
  return {
    documentId: member.documentId,
    name: member.name,
    phone: member.phone || '',
    email: member.email || '',
    roomNumber: member.roomNumber,
    isPresent: member.isPresent !== false,
    isActive: member.isActive !== false,
    hasAccount: Boolean(member.user),
    isMe: member.user?.id === user.id,
    isOwner: Boolean(member.user) && member.user.id === colocation.creator?.id,
  };
}

function cleanMemberPayload(raw) {
  const data = {};
  if (raw.name !== undefined) data.name = String(raw.name).trim();
  if (raw.phone !== undefined) data.phone = String(raw.phone || '').trim();
  if (raw.email !== undefined) data.email = String(raw.email || '').trim() || null;
  if (raw.roomNumber !== undefined) data.roomNumber = String(raw.roomNumber).trim();
  if (typeof raw.isPresent === 'boolean') data.isPresent = raw.isPresent;
  return data;
}

async function isNameTaken(strapi, colocation, name, exceptId) {
  const members = await listMembers(strapi, colocation, { activeOnly: true });
  return members.some(
    (m) => m.documentId !== exceptId && m.name.trim().toLowerCase() === name.toLowerCase(),
  );
}

module.exports = createCoreController(MEMBER_UID, ({ strapi }) => ({
  async find(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    // Les anciens membres sont inclus : ils restent nécessaires pour afficher l'historique et les soldes.
    const members = await listMembers(strapi, membership.colocation);
    return {
      data: members.map((m) => serializeMember(m, membership)),
      meta: { count: members.length },
    };
  },

  async findOne(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const member = await findColocationMember(strapi, membership.colocation, ctx.params.id);
    if (!member) return ctx.notFound('Colocataire introuvable.');
    return { data: serializeMember(member, membership) };
  },

  async create(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const data = cleanMemberPayload(ctx.request.body?.data || ctx.request.body || {});
    if (!data.name || !data.roomNumber) {
      return ctx.badRequest('Le nom et la chambre sont obligatoires.');
    }
    if (await isNameTaken(strapi, membership.colocation, data.name)) {
      return ctx.badRequest('Un colocataire porte déjà ce nom.');
    }

    const created = await strapi.documents(MEMBER_UID).create({
      data: {
        ...data,
        isActive: true,
        colocation: membership.colocation.documentId,
        owner: membership.user.id,
      },
      populate: { user: true },
    });

    ctx.status = 201;
    return { data: serializeMember(created, membership) };
  },

  async update(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const member = await findColocationMember(strapi, membership.colocation, ctx.params.id);
    if (!member?.isActive) return ctx.notFound('Colocataire introuvable.');
    if (member.user && member.user.id !== membership.user.id) {
      return ctx.forbidden('Seul ce colocataire peut modifier sa propre fiche.');
    }

    const data = cleanMemberPayload(ctx.request.body?.data || ctx.request.body || {});
    if (data.name === '' || data.roomNumber === '') {
      return ctx.badRequest('Le nom et la chambre sont obligatoires.');
    }
    if (data.name && (await isNameTaken(strapi, membership.colocation, data.name, member.documentId))) {
      return ctx.badRequest('Un colocataire porte déjà ce nom.');
    }

    const updated = await strapi.documents(MEMBER_UID).update({
      documentId: member.documentId,
      data,
      populate: { user: true },
    });
    return { data: serializeMember(updated, membership) };
  },

  async delete(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const member = await findColocationMember(strapi, membership.colocation, ctx.params.id);
    if (!member?.isActive) return ctx.notFound('Colocataire introuvable.');
    if (member.user?.id === membership.user.id) {
      return ctx.badRequest('Utilisez « Quitter la colocation » pour vous retirer.');
    }
    if (member.user && membership.colocation.creator?.id !== membership.user.id) {
      return ctx.forbidden('Seul le créateur peut retirer un membre qui a un compte.');
    }

    await removeMember(strapi, membership.colocation, member);
    return { data: { documentId: member.documentId, deleted: true } };
  },
}));
