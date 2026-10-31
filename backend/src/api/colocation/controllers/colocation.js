'use strict';

const { createCoreController } = require('@strapi/strapi').factories;
const { requireUser } = require('../../../utils/ownership');
const { generateUniqueCode, userDisplayName } = require('../../../utils/sanitize');
const {
  COLOCATION_UID,
  MEMBER_UID,
  findMembership,
  requireMembership,
  listMembers,
  removeMember,
} = require('../../../utils/colocation');

const ALREADY_MEMBER = 'Vous faites déjà partie d\'une colocation. Quittez-la d\'abord.';

function serializeColocation(colocation, userId, creatorId = colocation.creator?.id) {
  return {
    documentId: colocation.documentId,
    name: colocation.name,
    address: colocation.address || '',
    details: colocation.details || '',
    code: colocation.code,
    isCreator: creatorId === userId,
  };
}

function memberDataFromUser(user, roomNumber) {
  return {
    name: userDisplayName(user),
    email: user.email || null,
    phone: user.phone || '',
    roomNumber: String(roomNumber || '').trim() || 'À définir',
    isPresent: true,
    isActive: true,
    user: user.id,
    owner: user.id,
  };
}

module.exports = createCoreController(COLOCATION_UID, ({ strapi }) => ({
  async mine(ctx) {
    const user = requireUser(ctx);
    if (!user) return;

    const membership = await findMembership(strapi, user.id);
    return { data: membership ? serializeColocation(membership.colocation, user.id) : null };
  },

  async create(ctx) {
    const user = requireUser(ctx);
    if (!user) return;

    if (await findMembership(strapi, user.id)) {
      return ctx.badRequest(ALREADY_MEMBER);
    }

    const raw = ctx.request.body?.data || ctx.request.body || {};
    const name = String(raw.name || '').trim();
    const address = String(raw.address || '').trim();
    if (!name || !address) {
      return ctx.badRequest('Le nom et l\'adresse de la colocation sont obligatoires.');
    }

    const created = await strapi.documents(COLOCATION_UID).create({
      data: {
        name,
        address,
        details: String(raw.details || '').trim(),
        code: await generateUniqueCode(strapi, COLOCATION_UID),
        creator: user.id,
      },
    });
    await strapi.documents(MEMBER_UID).create({
      data: { ...memberDataFromUser(user, raw.roomNumber), colocation: created.documentId },
    });

    ctx.status = 201;
    return { data: serializeColocation(created, user.id, user.id) };
  },

  async joinByCode(ctx) {
    const user = requireUser(ctx);
    if (!user) return;

    if (await findMembership(strapi, user.id)) {
      return ctx.badRequest(ALREADY_MEMBER);
    }

    const raw = ctx.request.body?.data || ctx.request.body || {};
    const code = String(raw.code || '').trim().toUpperCase();
    if (!code) {
      return ctx.badRequest('Code d\'invitation requis.');
    }

    const colocation = await strapi.documents(COLOCATION_UID).findFirst({
      filters: { code: { $eqi: code } },
      populate: { creator: true },
    });
    if (!colocation) {
      const studyGroup = await strapi.documents('api::study-group.study-group').findFirst({
        filters: { code: { $eqi: code } },
      });
      return ctx.notFound(
        studyGroup
          ? 'Ce code correspond à un groupe d\'étude : rejoignez-le depuis le module Groupes.'
          : 'Aucune colocation ne correspond à ce code d\'invitation.',
      );
    }

    // Une fiche créée à l'avance avec le même e-mail est reliée au compte : l'historique est conservé.
    const email = String(user.email || '').toLowerCase();
    const members = await listMembers(strapi, colocation, { activeOnly: true });
    const existing = members.find(
      (m) => !m.user && email && String(m.email || '').toLowerCase() === email,
    );

    if (existing) {
      await strapi.documents(MEMBER_UID).update({
        documentId: existing.documentId,
        data: { user: user.id },
      });
    } else {
      await strapi.documents(MEMBER_UID).create({
        data: { ...memberDataFromUser(user, raw.roomNumber), colocation: colocation.documentId },
      });
    }

    return { data: serializeColocation(colocation, user.id) };
  },

  async leave(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const member = { ...membership.member, user: membership.user };
    const result = await removeMember(strapi, membership.colocation, member);
    return { data: { left: true, ...result } };
  },
}));
