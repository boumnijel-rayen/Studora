'use strict';

const { createCoreController } = require('@strapi/strapi').factories;

module.exports = createCoreController('api::app-setting.app-setting', ({ strapi }) => ({
  async find(ctx) {
    let setting = await strapi.documents('api::app-setting.app-setting').findFirst();
    if (!setting) {
      setting = await strapi.documents('api::app-setting.app-setting').create({
        data: {
          appName: 'Studora',
          appVersion: '1.0.0',
          supportEmail: 'support@studora.app',
          maintenanceMode: false,
          defaultCurrency: '€',
          defaultReminderMinutes: 30,
          supportedCurrencies: ['€', 'TND', '$'],
        },
      });
    }
    return { data: setting };
  },
}));

