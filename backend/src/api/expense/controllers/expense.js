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

const EXPENSE_POPULATE = { paidBy: true, reimbursedTo: true, participants: true, owner: true };

/** Chacun ne gère que ce qui le concerne. Un colocataire sans compte est géré par les autres. */
const expenseRules = {
  /** Payeur d'une nouvelle dépense : soi-même, ou un colocataire sans compte. */
  canRecordPayment(payer, user) {
    return !payer.user || payer.user.id === user.id;
  },
  /**
   * Remboursement : enregistré par la personne qui rembourse ; si elle n'a pas de compte,
   * par la personne remboursée (qui confirme avoir reçu l'argent).
   */
  canSettle(from, to, user) {
    if (from.user) return from.user.id === user.id;
    return Boolean(to.user) && to.user.id === user.id;
  },
  /** Suppression : uniquement par la personne qui a saisi la dépense ou le remboursement. */
  canDelete(expense, user) {
    return Boolean(expense.owner) && expense.owner.id === user.id;
  },
};

function serializeExpense(expense, user) {
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
    canDelete: expenseRules.canDelete(expense, user),
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

const controller = createCoreController(UID, ({ strapi }) => ({
  async find(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const entries = await strapi.documents(UID).findMany({
      filters: byColocation(membership.colocation),
      sort: { date: 'desc' },
      populate: EXPENSE_POPULATE,
    });
    return {
      data: entries.map((e) => serializeExpense(e, membership.user)),
      meta: { count: entries.length },
    };
  },

  async findOne(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const entry = await findColocationEntry(strapi, UID, membership.colocation, ctx.params.id, EXPENSE_POPULATE);
    if (!entry) return ctx.notFound('Dépense introuvable.');
    return { data: serializeExpense(entry, membership.user) };
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
    if (!expenseRules.canRecordPayment(payer, user)) {
      return ctx.forbidden(
        'Vous ne pouvez enregistrer que vos propres dépenses (ou celles d\'un colocataire sans compte).',
      );
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
    return { data: serializeExpense(created, user) };
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
    if (!expenseRules.canSettle(from, to, user)) {
      return ctx.forbidden('Seule la personne qui rembourse peut enregistrer ce remboursement.');
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
    return { data: serializeExpense(created, user) };
  },

  async delete(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const expense = await findColocationEntry(strapi, UID, membership.colocation, ctx.params.id, {
      owner: true,
    });
    if (!expense) return ctx.notFound('Dépense introuvable.');
    if (!expenseRules.canDelete(expense, membership.user)) {
      return ctx.forbidden('Seule la personne qui a saisi cette opération peut la supprimer.');
    }

    await strapi.documents(UID).delete({ documentId: expense.documentId });
    return { data: { documentId: expense.documentId, deleted: true } };
  },
}));

module.exports = controller;
module.exports.expenseRules = expenseRules;
