'use strict';

/**
 * Contrôleur des abonnements : couche HTTP fine, toute la logique est dans le service.
 */
const { requireUser } = require('../../../utils/ownership');
const { publicCatalog, getPlan } = require('../../../utils/subscription/plans');
const {
  getStripe,
  isStripeConfigured,
  StripeNotConfiguredError,
} = require('../../../utils/subscription/stripe-client');

const SERVICE = 'api::subscription.subscription';
const UNPARSED_BODY = Symbol.for('unparsedBody');

function service(strapi) {
  return strapi.service(SERVICE);
}

function readPlanId(ctx) {
  const raw = ctx.request.body?.data || ctx.request.body || {};
  const planId = String(raw.plan || '').trim().toLowerCase();
  return getPlan(planId) ? planId : null;
}

/** Traduit les erreurs Stripe / configuration en réponses HTTP explicites. */
async function withStripeErrors(ctx, strapi, fn) {
  try {
    return await fn();
  } catch (err) {
    if (err instanceof StripeNotConfiguredError) {
      ctx.status = 503;
      ctx.body = { data: null, error: { status: 503, name: 'ServiceUnavailable', message: err.message } };
      return undefined;
    }
    if (err && typeof err.type === 'string' && err.type.startsWith('Stripe')) {
      strapi.log.error(`[subscription] Erreur Stripe (${err.type}) : ${err.message}`);
      if (err.type === 'StripeCardError' || err.type === 'StripeInvalidRequestError') {
        return ctx.badRequest(err.message, { code: 'STRIPE_ERROR' });
      }
      ctx.status = 502;
      ctx.body = {
        data: null,
        error: { status: 502, name: 'BadGateway', message: 'Le service de paiement est momentanément indisponible.' },
      };
      return undefined;
    }
    throw err;
  }
}

module.exports = ({ strapi }) => ({
  /** GET /subscription/plans (public) */
  async plans(ctx) {
    ctx.body = {
      data: publicCatalog(),
      meta: {
        paymentsEnabled: isStripeConfigured(),
        publishableKey: process.env.STRIPE_PUBLISHABLE_KEY || null,
        merchantCountryCode: process.env.STRIPE_MERCHANT_COUNTRY || 'FR',
      },
    };
  },

  /** GET /subscription/me */
  async me(ctx) {
    const user = requireUser(ctx);
    if (!user) return;
    const row = await service(strapi).ensureForUser(user.id);
    ctx.body = { data: service(strapi).serialize(row) };
  },

  /** GET /subscription/history */
  async history(ctx) {
    const user = requireUser(ctx);
    if (!user) return;
    ctx.body = { data: await service(strapi).historyForUser(user.id) };
  },

  /** POST /subscription/payment-sheet { plan } : Core → plan payant */
  async paymentSheet(ctx) {
    const user = requireUser(ctx);
    if (!user) return;
    const planId = readPlanId(ctx);
    if (!planId) return ctx.badRequest('Plan inconnu.');
    return withStripeErrors(ctx, strapi, async () => {
      ctx.body = { data: await service(strapi).createPaymentSheet(user, planId) };
    });
  },

  /** POST /subscription/change { plan } : changement entre plans */
  async change(ctx) {
    const user = requireUser(ctx);
    if (!user) return;
    const planId = readPlanId(ctx);
    if (!planId) return ctx.badRequest('Plan inconnu.');
    return withStripeErrors(ctx, strapi, async () => {
      ctx.body = { data: await service(strapi).changePlan(user, planId) };
    });
  },

  /** POST /subscription/cancel : retour à Core en fin de période */
  async cancel(ctx) {
    const user = requireUser(ctx);
    if (!user) return;
    return withStripeErrors(ctx, strapi, async () => {
      ctx.body = { data: await service(strapi).cancel(user) };
    });
  },

  /** POST /subscription/resume : annule la résiliation programmée */
  async resume(ctx) {
    const user = requireUser(ctx);
    if (!user) return;
    return withStripeErrors(ctx, strapi, async () => {
      ctx.body = { data: await service(strapi).resume(user) };
    });
  },

  /** POST /subscription/sync : relit l'état depuis Stripe (jamais depuis le client) */
  async sync(ctx) {
    const user = requireUser(ctx);
    if (!user) return;
    const raw = ctx.request.body?.data || ctx.request.body || {};
    const subscriptionId =
      typeof raw.subscriptionId === 'string' && raw.subscriptionId.trim()
        ? raw.subscriptionId.trim()
        : null;
    return withStripeErrors(ctx, strapi, async () => {
      ctx.body = {
        data: await service(strapi).syncForUser(user, { subscriptionId }),
      };
    });
  },

  /** POST /stripe/webhook : événements Stripe signés */
  async webhook(ctx) {
    const secret = process.env.STRIPE_WEBHOOK_SECRET;
    if (!secret || !isStripeConfigured()) {
      strapi.log.error('[stripe-webhook] STRIPE_WEBHOOK_SECRET ou STRIPE_SECRET_KEY manquant.');
      ctx.status = 503;
      ctx.body = { received: false };
      return;
    }

    const signature = ctx.request.headers['stripe-signature'];
    const rawBody = ctx.request.body?.[UNPARSED_BODY];
    if (!signature || rawBody === undefined) {
      return ctx.badRequest('Signature Stripe ou corps brut manquant.');
    }

    let event;
    try {
      event = getStripe().webhooks.constructEvent(rawBody, signature, secret);
    } catch (err) {
      strapi.log.warn(`[stripe-webhook] Signature invalide : ${err.message}`);
      return ctx.badRequest('Signature Stripe invalide.');
    }

    try {
      const result = await service(strapi).handleStripeEvent(event);
      ctx.status = 200;
      ctx.body = { received: true, ...result };
    } catch (err) {
      // Réponse 500 : Stripe relivrera l'événement automatiquement (retries exponentiels).
      strapi.log.error(`[stripe-webhook] Échec du traitement de ${event.type} (${event.id}) : ${err.message}`);
      ctx.status = 500;
      ctx.body = { received: false };
    }
  },
});
