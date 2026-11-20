'use strict';

const { createCoreRouter } = require('@strapi/strapi').factories;
const { FEATURES } = require('../../../utils/subscription/plans');
const { requireFeature } = require('../../../utils/subscription/with-feature');

module.exports = requireFeature(
  FEATURES.ROOMMATES,
  createCoreRouter('api::roommate-member.roommate-member'),
);
