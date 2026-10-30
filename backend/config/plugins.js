'use strict';

module.exports = ({ env }) => ({
  'users-permissions': {
    config: {
      jwtSecret: env('JWT_SECRET'),
      jwt: {
        expiresIn: env('JWT_EXPIRES_IN', '7d'),
      },
      // Champs de profil acceptés à l'inscription (POST /api/auth/local/register).
      // Tout autre champ (role, confirmed, blocked…) est refusé par Strapi.
      register: {
        allowedFields: ['firstName', 'lastName', 'phone', 'university', 'program', 'year'],
      },
    },
  },
});

