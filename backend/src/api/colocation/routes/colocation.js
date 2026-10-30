'use strict';

module.exports = {
  routes: [
    {
      method: 'GET',
      path: '/colocations/mine',
      handler: 'colocation.mine',
    },
    {
      method: 'POST',
      path: '/colocations',
      handler: 'colocation.create',
    },
    {
      method: 'POST',
      path: '/colocations/join',
      handler: 'colocation.joinByCode',
    },
    {
      method: 'POST',
      path: '/colocations/leave',
      handler: 'colocation.leave',
    },
  ],
};
