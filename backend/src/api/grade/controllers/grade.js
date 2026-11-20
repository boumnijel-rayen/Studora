'use strict';

const { createOwnedController, requireUser } = require('../../../utils/ownership');
const {
  GradeImportError,
  parseUpload,
  normalizeScannedGrades,
  consumeScanQuota,
  extractGradesWithGemini,
} = require('../../../utils/grade-import');

function sendError(ctx, status, message) {
  ctx.status = status;
  ctx.body = { data: null, error: { status, name: 'GradeImportError', message } };
}

module.exports = createOwnedController('api::grade.grade', {
  defaultPopulate: { subject: true },

  extraActions: ({ strapi }) => ({
    /**
     * POST /api/grades/import-scan — analyse un relevé de notes par IA et
     * renvoie les notes détectées, sans rien enregistrer.
     */
    async scanImport(ctx) {
      const user = requireUser(ctx);
      if (!user) return;

      try {
        const upload = parseUpload(ctx.request.body?.data || ctx.request.body || {});

        if (!consumeScanQuota(user.id)) {
          return sendError(ctx, 429, "Limite d'analyses atteinte. Réessayez dans une heure.");
        }

        const subjects = await strapi.documents('api::subject.subject').findMany({
          filters: { owner: { id: user.id } },
          fields: ['name'],
        });

        const rawGrades = await extractGradesWithGemini({ ...upload, subjects });
        const grades = normalizeScannedGrades(rawGrades, subjects);
        return { data: { grades, count: grades.length } };
      } catch (error) {
        if (error instanceof GradeImportError) {
          return sendError(ctx, error.status, error.message);
        }
        strapi.log.error(`Import de notes par IA : ${error?.message || error}`);
        return sendError(ctx, 500, "L'analyse du document a échoué.");
      }
    },
  }),
});
