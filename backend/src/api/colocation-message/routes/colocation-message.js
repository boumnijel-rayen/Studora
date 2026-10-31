'use strict';

const { createCoreRouter } = require('@strapi/strapi').factories;

module.exports = createCoreRouter('api::colocation-message.colocation-message', {
  only: ['find', 'create'],
});
