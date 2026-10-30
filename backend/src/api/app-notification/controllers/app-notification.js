'use strict';

const { createOwnedController, requireUser } = require('../../../utils/ownership');

const UID = 'api::app-notification.app-notification';

module.exports = createOwnedController(UID, {
  extraActions: ({ strapi }) => ({
    async markAllRead(ctx) {
      const user = requireUser(ctx);
      if (!user) return;

      const unread = await strapi.documents(UID).findMany({
        filters: { owner: { id: user.id }, read: false },
      });

      for (const item of unread) {
        await strapi.documents(UID).update({
          documentId: item.documentId,
          data: { read: true },
        });
      }

      return { data: { updated: unread.length } };
    },
  }),
});
