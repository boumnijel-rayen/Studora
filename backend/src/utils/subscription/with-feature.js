'use strict';

/**
 * Attache la policy `global::require-feature` à toutes les routes d'un routeur Strapi.
 *
 * Usage dans un fichier `routes/*.js` :
 *   module.exports = requireFeature(FEATURES.STUDY_GROUPS, createCoreRouter(UID));
 *
 * Fonctionne avec les routeurs générés (`createCoreRouter`, routes calculées à la demande)
 * comme avec les routeurs personnalisés (`{ routes: [...] }`).
 */
function addPolicy(route, feature) {
  const config = route.config || {};
  const policies = Array.isArray(config.policies) ? config.policies : [];
  const alreadyGuarded = policies.some(
    (p) => p && typeof p === 'object' && p.name === 'global::require-feature',
  );
  return {
    ...route,
    config: {
      ...config,
      policies: alreadyGuarded
        ? policies
        : [...policies, { name: 'global::require-feature', config: { feature } }],
    },
  };
}

function requireFeature(feature, router) {
  if (!feature) throw new Error('requireFeature : fonctionnalité manquante.');
  let cached = null;
  return {
    type: router.type,
    prefix: router.prefix,
    get routes() {
      if (!cached) {
        cached = (router.routes || []).map((route) => addPolicy(route, feature));
      }
      return cached;
    },
  };
}

module.exports = { requireFeature };
