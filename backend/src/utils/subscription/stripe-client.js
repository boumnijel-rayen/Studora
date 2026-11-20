'use strict';

/**
 * Client Stripe unique (singleton) et helpers de lecture des objets Stripe.
 *
 * La clé secrète n'est lue que côté serveur (variable d'environnement
 * `STRIPE_SECRET_KEY`) et n'est JAMAIS exposée à l'application Flutter.
 */
const Stripe = require('stripe');

let client = null;

class StripeNotConfiguredError extends Error {
  constructor() {
    super('Paiements indisponibles : STRIPE_SECRET_KEY n\'est pas configurée sur le serveur.');
    this.name = 'StripeNotConfiguredError';
  }
}

function getStripe() {
  if (client) return client;
  const secretKey = process.env.STRIPE_SECRET_KEY;
  if (!secretKey) throw new StripeNotConfiguredError();
  client = new Stripe(secretKey, {
    maxNetworkRetries: 2,
    timeout: 20000,
    appInfo: { name: 'Studora' },
  });
  return client;
}

/** Permet d'injecter un faux client dans les tests unitaires. */
function setStripeClientForTests(fake) {
  client = fake;
}

function isStripeConfigured() {
  return Boolean(process.env.STRIPE_SECRET_KEY);
}

function toDate(unixSeconds) {
  return typeof unixSeconds === 'number' && unixSeconds > 0
    ? new Date(unixSeconds * 1000).toISOString()
    : null;
}

/**
 * Lecture tolérante aux versions d'API Stripe :
 * depuis 2025-03-31 (basil), les périodes sont portées par les items d'abonnement.
 */
function subscriptionPeriod(subscription) {
  const item = subscription?.items?.data?.[0];
  return {
    start: toDate(item?.current_period_start ?? subscription?.current_period_start),
    end: toDate(item?.current_period_end ?? subscription?.current_period_end),
  };
}

function subscriptionPriceId(subscription) {
  return subscription?.items?.data?.[0]?.price?.id ?? null;
}

function subscriptionProductId(subscription) {
  const prod = subscription?.items?.data?.[0]?.price?.product;
  return typeof prod === 'string' ? prod : prod?.id ?? null;
}

function subscriptionItemId(subscription) {
  return subscription?.items?.data?.[0]?.id ?? null;
}

/** Identifiant d'abonnement d'une facture (ancien et nouveau format d'API). */
function invoiceSubscriptionId(invoice) {
  const fromParent = invoice?.parent?.subscription_details?.subscription;
  const legacy = invoice?.subscription;
  const value = fromParent ?? legacy;
  return typeof value === 'string' ? value : value?.id ?? null;
}

/** `client_secret` du PaymentIntent de la facture (à confirmer dans PaymentSheet). */
function invoiceClientSecret(invoice) {
  if (!invoice || typeof invoice !== 'object') return null;
  return (
    invoice.confirmation_secret?.client_secret ??
    (typeof invoice.payment_intent === 'object' ? invoice.payment_intent?.client_secret : null) ??
    null
  );
}

function idOf(value) {
  if (!value) return null;
  return typeof value === 'string' ? value : value.id ?? null;
}

module.exports = {
  getStripe,
  setStripeClientForTests,
  isStripeConfigured,
  StripeNotConfiguredError,
  toDate,
  subscriptionPeriod,
  subscriptionPriceId,
  subscriptionProductId,
  subscriptionItemId,
  invoiceSubscriptionId,
  invoiceClientSecret,
  idOf,
};
