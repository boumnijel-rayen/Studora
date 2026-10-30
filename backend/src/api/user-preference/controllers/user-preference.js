'use strict';

const { createCoreController } = require('@strapi/strapi').factories;
const { requireUser } = require('../../../utils/ownership');

const UID = 'api::user-preference.user-preference';
const ALLOWED_FIELDS = [
  'themeMode',
  'notificationsEnabled',
  'reminderMinutesBefore',
  'currency',
  'locale',
  'onboardingSeen',
  'pomodoroWorkMinutes',
  'pomodoroShortBreakMinutes',
  'pomodoroLongBreakMinutes',
  'pomodoroSessionsBeforeLongBreak',
  'pomodoroAutoStartBreaks',
];

async function findOrCreateForUser(strapi, userId) {
  const existing = await strapi.documents(UID).findFirst({
    filters: { owner: { id: userId } },
  });
  if (existing) return existing;

  return strapi.documents(UID).create({
    data: {
      themeMode: 'light',
      notificationsEnabled: true,
      reminderMinutesBefore: 30,
      currency: '€',
      locale: 'fr_FR',
      onboardingSeen: false,
      pomodoroWorkMinutes: 25,
      pomodoroShortBreakMinutes: 5,
      pomodoroLongBreakMinutes: 15,
      pomodoroSessionsBeforeLongBreak: 4,
      pomodoroAutoStartBreaks: false,
      owner: userId,
    },
  });
}

module.exports = createCoreController(UID, ({ strapi }) => ({
  async findMine(ctx) {
    const user = requireUser(ctx);
    if (!user) return;
    const pref = await findOrCreateForUser(strapi, user.id);
    return { data: pref };
  },

  async updateMine(ctx) {
    const user = requireUser(ctx);
    if (!user) return;

    const current = await findOrCreateForUser(strapi, user.id);
    const raw = ctx.request.body?.data || ctx.request.body || {};
    const patch = {};
    for (const key of ALLOWED_FIELDS) {
      if (raw[key] !== undefined) patch[key] = raw[key];
    }

    const updated = await strapi.documents(UID).update({
      documentId: current.documentId,
      data: patch,
    });

    return { data: updated };
  },
}));

