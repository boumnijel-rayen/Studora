'use strict';

const { createCoreController } = require('@strapi/strapi').factories;
const {
  EXPENSE_UID: UID,
  requireMembership,
  byColocation,
  listMembers,
  findColocationMember,
  findColocationEntry,
} = require('../../../utils/colocation');

const EXPENSE_POPULATE = { paidBy: true, reimbursedTo: true, participants: true };

function serializeExpense(expense) {
  return {
    documentId: expense.documentId,
    title: expense.title,
    amount: Number(expense.amount),
    paidById: expense.paidBy?.documentId ?? null,
    paidByName: expense.paidBy?.name ?? expense.paidByName,
    reimbursedToId: expense.reimbursedTo?.documentId ?? null,
    reimbursedToName: expense.reimbursedTo?.name ?? expense.reimbursedToName ?? null,
    participantIds: (expense.participants || []).map((p) => p.documentId),
    isSettlement: expense.isSettlement === true,
    date: expense.date,
    category: expense.category,
  };
}

/** La répartition est figée à la création : un futur membre ne change pas les anciennes dépenses. */
async function resolveParticipantIds(strapi, colocation, rawIds) {
  const members = await listMembers(strapi, colocation);
  if (!Array.isArray(rawIds) || rawIds.length === 0) {
    return members.filter((m) => m.isActive).map((m) => m.documentId);
  }
  const allowed = new Set(members.map((m) => m.documentId));
  const ids = [...new Set(rawIds.map(String))];
  return ids.every((id) => allowed.has(id)) ? ids : null;
}

module.exports = createCoreController(UID, ({ strapi }) => ({
  async find(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const entries = await strapi.documents(UID).findMany({
      filters: byColocation(membership.colocation),
      sort: { date: 'desc' },
      populate: EXPENSE_POPULATE,
    });
    return { data: entries.map(serializeExpense), meta: { count: entries.length } };
  },

  async findOne(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const entry = await findColocationEntry(strapi, UID, membership.colocation, ctx.params.id, EXPENSE_POPULATE);
    if (!entry) return ctx.notFound('Dépense introuvable.');
    return { data: serializeExpense(entry) };
  },

  async create(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const { colocation, user } = membership;
    const raw = ctx.request.body?.data || ctx.request.body || {};
    const title = String(raw.title || '').trim();
    const amount = Number(raw.amount || 0);
    if (!title || !(amount > 0)) {
      return ctx.badRequest('Un intitulé et un montant positif sont requis.');
    }

    const payer = await findColocationMember(strapi, colocation, raw.paidById);
    if (!payer) {
      return ctx.badRequest('Le payeur doit être un membre de la colocation.');
    }

    const participantIds = await resolveParticipantIds(strapi, colocation, raw.participantIds);
    if (!participantIds || participantIds.length === 0) {
      return ctx.badRequest('La dépense doit être partagée entre des membres de la colocation.');
    }

    const created = await strapi.documents(UID).create({
      data: {
        title,
        amount,
        category: raw.category || 'Autre',
        date: raw.date || new Date().toISOString(),
        isSettlement: false,
        paidBy: payer.documentId,
        paidByName: payer.name,
        participants: participantIds,
        colocation: colocation.documentId,
        owner: user.id,
      },
      populate: EXPENSE_POPULATE,
    });

    ctx.status = 201;
    return { data: serializeExpense(created) };
  },

  async settle(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const { colocation, user } = membership;
    const raw = ctx.request.body?.data || ctx.request.body || {};
    const amount = Number(raw.amount || 0);
    const from = await findColocationMember(strapi, colocation, raw.fromMemberId);
    const to = await findColocationMember(strapi, colocation, raw.toMemberId);

    if (!from || !to || from.documentId === to.documentId || !(amount > 0)) {
      return ctx.badRequest('Deux membres différents et un montant positif sont requis.');
    }

    const created = await strapi.documents(UID).create({
      data: {
        title: `Remboursement : ${from.name} → ${to.name}`,
        amount,
        paidBy: from.documentId,
        paidByName: from.name,
        reimbursedTo: to.documentId,
        reimbursedToName: to.name,
        isSettlement: true,
        date: new Date().toISOString(),
        category: 'Remboursement',
        colocation: colocation.documentId,
        owner: user.id,
      },
      populate: EXPENSE_POPULATE,
    });

    ctx.status = 201;
    return { data: serializeExpense(created) };
  },

  async delete(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const expense = await findColocationEntry(strapi, UID, membership.colocation, ctx.params.id);
    if (!expense) return ctx.notFound('Dépense introuvable.');

    await strapi.documents(UID).delete({ documentId: expense.documentId });
    return { data: { documentId: expense.documentId, deleted: true } };
  },
}));
