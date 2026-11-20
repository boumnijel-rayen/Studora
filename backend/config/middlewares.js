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
    // 8 Mo : l'import de notes par IA envoie un fichier de 4 Mo maximum encodé en base64.
    config: { jsonLimit: '8mb' },
  },
  'strapi::session',
  'strapi::favicon',
  'strapi::public',
];

