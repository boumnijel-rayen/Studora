'use strict';

/**
 * Catalogue des formules d'abonnement et matrice des droits d'accès.
 *
 * SOURCE UNIQUE DE VÉRITÉ pour les règles « plan → fonctionnalités ».
 * - Les prix facturés sont portés par les Stripe Prices (identifiants en variables d'environnement).
 * - Le frontend récupère ce catalogue via `GET /api/subscription/plans` (aucune duplication).
 */

const FEATURES = Object.freeze({
  STUDY_GROUPS: 'studyGroups',
  ROOMMATES: 'roommates',
});

const PLAN_IDS = Object.freeze({
  CORE: 'core',
  PLUS: 'plus',
  ULTIMATE: 'ultimate',
});

const PLANS = Object.freeze([
  {
    id: PLAN_IDS.CORE,
    name: 'Core',
    rank: 0,
    priceMonthly: 0,
    currency: 'usd',
    features: [],
    highlights: [
      'Emploi du temps, échéances et notifications',
      'Sessions d\'étude, tâches et Pomodoro',
      'Suivi des notes et objectifs académiques',
    ],
    stripePriceEnv: null,
  },
  {
    id: PLAN_IDS.PLUS,
    name: 'Plus',
    rank: 1,
    priceMonthly: 9,
    currency: 'usd',
    features: [FEATURES.STUDY_GROUPS],
    highlights: ['Tout le plan Core', 'Groupes d\'étude, discussions et activités'],
    stripePriceEnv: 'STRIPE_PRICE_PLUS',
  },
  {
    id: PLAN_IDS.ULTIMATE,
    name: 'Ultimate',
    rank: 2,
    priceMonthly: 14,
    currency: 'usd',
    features: [FEATURES.STUDY_GROUPS, FEATURES.ROOMMATES],
    highlights: [
      'Tout le plan Plus',
      'Colocation : tâches partagées, dépenses et discussion',
    ],
    stripePriceEnv: 'STRIPE_PRICE_ULTIMATE',
  },
]);

/** Statuts Stripe pour lesquels le plan payant donne accès aux fonctionnalités. */
const ENTITLED_STATUSES = new Set(['active', 'trialing', 'past_due']);

function getPlan(planId) {
  return PLANS.find((p) => p.id === planId) || null;
}

function isPaidPlan(planId) {
  const plan = getPlan(planId);
  return Boolean(plan && plan.priceMonthly > 0);
}

function stripePriceIdFor(planId) {
  const plan = getPlan(planId);
  if (!plan || !plan.stripePriceEnv) return null;
  return process.env[plan.stripePriceEnv] || null;
}

function planIdFromStripePrice(priceId) {
  if (!priceId) return null;
  const plan = PLANS.find((p) => p.stripePriceEnv && process.env[p.stripePriceEnv] === priceId);
  return plan ? plan.id : null;
}

/** Plan minimum (le moins cher) donnant accès à une fonctionnalité. */
function minimumPlanFor(feature) {
  return [...PLANS].sort((a, b) => a.rank - b.rank).find((p) => p.features.includes(feature)) || null;
}

/**
 * Plan effectif d'une ligne `subscription` : un plan payant ne donne accès
 * aux fonctionnalités que si son statut Stripe l'autorise.
 */
function effectivePlanId(subscription) {
  if (!subscription || !subscription.plan) return PLAN_IDS.CORE;
  if (!isPaidPlan(subscription.plan)) return PLAN_IDS.CORE;
  return ENTITLED_STATUSES.has(subscription.status) ? subscription.plan : PLAN_IDS.CORE;
}

function featuresFor(planId) {
  return getPlan(planId)?.features ?? [];
}

function hasFeature(subscription, feature) {
  return featuresFor(effectivePlanId(subscription)).includes(feature);
}

/** Représentation publique du catalogue (sans détails internes). */
function publicCatalog() {
  return PLANS.map(({ stripePriceEnv, ...plan }) => ({
    ...plan,
    purchasable: plan.priceMonthly === 0 || Boolean(process.env[stripePriceEnv]),
  }));
}

module.exports = {
  FEATURES,
  PLAN_IDS,
  PLANS,
  ENTITLED_STATUSES,
  getPlan,
  isPaidPlan,
  stripePriceIdFor,
  planIdFromStripePrice,
  minimumPlanFor,
  effectivePlanId,
  featuresFor,
  hasFeature,
  publicCatalog,
};
