'use strict';

const { requireUser } = require('./ownership');

const COLOCATION_UID = 'api::colocation.colocation';
const MEMBER_UID = 'api::roommate-member.roommate-member';
const CHORE_UID = 'api::chore.chore';
const EXPENSE_UID = 'api::expense.expense';
const MESSAGE_UID = 'api::colocation-message.colocation-message';

/** Colocation active de l'utilisateur (un utilisateur appartient à une seule colocation). */
async function findMembership(strapi, userId) {
  const member = await strapi.documents(MEMBER_UID).findFirst({
    filters: { user: { id: { $eq: userId } }, isActive: { $eq: true } },
    populate: { colocation: { populate: { creator: true } } },
  });
  if (!member?.colocation) return null;
  return { member, colocation: member.colocation };
}

/** Répond 403 et renvoie `null` si l'utilisateur n'appartient à aucune colocation. */
async function requireMembership(ctx, strapi) {
  const user = requireUser(ctx);
  if (!user) return null;
  const membership = await findMembership(strapi, user.id);
  if (!membership) {
    ctx.forbidden('Vous devez créer ou rejoindre une colocation.');
    return null;
  }
  return { user, ...membership };
}

function byColocation(colocation) {
  return { colocation: { documentId: { $eq: colocation.documentId } } };
}

async function listMembers(strapi, colocation, { activeOnly = false } = {}) {
  return strapi.documents(MEMBER_UID).findMany({
    filters: {
      ...byColocation(colocation),
      ...(activeOnly ? { isActive: { $eq: true } } : {}),
    },
    sort: { name: 'asc' },
    populate: { user: true },
  });
}

/** Charge un membre en vérifiant qu'il appartient bien à la colocation. */
async function findColocationMember(strapi, colocation, memberId) {
  if (!memberId) return null;
  const member = await strapi.documents(MEMBER_UID).findOne({
    documentId: String(memberId),
    populate: { colocation: true, user: true },
  });
  return member?.colocation?.documentId === colocation.documentId ? member : null;
}

/** Charge une entité en vérifiant qu'elle appartient bien à la colocation. */
async function findColocationEntry(strapi, uid, colocation, documentId, populate = {}) {
  const entry = await strapi.documents(uid).findOne({
    documentId,
    populate: { ...populate, colocation: true },
  });
  return entry?.colocation?.documentId === colocation.documentId ? entry : null;
}

async function deleteColocationData(strapi, colocation) {
  for (const uid of [MESSAGE_UID, EXPENSE_UID, CHORE_UID, MEMBER_UID]) {
    const entries = await strapi.documents(uid).findMany({ filters: byColocation(colocation) });
    for (const entry of entries) {
      await strapi.documents(uid).delete({ documentId: entry.documentId });
    }
  }
  await strapi.documents(COLOCATION_UID).delete({ documentId: colocation.documentId });
}

/**
 * Retire un membre sans effacer l'historique : la fiche reste référencée par les
 * dépenses et les soldes, ses tâches en attente passent à un autre membre.
 * Sans aucun membre avec un compte restant, la colocation est supprimée.
 */
async function removeMember(strapi, colocation, member) {
  const remaining = (await listMembers(strapi, colocation, { activeOnly: true })).filter(
    (m) => m.documentId !== member.documentId,
  );
  const remainingAccounts = remaining.filter((m) => m.user);

  if (remainingAccounts.length === 0) {
    await deleteColocationData(strapi, colocation);
    return { colocationDeleted: true };
  }

  await strapi.documents(MEMBER_UID).update({
    documentId: member.documentId,
    data: { isActive: false, isPresent: false, user: null },
  });

  const pendingChores = await strapi.documents(CHORE_UID).findMany({
    filters: {
      ...byColocation(colocation),
      isCompleted: { $eq: false },
      assignedTo: { documentId: { $eq: member.documentId } },
    },
  });
  for (const chore of pendingChores) {
    await strapi.documents(CHORE_UID).update({
      documentId: chore.documentId,
      data: { assignedTo: remaining[0].documentId, assignedToName: remaining[0].name },
    });
  }

  const creatorId = colocation.creator?.id;
  if (member.user && member.user.id === creatorId) {
    await strapi.documents(COLOCATION_UID).update({
      documentId: colocation.documentId,
      data: { creator: remainingAccounts[0].user.id },
    });
  }

  return { colocationDeleted: false };
}

module.exports = {
  COLOCATION_UID,
  MEMBER_UID,
  CHORE_UID,
  EXPENSE_UID,
  MESSAGE_UID,
  findMembership,
  requireMembership,
  byColocation,
  listMembers,
  findColocationMember,
  findColocationEntry,
  removeMember,
};
