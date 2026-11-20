'use strict';

const { FEATURES } = require('../../../utils/subscription/plans');
const { requireFeature } = require('../../../utils/subscription/with-feature');

module.exports = requireFeature(FEATURES.ROOMMATES, {
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
});
