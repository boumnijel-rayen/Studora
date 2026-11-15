'use strict';

const { FEATURES } = require('../../../utils/subscription/plans');
const { requireFeature } = require('../../../utils/subscription/with-feature');

module.exports = requireFeature(FEATURES.STUDY_GROUPS, {
  routes: [
    {
      method: 'POST',
      path: '/study-groups/join',
      handler: 'study-group.joinByCode',
    },
  ],
});
