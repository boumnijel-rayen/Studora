'use strict';

const { createCoreController } = require('@strapi/strapi').factories;
const {
  CHORE_UID,
  requireMembership,
  byColocation,
  listMembers,
  findColocationMember,
  findColocationEntry,
} = require('../../../utils/colocation');

function serializeChore(chore) {
  return {
    documentId: chore.documentId,
    title: chore.title,
    assignedToId: chore.assignedTo?.documentId ?? null,
    assignedToName: chore.assignedTo?.name ?? chore.assignedToName,
    dueDate: chore.dueDate,
    isCompleted: chore.isCompleted === true,
    frequency: chore.frequency,
  };
}

function nextDueDate(dueDate, frequency) {
  const next = new Date(dueDate);
  if (frequency === 'Quotidien') {
    next.setDate(next.getDate() + 1);
  } else if (frequency === 'Hebdomadaire') {
    next.setDate(next.getDate() + 7);
  } else if (frequency === 'Mensuel') {
    next.setMonth(next.getMonth() + 1);
  } else {
    return null;
  }
  return next;
}

/** Crée l'occurrence suivante d'une tâche récurrente, assignée au membre suivant. */
async function createNextOccurrence(strapi, colocation, chore) {
  const dueDate = nextDueDate(chore.dueDate, chore.frequency);
  if (!dueDate) return null;

  const members = await listMembers(strapi, colocation, { activeOnly: true });
  if (members.length === 0) return null;
  const index = members.findIndex((m) => m.documentId === chore.assignedTo?.documentId);
  const next = members[(index + 1) % members.length];

  return strapi.documents(CHORE_UID).create({
    data: {
      title: chore.title,
      frequency: chore.frequency,
      dueDate: dueDate.toISOString(),
      isCompleted: false,
      assignedTo: next.documentId,
      assignedToName: next.name,
      colocation: colocation.documentId,
      owner: chore.owner?.id,
    },
  });
}

module.exports = createCoreController(CHORE_UID, ({ strapi }) => ({
  async find(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const entries = await strapi.documents(CHORE_UID).findMany({
      filters: byColocation(membership.colocation),
      sort: { dueDate: 'asc' },
      populate: { assignedTo: true },
    });
    return { data: entries.map(serializeChore), meta: { count: entries.length } };
  },

  async findOne(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const entry = await findColocationEntry(strapi, CHORE_UID, membership.colocation, ctx.params.id, {
      assignedTo: true,
    });
    if (!entry) return ctx.notFound('Tâche introuvable.');
    return { data: serializeChore(entry) };
  },

  async create(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const raw = ctx.request.body?.data || ctx.request.body || {};
    const title = String(raw.title || '').trim();
    const assignee = await findColocationMember(strapi, membership.colocation, raw.assignedToId);
    if (!title || !raw.dueDate) {
      return ctx.badRequest('L\'intitulé et la date sont obligatoires.');
    }
    if (!assignee?.isActive) {
      return ctx.badRequest('La tâche doit être assignée à un membre de la colocation.');
    }

    const created = await strapi.documents(CHORE_UID).create({
      data: {
        title,
        dueDate: raw.dueDate,
        frequency: raw.frequency || 'Hebdomadaire',
        isCompleted: false,
        assignedTo: assignee.documentId,
        assignedToName: assignee.name,
        colocation: membership.colocation.documentId,
        owner: membership.user.id,
      },
      populate: { assignedTo: true },
    });

    ctx.status = 201;
    return { data: serializeChore(created) };
  },

  async update(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const { colocation } = membership;
    const chore = await findColocationEntry(strapi, CHORE_UID, colocation, ctx.params.id, {
      assignedTo: true,
      owner: true,
    });
    if (!chore) return ctx.notFound('Tâche introuvable.');

    const raw = ctx.request.body?.data || ctx.request.body || {};
    const data = {};
    if (raw.title !== undefined) data.title = String(raw.title).trim();
    if (raw.dueDate !== undefined) data.dueDate = raw.dueDate;
    if (raw.frequency !== undefined) data.frequency = raw.frequency;
    if (raw.assignedToId !== undefined) {
      const assignee = await findColocationMember(strapi, colocation, raw.assignedToId);
      if (!assignee?.isActive) {
        return ctx.badRequest('La tâche doit être assignée à un membre de la colocation.');
      }
      data.assignedTo = assignee.documentId;
      data.assignedToName = assignee.name;
    }

    if (typeof raw.isCompleted === 'boolean' && raw.isCompleted !== chore.isCompleted) {
      data.isCompleted = raw.isCompleted;
      if (raw.isCompleted) {
        const next = await createNextOccurrence(strapi, colocation, { ...chore, ...data });
        data.nextChoreId = next?.documentId ?? null;
      } else if (chore.nextChoreId) {
        // Annuler une validation retire l'occurrence générée, sauf si elle a déjà été faite.
        const next = await findColocationEntry(strapi, CHORE_UID, colocation, chore.nextChoreId);
        if (next && !next.isCompleted) {
          await strapi.documents(CHORE_UID).delete({ documentId: next.documentId });
        }
        data.nextChoreId = null;
      }
    }

    const updated = await strapi.documents(CHORE_UID).update({
      documentId: chore.documentId,
      data,
      populate: { assignedTo: true },
    });
    return { data: serializeChore(updated) };
  },

  async delete(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const chore = await findColocationEntry(strapi, CHORE_UID, membership.colocation, ctx.params.id);
    if (!chore) return ctx.notFound('Tâche introuvable.');

    await strapi.documents(CHORE_UID).delete({ documentId: chore.documentId });
    return { data: { documentId: chore.documentId, deleted: true } };
  },
}));
