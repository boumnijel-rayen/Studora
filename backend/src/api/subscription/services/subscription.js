'use strict';

/**
 * Service métier des abonnements (seul point d'écriture de la table `subscriptions`).
 *
 * Règle de sécurité : le plan d'un utilisateur n'est JAMAIS modifié à partir d'une
 * donnée envoyée par le client. Toute écriture provient d'un objet Stripe récupéré
 * côté serveur (webhook vérifié ou appel direct à l'API Stripe).
 */
const { createCoreService } = require('@strapi/strapi').factories;
const { errors } = require('@strapi/utils');
const {
  PLAN_IDS,
  ENTITLED_STATUSES,
  getPlan,
  isPaidPlan,
  stripePriceIdFor,
  planIdFromStripePrice,
  effectivePlanId,
  featuresFor,
} = require('../../../utils/subscription/plans');
const {
  getStripe,
  toDate,
  subscriptionPeriod,
  subscriptionPriceId,
  subscriptionProductId,
  invoiceSubscriptionId,
  invoiceClientSecret,
  idOf,
} = require('../../../utils/subscription/stripe-client');

const UID = 'api::subscription.subscription';
const EVENT_UID = 'api::subscription-event.subscription-event';
const resolvedPriceCache = new Map();
const prorationCouponCache = new Map();

/** Correspondance statut Stripe → statut applicatif. */
function mapStripeStatus(stripeStatus) {
  switch (stripeStatus) {
    case 'active':
    case 'trialing':
    case 'past_due':
    case 'incomplete':
    case 'unpaid':
    case 'paused':
    case 'canceled':
      return stripeStatus;
    case 'incomplete_expired':
      return 'expired';
    default:
      return 'incomplete';
  }
}

function isEntitled(row) {
  return Boolean(row && isPaidPlan(row.plan) && ENTITLED_STATUSES.has(row.status));
}

module.exports = createCoreService(UID, ({ strapi }) => ({
  // ---------------------------------------------------------------------------
  // Lecture
  // ---------------------------------------------------------------------------

  async findForUser(userId) {
    return strapi.documents(UID).findFirst({ filters: { owner: { id: userId } } });
  },

  async findByStripeIds({ subscriptionId, customerId }) {
    if (subscriptionId) {
      const bySub = await strapi.documents(UID).findFirst({
        filters: { stripeSubscriptionId: subscriptionId },
        populate: { owner: true },
      });
      if (bySub) return bySub;
    }
    if (customerId) {
      return strapi.documents(UID).findFirst({
        filters: { stripeCustomerId: customerId },
        populate: { owner: true },
      });
    }
    return null;
  },

  /** Ligne d'abonnement de l'utilisateur, créée en plan Core si elle n'existe pas. */
  async ensureForUser(userId) {
    const existing = await this.findForUser(userId);
    if (existing) return existing;
    return strapi.documents(UID).create({
      data: { owner: userId, plan: PLAN_IDS.CORE, status: 'active', cancelAtPeriodEnd: false },
    });
  },

  /** Droits d'accès effectifs (utilisé par la policy `require-feature`). */
  async getAccessForUser(userId) {
    const row = await this.findForUser(userId);
    const plan = effectivePlanId(row);
    return { plan, status: row?.status ?? 'active', features: featuresFor(plan) };
  },

  /** Représentation renvoyée au frontend (aucun identifiant Stripe sensible exposé). */
  serialize(row) {
    const plan = effectivePlanId(row);
    const status = row?.status ?? 'active';
    const entitled = isEntitled(row);
    const cancelAtPeriodEnd = Boolean(row?.cancelAtPeriodEnd);
    const periodEnd = row?.currentPeriodEnd ?? null;
    return {
      plan,
      subscribedPlan: row?.plan ?? PLAN_IDS.CORE,
      status,
      features: featuresFor(plan),
      cancelAtPeriodEnd,
      pendingPlan: row?.pendingPlan ?? null,
      currentPeriodStart: row?.currentPeriodStart ?? null,
      currentPeriodEnd: periodEnd,
      renewsAt: entitled && !cancelAtPeriodEnd ? periodEnd : null,
      accessEndsAt: entitled && cancelAtPeriodEnd ? periodEnd : null,
      canceledAt: row?.canceledAt ?? null,
      endedAt: row?.endedAt ?? null,
      lastPaymentError: row?.lastPaymentError ?? null,
      paymentPending: status === 'incomplete',
    };
  },

  // ---------------------------------------------------------------------------
  // Actions utilisateur (déclenchées par l'application, exécutées côté Stripe)
  // ---------------------------------------------------------------------------

  /**
   * Résout l'identifiant de tarif Stripe (`price_...`) d'un plan payant.
   * Si la variable d'environnement contient un identifiant de produit (`prod_...`),
   * récupère automatiquement son tarif récurrent mensuel actif (ou le crée s'il n'existe pas).
   */
  async resolveStripePriceId(planId) {
    const raw = stripePriceIdFor(planId);
    if (!raw) return null;
    if (raw.startsWith('price_')) return raw;
    if (resolvedPriceCache.has(raw)) return resolvedPriceCache.get(raw);

    if (raw.startsWith('prod_')) {
      const stripe = getStripe();
      const prices = await stripe.prices.list({
        product: raw,
        active: true,
        type: 'recurring',
        limit: 10,
      });
      const monthly =
        prices.data.find((p) => p.recurring?.interval === 'month') || prices.data[0];
      if (monthly) {
        resolvedPriceCache.set(raw, monthly.id);
        return monthly.id;
      }

      const plan = getPlan(planId);
      const created = await stripe.prices.create({
        product: raw,
        unit_amount: plan.priceMonthly * 100,
        currency: plan.currency || 'usd',
        recurring: { interval: 'month' },
      });
      resolvedPriceCache.set(raw, created.id);
      return created.id;
    }

    return raw;
  },

  async ensureStripeCustomer(user, row) {
    if (row.stripeCustomerId) return row.stripeCustomerId;
    const stripe = getStripe();
    const name = `${user.firstName || ''} ${user.lastName || ''}`.trim() || undefined;
    const customer = await stripe.customers.create(
      { email: user.email, name, metadata: { userId: String(user.id) } },
      { idempotencyKey: `studora-customer-${user.id}` },
    );
    await strapi.documents(UID).update({
      documentId: row.documentId,
      data: { stripeCustomerId: customer.id },
    });
    row.stripeCustomerId = customer.id;
    return customer.id;
  },

  /**
   * Nettoie les abonnements `incomplete` précédemment abandonnés par ce client
   * afin de toujours repartir sur une session de paiement Stripe neuve.
   */
  async cancelIncompleteSubscriptionsForCustomer(customerId) {
    if (!customerId) return;
    const stripe = getStripe();
    try {
      const existing = await stripe.subscriptions.list({
        customer: customerId,
        status: 'incomplete',
        limit: 10,
      });
      for (const sub of existing.data) {
        try {
          await stripe.subscriptions.cancel(sub.id);
        } catch (_) {}
      }
    } catch (err) {
      strapi.log.warn(`[subscription] Nettoyage des abonnements incomplets ignoré : ${err.message}`);
    }
  },

  /**
   * Récupère ou crée un coupon Stripe unique (`duration: 'once'`) permettant d'appliquer
   * la facturation au prorata lors d'un passage vers un plan supérieur :
   * l'utilisateur ne paie que la différence de prix (`targetPlan.priceMonthly - currentPlan.priceMonthly`)
   * sur la première échéance (ex. Plus 9 USD → Ultimate 14 USD : réduction de 9 USD, facturé 5 USD),
   * puis le renouvellement mensuel suivant se fait au tarif normal du nouveau plan (14 USD).
   */
  async resolveUpgradeProrationCouponId(currentPlan, targetPlan) {
    if (!currentPlan || !targetPlan || targetPlan.rank <= currentPlan.rank) return null;
    const creditCents = Math.round(currentPlan.priceMonthly * 100);
    const diffCents = Math.round((targetPlan.priceMonthly - currentPlan.priceMonthly) * 100);
    if (creditCents <= 0 || diffCents <= 0) return null;

    const currency = (targetPlan.currency || 'usd').toLowerCase();
    const couponId = `studora_prorata_${currentPlan.id}_to_${targetPlan.id}_${creditCents}_${currency}`;
    if (prorationCouponCache.has(couponId)) {
      return prorationCouponCache.get(couponId);
    }

    const stripe = getStripe();
    try {
      const existing = await stripe.coupons.retrieve(couponId);
      if (existing && existing.valid !== false) {
        prorationCouponCache.set(couponId, existing.id);
        return existing.id;
      }
    } catch (_) {
      // Le coupon n'existe pas encore sur ce compte Stripe : on le crée ci-dessous.
    }

    const created = await stripe.coupons.create({
      id: couponId,
      amount_off: creditCents,
      currency,
      duration: 'once',
      name: `Prorata ${currentPlan.name} vers ${targetPlan.name}`,
    });
    prorationCouponCache.set(couponId, created.id);
    return created.id;
  },

  /**
   * Crée une NOUVELLE session de paiement Stripe (abonnement `default_incomplete` +
   * `PaymentIntent` neuf) pour souscrire ou changer vers un plan payant (`plus` ou `ultimate`).
   *
   * - Ne réutilise jamais automatiquement une ancienne carte ou session de paiement :
   *   l'application Flutter reçoit toujours un `clientSecret` neuf et ouvre la PaymentSheet.
   * - Lors d'un passage à un plan supérieur depuis un abonnement actif (ex. Plus 9 USD → Ultimate 14 USD),
   *   applique automatiquement une remise au prorata de la valeur du plan actuel afin de ne facturer
   *   que la différence de prix (ex. 5 USD).
   * - Si l'utilisateur possédait déjà un abonnement payant actif, celui-ci reste intact tant
   *   que le nouveau paiement n'est pas confirmé, puis est automatiquement remplacé et annulé.
   */
  async createPaymentSheet(user, planId) {
    if (!isPaidPlan(planId)) {
      throw new errors.ValidationError('Le plan demandé n\'est pas un plan payant.');
    }
    const targetPlan = getPlan(planId);
    const priceId = await this.resolveStripePriceId(planId);
    if (!priceId) {
      throw new errors.ApplicationError(`Le plan ${targetPlan.name} n'est pas configuré sur le serveur.`);
    }

    const stripe = getStripe();
    const row = await this.ensureForUser(user.id);
    const customerId = await this.ensureStripeCustomer(user, row);

    // Annule toute tentative de paiement incomplète précédente pour repartir d'une session propre.
    await this.cancelIncompleteSubscriptionsForCustomer(customerId);

    const currentPlan = getPlan(effectivePlanId(row));
    const isProratedUpgrade = Boolean(
      isEntitled(row) &&
        currentPlan &&
        targetPlan &&
        targetPlan.rank > currentPlan.rank &&
        currentPlan.priceMonthly > 0,
    );
    const prorationCouponId = isProratedUpgrade
      ? await this.resolveUpgradeProrationCouponId(currentPlan, targetPlan)
      : null;

    const replacesSubscriptionId =
      isEntitled(row) && row.stripeSubscriptionId ? row.stripeSubscriptionId : '';

    const subscription = await stripe.subscriptions.create({
      customer: customerId,
      items: [{ price: priceId }],
      ...(prorationCouponId ? { discounts: [{ coupon: prorationCouponId }] } : {}),
      payment_behavior: 'default_incomplete',
      payment_settings: {
        payment_method_types: ['card'],
      },
      metadata: {
        userId: String(user.id),
        plan: planId,
        ...(replacesSubscriptionId ? { replacesSubscriptionId } : {}),
        ...(isProratedUpgrade
          ? {
              proratedFromPlan: currentPlan.id,
              proratedCreditAmount: String(currentPlan.priceMonthly),
              proratedChargedAmount: String(targetPlan.priceMonthly - currentPlan.priceMonthly),
            }
          : {}),
      },
      expand: ['latest_invoice.confirmation_secret'],
    });

    const clientSecret = invoiceClientSecret(subscription.latest_invoice);
    if (!clientSecret) {
      throw new errors.ApplicationError('Stripe n\'a pas renvoyé de paiement à confirmer.');
    }

    // Si l'utilisateur n'avait pas d'abonnement actif (plan Core), on enregistre l'état `incomplete`.
    // S'il avait déjà un plan payant actif, on ne l'écrase PAS tant que le nouveau paiement n'est pas validé.
    if (!isEntitled(row)) {
      await strapi.documents(UID).update({
        documentId: row.documentId,
        data: { stripeSubscriptionId: subscription.id },
      });
      await this.applyStripeSubscription(subscription, { source: 'payment-sheet' });
    }

    const chargedAmount = isProratedUpgrade
      ? targetPlan.priceMonthly - currentPlan.priceMonthly
      : targetPlan.priceMonthly;

    return {
      requiresPayment: true,
      clientSecret,
      subscriptionId: subscription.id,
      customerId,
      plan: planId,
      prorated: isProratedUpgrade,
      chargedAmount,
      creditAmount: isProratedUpgrade ? currentPlan.priceMonthly : 0,
      publishableKey: process.env.STRIPE_PUBLISHABLE_KEY || null,
    };
  },

  /**
   * Changement de plan :
   * - Vers un plan payant (`plus` ou `ultimate`) : crée systématiquement une nouvelle
   *   interface de paiement Stripe (`createPaymentSheet`) pour que l'utilisateur valide
   *   son paiement dans la PaymentSheet sans réutiliser silencieusement l'ancienne session.
   * - Vers le plan gratuit `core` : programme l'annulation à la fin de la période en cours.
   */
  async changePlan(user, targetPlanId) {
    if (!getPlan(targetPlanId)) {
      throw new errors.ValidationError('Plan inconnu.');
    }
    if (targetPlanId === PLAN_IDS.CORE) {
      return { requiresPayment: false, subscription: await this.cancel(user) };
    }

    const row = await this.ensureForUser(user.id);
    if (isEntitled(row) && row.plan === targetPlanId && row.cancelAtPeriodEnd) {
      return { requiresPayment: false, subscription: await this.resume(user) };
    }

    return this.createPaymentSheet(user, targetPlanId);
  },

  /** Retour au plan Core en fin de période payée. */
  async cancel(user) {
    const row = await this.ensureForUser(user.id);
    if (!isEntitled(row) || !row.stripeSubscriptionId) {
      throw new errors.ValidationError('Vous êtes déjà sur le plan gratuit Core.');
    }
    const updated = await getStripe().subscriptions.update(row.stripeSubscriptionId, {
      cancel_at_period_end: true,
    });
    return this.serialize(await this.applyStripeSubscription(updated, { source: 'cancel' }));
  },

  /** Annule une résiliation programmée. */
  async resume(user) {
    const row = await this.ensureForUser(user.id);
    if (!row.stripeSubscriptionId || !row.cancelAtPeriodEnd) {
      throw new errors.ValidationError('Aucune résiliation programmée à annuler.');
    }
    const updated = await getStripe().subscriptions.update(row.stripeSubscriptionId, {
      cancel_at_period_end: false,
    });
    return this.serialize(await this.applyStripeSubscription(updated, { source: 'resume' }));
  },

  /**
   * Resynchronisation à la demande : l'état est relu DEPUIS Stripe par le serveur
   * (utile juste après la PaymentSheet si le webhook n'est pas encore arrivé).
   */
  async syncForUser(user, { subscriptionId = null } = {}) {
    const row = await this.ensureForUser(user.id);
    if (!row.stripeCustomerId && !subscriptionId) return this.serialize(row);

    const stripe = getStripe();
    let subscription = null;

    if (subscriptionId) {
      try {
        const candidate = await stripe.subscriptions.retrieve(subscriptionId);
        const candidateCustomerId = idOf(candidate.customer);
        if (
          candidate.metadata?.userId === String(user.id) ||
          (row.stripeCustomerId && candidateCustomerId === row.stripeCustomerId)
        ) {
          subscription = candidate;
        }
      } catch (err) {
        strapi.log.warn(`[subscription] Impossible de relire l'abonnement ${subscriptionId} : ${err.message}`);
      }
    }

    if (!subscription && row.stripeCustomerId) {
      const list = await stripe.subscriptions.list({
        customer: row.stripeCustomerId,
        status: 'all',
        limit: 10,
      });
      // Priorise l'abonnement actif le plus récent
      const priority = ['active', 'trialing', 'past_due', 'incomplete', 'unpaid'];
      subscription =
        priority.map((s) => list.data.find((sub) => sub.status === s)).find(Boolean) || null;
    }

    if (!subscription && row.stripeSubscriptionId) {
      try {
        subscription = await stripe.subscriptions.retrieve(row.stripeSubscriptionId);
      } catch (_) {}
    }

    if (!subscription) return this.serialize(row);
    return this.serialize(await this.applyStripeSubscription(subscription, { source: 'sync' }));
  },

  // ---------------------------------------------------------------------------
  // Synchronisation Stripe → base de données
  // ---------------------------------------------------------------------------

  async resolveUserIdForStripe({ metadataUserId, subscriptionId, customerId }) {
    const row = await this.findByStripeIds({ subscriptionId, customerId });
    if (row?.owner?.id) return row.owner.id;
    const parsed = Number.parseInt(metadataUserId, 10);
    if (Number.isInteger(parsed) && parsed > 0) {
      const user = await strapi.db
        .query('plugin::users-permissions.user')
        .findOne({ where: { id: parsed }, select: ['id'] });
      if (user) return user.id;
    }
    return null;
  },

  /**
   * Applique l'état d'un abonnement Stripe à la ligne locale (idempotent).
   * Si un nouvel abonnement payé remplace un ancien abonnement actif, annule
   * automatiquement l'ancien abonnement sur Stripe pour éviter toute double facturation.
   */
  async applyStripeSubscription(subscription, { source = 'webhook', eventId = null } = {}) {
    const customerId = idOf(subscription.customer);
    const userId = await this.resolveUserIdForStripe({
      metadataUserId: subscription.metadata?.userId,
      subscriptionId: subscription.id,
      customerId,
    });
    if (!userId) {
      strapi.log.warn(`[subscription] Utilisateur introuvable pour l'abonnement Stripe ${subscription.id}.`);
      return null;
    }

    const row = await this.ensureForUser(userId);
    const previousPlan = effectivePlanId(row);
    const subscriptionEntitles = ENTITLED_STATUSES.has(subscription.status);

    // Si l'événement concerne un autre abonnement qui N'EST PAS actif (ex. tentative incomplete
    // ou annulation de l'ancien abonnement après remplacement), on ne touche pas à l'abonnement actuel.
    if (
      row.stripeSubscriptionId &&
      row.stripeSubscriptionId !== subscription.id &&
      !subscriptionEntitles
    ) {
      strapi.log.info(
        `[subscription] Événement non actif (${subscription.status}) ignoré pour ${subscription.id} (actuel : ${row.stripeSubscriptionId}).`,
      );
      return row;
    }

    // Si un nouvel abonnement devient actif alors qu'un ancien abonnement était enregistré,
    // on annule l'ancien abonnement côté Stripe pour qu'il ne soit plus jamais facturé.
    const oldSubId =
      row.stripeSubscriptionId && row.stripeSubscriptionId !== subscription.id
        ? row.stripeSubscriptionId
        : subscription.metadata?.replacesSubscriptionId || null;

    if (subscriptionEntitles && oldSubId && oldSubId !== subscription.id) {
      try {
        await getStripe().subscriptions.cancel(oldSubId);
        strapi.log.info(`[subscription] Ancien abonnement ${oldSubId} annulé après remplacement par ${subscription.id}.`);
      } catch (err) {
        strapi.log.debug(`[subscription] Annulation de l'ancien abonnement ${oldSubId} ignorée : ${err.message}`);
      }
    }

    const priceId = subscriptionPriceId(subscription);
    const productId = subscriptionProductId(subscription);
    const planFromPrice =
      planIdFromStripePrice(priceId) ||
      planIdFromStripePrice(productId) ||
      subscription.metadata?.plan ||
      row.plan;
    const status = mapStripeStatus(subscription.status);
    const period = subscriptionPeriod(subscription);
    let data;

    if (status === 'canceled' || status === 'expired') {
      const wasAbandoned = row.status === 'incomplete' || subscription.status === 'incomplete_expired';
      const endedAt = toDate(subscription.ended_at) || new Date().toISOString();
      const endedAtPeriodEnd =
        subscription.cancel_at_period_end ||
        (period.end && new Date(endedAt).getTime() >= new Date(period.end).getTime() - 60_000);
      data = {
        plan: PLAN_IDS.CORE,
        status: wasAbandoned ? 'active' : endedAtPeriodEnd ? 'expired' : 'canceled',
        pendingPlan: null,
        cancelAtPeriodEnd: false,
        stripeSubscriptionId: null,
        stripePriceId: null,
        currentPeriodStart: wasAbandoned ? row.currentPeriodStart : period.start,
        currentPeriodEnd: wasAbandoned ? row.currentPeriodEnd : period.end,
        canceledAt: wasAbandoned ? row.canceledAt : toDate(subscription.canceled_at) || endedAt,
        endedAt: wasAbandoned ? row.endedAt : endedAt,
      };
    } else {
      data = {
        plan: planFromPrice,
        status,
        pendingPlan: subscription.cancel_at_period_end ? PLAN_IDS.CORE : null,
        cancelAtPeriodEnd: Boolean(subscription.cancel_at_period_end),
        stripeSubscriptionId: subscription.id,
        stripePriceId: priceId,
        currentPeriodStart: period.start,
        currentPeriodEnd: period.end,
        canceledAt: toDate(subscription.canceled_at),
        endedAt: null,
        ...(status === 'active' || status === 'trialing' ? { lastPaymentError: null } : {}),
      };
    }

    if (customerId && !row.stripeCustomerId) data.stripeCustomerId = customerId;

    const saved = await strapi.documents(UID).update({ documentId: row.documentId, data });
    const newPlan = effectivePlanId(saved);

    if (newPlan !== previousPlan) {
      await this.recordEvent({
        type: 'plan.changed',
        userId,
        plan: newPlan,
        previousPlan,
        status: saved.status,
        occurredAt: new Date().toISOString(),
      });
      strapi.log.info(`[subscription] Utilisateur ${userId} : ${previousPlan} → ${newPlan} (${source}).`);
    }

    return saved;
  },

  async markPaymentFailed(invoice) {
    const subscriptionId = invoiceSubscriptionId(invoice);
    const row = await this.findByStripeIds({ subscriptionId, customerId: idOf(invoice.customer) });
    if (!row) return;
    const message =
      invoice.last_finalization_error?.message ||
      'Le paiement de votre abonnement a échoué. Mettez à jour votre carte bancaire.';
    await strapi.documents(UID).update({
      documentId: row.documentId,
      data: { lastPaymentError: message.slice(0, 250) },
    });
  },

  // ---------------------------------------------------------------------------
  // Historique & idempotence des webhooks
  // ---------------------------------------------------------------------------

  async isEventProcessed(stripeEventId) {
    if (!stripeEventId) return false;
    const existing = await strapi.documents(EVENT_UID).findFirst({ filters: { stripeEventId } });
    return Boolean(existing);
  },

  async recordEvent({
    stripeEventId = null,
    type,
    userId = null,
    plan = null,
    previousPlan = null,
    status = null,
    amount = null,
    currency = null,
    stripeInvoiceId = null,
    occurredAt = new Date().toISOString(),
  }) {
    try {
      await strapi.documents(EVENT_UID).create({
        data: {
          stripeEventId,
          type,
          owner: userId,
          plan,
          previousPlan,
          status,
          amount,
          currency,
          stripeInvoiceId,
          occurredAt,
        },
      });
    } catch (err) {
      strapi.log.debug(`[subscription] Événement non enregistré (${type}) : ${err.message}`);
    }
  },

  /** Historique visible par l'utilisateur. */
  async historyForUser(userId, limit = 20) {
    const events = await strapi.documents(EVENT_UID).findMany({
      filters: { owner: { id: userId } },
      sort: { occurredAt: 'desc' },
      limit,
    });
    return events.map((e) => ({
      type: e.type,
      plan: e.plan,
      previousPlan: e.previousPlan,
      status: e.status,
      amount: e.amount,
      currency: e.currency,
      occurredAt: e.occurredAt,
    }));
  },

  // ---------------------------------------------------------------------------
  // Webhooks Stripe (signature déjà vérifiée par le contrôleur)
  // ---------------------------------------------------------------------------

  async handleStripeEvent(event) {
    if (await this.isEventProcessed(event.id)) {
      return { duplicate: true };
    }

    const stripe = getStripe();
    const object = event.data?.object || {};
    let userId = null;
    let extra = {};

    switch (event.type) {
      case 'customer.subscription.created':
      case 'customer.subscription.updated':
      case 'customer.subscription.paused':
      case 'customer.subscription.resumed': {
        const fresh = await stripe.subscriptions.retrieve(object.id);
        const saved = await this.applyStripeSubscription(fresh, { eventId: event.id });
        userId = saved?.owner?.id ?? (await this.resolveUserIdForStripe({
          metadataUserId: fresh.metadata?.userId,
          subscriptionId: fresh.id,
          customerId: idOf(fresh.customer),
        }));
        extra = { plan: saved ? effectivePlanId(saved) : null, status: fresh.status };
        break;
      }
      case 'customer.subscription.deleted': {
        const saved = await this.applyStripeSubscription(object, { eventId: event.id });
        userId = await this.resolveUserIdForStripe({
          metadataUserId: object.metadata?.userId,
          customerId: idOf(object.customer),
        });
        extra = { plan: saved ? effectivePlanId(saved) : PLAN_IDS.CORE, status: object.status };
        break;
      }
      case 'invoice.paid':
      case 'invoice.payment_failed':
      case 'invoice.payment_action_required': {
        const subscriptionId = invoiceSubscriptionId(object);
        userId = await this.resolveUserIdForStripe({
          subscriptionId,
          customerId: idOf(object.customer),
        });
        if (event.type === 'invoice.payment_failed') {
          await this.markPaymentFailed(object);
        }
        if (subscriptionId) {
          const fresh = await stripe.subscriptions.retrieve(subscriptionId);
          await this.applyStripeSubscription(fresh, { eventId: event.id });
        }
        extra = {
          status: object.status,
          amount: event.type === 'invoice.paid' ? object.amount_paid : object.amount_due,
          currency: object.currency,
          stripeInvoiceId: object.id,
        };
        break;
      }
      default:
        return { ignored: true };
    }

    await this.recordEvent({
      stripeEventId: event.id,
      type: event.type,
      userId,
      occurredAt: toDate(event.created) || new Date().toISOString(),
      ...extra,
    });
    return { processed: true };
  },
}));
