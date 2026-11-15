'use strict';

const { FEATURES } = require('../../../utils/subscription/plans');
const { requireFeature } = require('../../../utils/subscription/with-feature');

module.exports = requireFeature(FEATURES.ROOMMATES, {
  routes: [
    {
      method: 'POST',
      path: '/expenses/settle',
      handler: 'expense.settle',
    },
  ],
});
