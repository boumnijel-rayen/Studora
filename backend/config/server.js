'use strict';

module.exports = ({ env }) => ({
  host: env('HOST', '0.0.0.0'),
  port: env.int('PORT', 1337),
  // Render fournit RENDER_EXTERNAL_URL et termine le HTTPS devant le serveur.
  url: env('PUBLIC_URL', env('RENDER_EXTERNAL_URL', '')),
  proxy: { koa: env.bool('IS_PROXIED', false) },
  app: {
    keys: env.array('APP_KEYS'),
  },
});

