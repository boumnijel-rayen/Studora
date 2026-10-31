'use strict';

const { createCoreService } = require('@strapi/strapi').factories;

module.exports = createCoreService('api::colocation-message.colocation-message');
