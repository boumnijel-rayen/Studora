'use strict';

/**
 * Policy centrale de contrôle d'accès par abonnement.
 *
 * Exécutée APRÈS l'authentification JWT : refuse (403) tout appel à une API
 * dont la fonctionnalité n'est pas incluse dans le plan effectif de l'utilisateur.
 * Les règles « plan → fonctionnalités » sont définies dans utils/subscription/plans.js.
 */
const { errors } = require('@strapi/utils');
const { getPlan, minimumPlanFor } = require('../utils/subscription/plans');

const UPGRADE_CODE = 'PLAN_UPGRADE_REQUIRED';

module.exports = async (policyContext, config, { strapi }) => {
  const feature = config?.feature;
  if (!feature) {
    strapi.log.error('[require-feature] Policy utilisée sans fonctionnalité configurée.');
    return false;
  }

  const user = policyContext.state?.user;
  if (!user) {
    // L'authentification est gérée en amont : sans utilisateur, on refuse.
    return false;
  }

  const access = await strapi
    .service('api::subscription.subscription')
    .getAccessForUser(user.id);

  if (access.features.includes(feature)) {
    return true;
  }

  const requiredPlan = minimumPlanFor(feature);
  const currentPlan = getPlan(access.plan);
  throw new errors.PolicyError(
    `Cette fonctionnalité nécessite le plan ${requiredPlan?.name ?? 'supérieur'}.`,
    {
      code: UPGRADE_CODE,
      feature,
      currentPlan: currentPlan?.id ?? 'core',
      requiredPlan: requiredPlan?.id ?? null,
    },
  );
};

module.exports.UPGRADE_CODE = UPGRADE_CODE;
