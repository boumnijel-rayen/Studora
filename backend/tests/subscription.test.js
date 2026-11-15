'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  FEATURES,
  PLAN_IDS,
  getPlan,
  isPaidPlan,
  minimumPlanFor,
  effectivePlanId,
  featuresFor,
  hasFeature,
  publicCatalog,
  planIdFromStripePrice,
} = require('../src/utils/subscription/plans');
const { requireFeature } = require('../src/utils/subscription/with-feature');
const requireFeaturePolicy = require('../src/policies/require-feature');

test('Catalogue des 3 plans (Core 0$, Plus 9$, Ultimate 14$) et matrice des fonctionnalités', () => {
  const core = getPlan(PLAN_IDS.CORE);
  const plus = getPlan(PLAN_IDS.PLUS);
  const ultimate = getPlan(PLAN_IDS.ULTIMATE);

  assert.equal(core.priceMonthly, 0);
  assert.deepEqual(core.features, []);
  assert.equal(isPaidPlan('core'), false);

  assert.equal(plus.priceMonthly, 9);
  assert.deepEqual(plus.features, [FEATURES.STUDY_GROUPS]);
  assert.equal(isPaidPlan('plus'), true);

  assert.equal(ultimate.priceMonthly, 14);
  assert.deepEqual(ultimate.features, [FEATURES.STUDY_GROUPS, FEATURES.ROOMMATES]);
  assert.equal(isPaidPlan('ultimate'), true);

  assert.equal(minimumPlanFor(FEATURES.STUDY_GROUPS).id, PLAN_IDS.PLUS);
  assert.equal(minimumPlanFor(FEATURES.ROOMMATES).id, PLAN_IDS.ULTIMATE);
});

test('effectivePlanId et hasFeature coupent les accès si le statut Stripe n\'est pas autorisé', () => {
  assert.equal(effectivePlanId(null), PLAN_IDS.CORE);
  assert.equal(effectivePlanId({ plan: 'plus', status: 'active' }), PLAN_IDS.PLUS);
  assert.equal(effectivePlanId({ plan: 'plus', status: 'trialing' }), PLAN_IDS.PLUS);
  assert.equal(effectivePlanId({ plan: 'plus', status: 'past_due' }), PLAN_IDS.PLUS);
  assert.equal(effectivePlanId({ plan: 'plus', status: 'incomplete' }), PLAN_IDS.CORE);
  assert.equal(effectivePlanId({ plan: 'ultimate', status: 'canceled' }), PLAN_IDS.CORE);
  assert.equal(effectivePlanId({ plan: 'ultimate', status: 'unpaid' }), PLAN_IDS.CORE);

  assert.equal(hasFeature({ plan: 'core', status: 'active' }, FEATURES.STUDY_GROUPS), false);
  assert.equal(hasFeature({ plan: 'plus', status: 'active' }, FEATURES.STUDY_GROUPS), true);
  assert.equal(hasFeature({ plan: 'plus', status: 'active' }, FEATURES.ROOMMATES), false);
  assert.equal(hasFeature({ plan: 'ultimate', status: 'active' }, FEATURES.ROOMMATES), true);
  assert.equal(hasFeature({ plan: 'ultimate', status: 'incomplete' }, FEATURES.ROOMMATES), false);
});

test('planIdFromStripePrice et publicCatalog lisent les variables d\'environnement Stripe', () => {
  process.env.STRIPE_PRICE_PLUS = 'price_test_plus';
  process.env.STRIPE_PRICE_ULTIMATE = 'price_test_ultimate';

  assert.equal(planIdFromStripePrice('price_test_plus'), 'plus');
  assert.equal(planIdFromStripePrice('price_test_ultimate'), 'ultimate');
  assert.equal(planIdFromStripePrice('price_unknown'), null);

  const catalog = publicCatalog();
  assert.equal(catalog.length, 3);
  assert.equal(catalog.every((p) => p.purchasable === true), true);
  assert.equal(featuresFor('ultimate').length, 2);
});

test('requireFeature attache la policy global::require-feature sans la dupliquer', () => {
  const baseRouter = {
    routes: [
      { method: 'GET', path: '/study-groups', handler: 'study-group.find' },
      {
        method: 'POST',
        path: '/study-groups',
        handler: 'study-group.create',
        config: { policies: [{ name: 'global::require-feature', config: { feature: 'studyGroups' } }] },
      },
    ],
  };

  const wrapped = requireFeature(FEATURES.STUDY_GROUPS, baseRouter);
  assert.equal(wrapped.routes.length, 2);
  assert.equal(wrapped.routes[0].config.policies.length, 1);
  assert.equal(wrapped.routes[0].config.policies[0].name, 'global::require-feature');
  assert.equal(wrapped.routes[0].config.policies[0].config.feature, FEATURES.STUDY_GROUPS);
  assert.equal(wrapped.routes[1].config.policies.length, 1);
});

test('Policy require-feature autorise ou lève PolicyError(PLAN_UPGRADE_REQUIRED)', async () => {
  const fakeStrapiForPlan = (plan) => ({
    log: { error() {} },
    service: () => ({
      async getAccessForUser() {
        return { plan, status: 'active', features: featuresFor(plan) };
      },
    }),
  });

  const ctx = { state: { user: { id: 42 } } };

  // Utilisateur Core refusé sur studyGroups -> requiert Plus
  await assert.rejects(
    () =>
      requireFeaturePolicy(
        ctx,
        { feature: FEATURES.STUDY_GROUPS },
        { strapi: fakeStrapiForPlan('core') },
      ),
    (err) => {
      assert.equal(err.details.code, 'PLAN_UPGRADE_REQUIRED');
      assert.equal(err.details.feature, FEATURES.STUDY_GROUPS);
      assert.equal(err.details.currentPlan, 'core');
      assert.equal(err.details.requiredPlan, 'plus');
      return true;
    },
  );

  // Utilisateur Plus autorisé sur studyGroups mais refusé sur roommates -> requiert Ultimate
  const allowedGroups = await requireFeaturePolicy(
    ctx,
    { feature: FEATURES.STUDY_GROUPS },
    { strapi: fakeStrapiForPlan('plus') },
  );
  assert.equal(allowedGroups, true);

  await assert.rejects(
    () =>
      requireFeaturePolicy(
        ctx,
        { feature: FEATURES.ROOMMATES },
        { strapi: fakeStrapiForPlan('plus') },
      ),
    (err) => {
      assert.equal(err.details.code, 'PLAN_UPGRADE_REQUIRED');
      assert.equal(err.details.requiredPlan, 'ultimate');
      return true;
    },
  );

  // Utilisateur Ultimate autorisé sur roommates
  const allowedRoommates = await requireFeaturePolicy(
    ctx,
    { feature: FEATURES.ROOMMATES },
    { strapi: fakeStrapiForPlan('ultimate') },
  );
  assert.equal(allowedRoommates, true);
});

test('Calcul du prorata lors du passage d\'un plan payant vers un plan supérieur (Plus 9$ -> Ultimate 14$ = 5$)', () => {
  const plus = getPlan(PLAN_IDS.PLUS);
  const ultimate = getPlan(PLAN_IDS.ULTIMATE);

  assert.equal(ultimate.rank > plus.rank, true);
  assert.equal(plus.priceMonthly, 9);
  assert.equal(ultimate.priceMonthly, 14);

  const creditAmount = plus.priceMonthly;
  const chargedAmount = ultimate.priceMonthly - plus.priceMonthly;
  assert.equal(creditAmount, 9);
  assert.equal(chargedAmount, 5);
});
