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

/** Relations à charger pour calculer les droits de l'utilisateur sur une tâche. */
const CHORE_POPULATE = { assignedTo: { populate: { user: true } }, owner: true };

/**
 * Droits de l'utilisateur connecté sur une tâche :
 * - valider / annuler : le colocataire assigné ; si celui-ci n'a pas de compte Studora,
 *   la personne qui a créé la tâche ou le propriétaire du groupe le fait à sa place ;
 * - réassigner : le colocataire assigné (qui passe la main) ou le créateur de la tâche ;
 * - supprimer : le créateur de la tâche.
 */
function chorePermissions(chore, { user, colocation }) {
  const assigneeUserId = chore.assignedTo?.user?.id ?? null;
  const ownerId = chore.owner?.id ?? null;
  const isAssignee = assigneeUserId !== null && assigneeUserId === user.id;
  const isCreator = ownerId !== null && ownerId === user.id;
  const isGroupOwner = colocation.creator?.id === user.id;
  return {
    canComplete: isAssignee || (assigneeUserId === null && (isCreator || isGroupOwner)),
    canReassign: isAssignee || isCreator,
    canDelete: isCreator,
  };
}

function serializeChore(chore, membership) {
  return {
    documentId: chore.documentId,
    title: chore.title,
    assignedToId: chore.assignedTo?.documentId ?? null,
    assignedToName: chore.assignedTo?.name ?? chore.assignedToName,
    dueDate: chore.dueDate,
    isCompleted: chore.isCompleted === true,
    frequency: chore.frequency,
    ...chorePermissions(chore, membership),
  };
}

const RECURRING_FREQUENCIES = new Set(['Quotidien', 'Hebdomadaire', 'Mensuel', 'Annuel']);

/** Ajoute une période (jour, semaine, mois ou année) à une date. */
function addPeriod(date, frequency) {
  const next = new Date(date);
  if (frequency === 'Quotidien') {
    next.setDate(next.getDate() + 1);
  } else if (frequency === 'Hebdomadaire') {
    next.setDate(next.getDate() + 7);
  } else if (frequency === 'Mensuel') {
    next.setMonth(next.getMonth() + 1);
  } else if (frequency === 'Annuel') {
    next.setFullYear(next.getFullYear() + 1);
  } else {
    return null;
  }
  return next;
}

/**
 * Date de la prochaine occurrence : une période après l'échéance validée, et toujours
 * dans le futur. Valider une tâche en retard ne crée donc pas une nouvelle occurrence
 * déjà en retard (ex. « Quotidien » validée avec 5 jours de retard → demain, pas hier).
 */
function nextDueDate(dueDate, frequency, now = new Date()) {
  let next = addPeriod(dueDate, frequency);
  if (!next || Number.isNaN(next.getTime())) return null;
  for (let i = 0; i < 1000 && next <= now; i++) {
    next = addPeriod(next, frequency);
  }
  return next;
}

/** Début de la période (jour, semaine du lundi, mois, année) qui contient [date]. */
function periodStart(date, frequency) {
  const d = new Date(date);
  if (Number.isNaN(d.getTime())) return null;
  d.setHours(0, 0, 0, 0);
  if (frequency === 'Hebdomadaire') {
    d.setDate(d.getDate() - ((d.getDay() + 6) % 7));
  } else if (frequency === 'Mensuel') {
    d.setDate(1);
  } else if (frequency === 'Annuel') {
    d.setMonth(0, 1);
  } else if (frequency !== 'Quotidien') {
    return null;
  }
  return d;
}

/**
 * Une tâche récurrente ne peut être validée qu'une fois sa période commencée : le jour même
 * pour « Quotidien », la semaine en cours pour « Hebdomadaire », le mois en cours pour
 * « Mensuel », l'année en cours pour « Annuel » (comme l'affichage de l'application).
 * Une marge d'un jour couvre le décalage horaire entre le serveur et le téléphone.
 */
function isTooEarlyToComplete(chore, now = new Date()) {
  if (!RECURRING_FREQUENCIES.has(chore.frequency)) return false;
  const start = periodStart(chore.dueDate, chore.frequency);
  if (!start) return false;
  return now.getTime() < start.getTime() - 24 * 60 * 60 * 1000;
}

/** Crée l'occurrence suivante d'une tâche récurrente, assignée au membre suivant. */
async function createNextOccurrence(strapi, colocation, chore) {
  const dueDate = nextDueDate(chore.dueDate, chore.frequency);
  if (!dueDate) return null;

  // Une seule occurrence en attente par tâche récurrente : pas de doublon si elle existe déjà.
  const pendingTwin = await strapi.documents(CHORE_UID).findFirst({
    filters: {
      ...byColocation(colocation),
      isCompleted: { $eq: false },
      title: { $eqi: chore.title },
      frequency: { $eq: chore.frequency },
      documentId: { $ne: chore.documentId },
    },
  });
  if (pendingTwin) return null;

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

const controller = createCoreController(CHORE_UID, ({ strapi }) => ({
  async find(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const entries = await strapi.documents(CHORE_UID).findMany({
      filters: byColocation(membership.colocation),
      sort: { dueDate: 'asc' },
      populate: CHORE_POPULATE,
    });
    return {
      data: entries.map((c) => serializeChore(c, membership)),
      meta: { count: entries.length },
    };
  },

  async findOne(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const entry = await findColocationEntry(
      strapi,
      CHORE_UID,
      membership.colocation,
      ctx.params.id,
      CHORE_POPULATE,
    );
    if (!entry) return ctx.notFound('Tâche introuvable.');
    return { data: serializeChore(entry, membership) };
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
      populate: CHORE_POPULATE,
    });

    ctx.status = 201;
    return { data: serializeChore(created, membership) };
  },

  async update(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const { colocation } = membership;
    const chore = await findColocationEntry(
      strapi,
      CHORE_UID,
      colocation,
      ctx.params.id,
      CHORE_POPULATE,
    );
    if (!chore) return ctx.notFound('Tâche introuvable.');

    const raw = ctx.request.body?.data || ctx.request.body || {};
    const can = chorePermissions(chore, membership);
    const editsDetails =
      raw.title !== undefined || raw.dueDate !== undefined || raw.frequency !== undefined;
    if (editsDetails && !can.canDelete) {
      return ctx.forbidden('Seule la personne qui a créé cette tâche peut la modifier.');
    }
    if (raw.assignedToId !== undefined && !can.canReassign) {
      return ctx.forbidden('Seul le colocataire assigné ou le créateur de la tâche peut la réassigner.');
    }
    if (
      typeof raw.isCompleted === 'boolean' &&
      raw.isCompleted !== chore.isCompleted &&
      !can.canComplete
    ) {
      return ctx.forbidden('Seul le colocataire assigné peut valider cette tâche.');
    }

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
      if (raw.isCompleted && isTooEarlyToComplete({ ...chore, ...data })) {
        return ctx.badRequest(
          'Cette tâche n\'est pas encore à faire : validez d\'abord l\'occurrence en cours.',
        );
      }
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
      populate: CHORE_POPULATE,
    });
    return { data: serializeChore(updated, membership) };
  },

  async delete(ctx) {
    const membership = await requireMembership(ctx, strapi);
    if (!membership) return;

    const chore = await findColocationEntry(
      strapi,
      CHORE_UID,
      membership.colocation,
      ctx.params.id,
      CHORE_POPULATE,
    );
    if (!chore) return ctx.notFound('Tâche introuvable.');
    if (!chorePermissions(chore, membership).canDelete) {
      return ctx.forbidden('Seule la personne qui a créé cette tâche peut la supprimer.');
    }

    await strapi.documents(CHORE_UID).delete({ documentId: chore.documentId });
    return { data: { documentId: chore.documentId, deleted: true } };
  },
}));

module.exports = controller;
module.exports.nextDueDate = nextDueDate;
module.exports.isTooEarlyToComplete = isTooEarlyToComplete;
module.exports.periodStart = periodStart;
module.exports.chorePermissions = chorePermissions;
