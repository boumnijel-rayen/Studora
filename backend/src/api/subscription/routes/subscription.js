'use strict';

module.exports = {
  routes: [
    {
      method: 'GET',
      path: '/subscription/plans',
      handler: 'subscription.plans',
      config: { auth: false },
    },
    {
      method: 'GET',
      path: '/subscription/me',
      handler: 'subscription.me',
    },
    {
      method: 'GET',
      path: '/subscription/history',
      handler: 'subscription.history',
    },
    {
      method: 'POST',
      path: '/subscription/payment-sheet',
      handler: 'subscription.paymentSheet',
    },
    {
      method: 'POST',
      path: '/subscription/change',
      handler: 'subscription.change',
    },
    {
      method: 'POST',
      path: '/subscription/cancel',
      handler: 'subscription.cancel',
    },
    {
      method: 'POST',
      path: '/subscription/resume',
      handler: 'subscription.resume',
    },
    {
      method: 'POST',
      path: '/subscription/sync',
      handler: 'subscription.sync',
    },
    {
      // Authentifié par la signature Stripe (vérifiée dans le contrôleur), pas par JWT.
      method: 'POST',
      path: '/stripe/webhook',
      handler: 'subscription.webhook',
      config: { auth: false },
    },
  ],
};
