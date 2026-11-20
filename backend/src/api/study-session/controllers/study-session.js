'use strict';

const { createOwnedController, requireUser } = require('../../../utils/ownership');
const {
  generateStudyInsights,
  AiNotConfiguredError,
  AiUnavailableError,
} = require('../../../utils/study-insights');

module.exports = createOwnedController('api::study-session.study-session', {
  defaultPopulate: { subject: true, task: true },
  extraActions: ({ strapi }) => ({
    async insights(ctx) {
      const user = requireUser(ctx);
      if (!user) return;

      try {
        const insights = await generateStudyInsights(strapi, user.id);
        return { data: insights };
      } catch (error) {
        if (error instanceof AiNotConfiguredError) {
          strapi.log.warn('[study-insights] GEMINI_API_KEY absente : analyse IA désactivée.');
          ctx.status = 503;
          return { data: null, error: { status: 503, name: 'ServiceUnavailableError', message: error.message } };
        }
        if (error instanceof AiUnavailableError) {
          ctx.status = 502;
          return { data: null, error: { status: 502, name: 'BadGatewayError', message: error.message } };
        }
        throw error;
      }
    },
  }),
});
