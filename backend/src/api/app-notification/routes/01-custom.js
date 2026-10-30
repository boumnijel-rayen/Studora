'use strict';

module.exports = {
  routes: [
    {
      method: 'POST',
      path: '/app-notifications/mark-all-read',
      handler: 'app-notification.markAllRead',
    },
  ],
};

