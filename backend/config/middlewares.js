'use strict';

module.exports = ({ env }) => [
  'strapi::logger',
  'strapi::errors',
  'strapi::security',
  {
    name: 'strapi::cors',
    config: {
      origin: env.array('CORS_ORIGINS', ['*']),
      headers: ['Content-Type', 'Authorization', 'Accept'],
    },
  },
  'strapi::poweredBy',
  'strapi::query',
  {
    name: 'strapi::body',
    config: {
      jsonLimit: '1mb',
      includeUnparsed: true,
    },
  },
  'global::password-reset',
  'strapi::session',
  'strapi::favicon',
  'strapi::public',
];

