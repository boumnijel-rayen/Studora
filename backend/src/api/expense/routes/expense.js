'use strict';

const { createCoreRouter } = require('@strapi/strapi').factories;
const { FEATURES } = require('../../../utils/subscription/plans');
const { requireFeature } = require('../../../utils/subscription/with-feature');

module.exports = requireFeature(
  FEATURES.ROOMMATES,
  createCoreRouter('api::expense.expense', {
    only: ['find', 'findOne', 'create', 'delete'],
  }),
);
