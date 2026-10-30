'use strict';

const { createOwnedController, requireUser } = require('../../../utils/ownership');

const UID = 'api::expense.expense';

module.exports = createOwnedController(UID, {
  extraActions: ({ strapi }) => ({
    async settle(ctx) {
      const user = requireUser(ctx);
      if (!user) return;

      const raw = ctx.request.body?.data || ctx.request.body || {};
      const fromPerson = String(raw.fromPerson || '').trim();
      const toPerson = String(raw.toPerson || '').trim();
      const amount = Number(raw.amount || 0);

      if (!fromPerson || !toPerson || !(amount > 0)) {
        return ctx.badRequest('fromPerson, toPerson et un montant positif sont requis.');
      }

      const created = await strapi.documents(UID).create({
        data: {
          title: `Remboursement : ${fromPerson} → ${toPerson}`,
          amount,
          paidByName: fromPerson,
          reimbursedToName: toPerson,
          isSettlement: true,
          date: new Date().toISOString(),
          category: 'Remboursement',
          owner: user.id,
        },
      });

      ctx.status = 201;
      return { data: created };
    },
  }),
});
