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
      // 8 Mo : l'import de notes par IA envoie un fichier de 4 Mo maximum encodé en base64.
      jsonLimit: '8mb',
      includeUnparsed: true,
    },
  },
  'global::password-reset',
  'strapi::session',
  'strapi::favicon',
  'strapi::public',
];

