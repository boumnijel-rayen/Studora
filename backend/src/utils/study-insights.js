'use strict';

/**
 * Analyse IA de l'historique de révision (module Study).
 *
 * Charge les sessions, notes, échéances et matières de l'utilisateur, pré-calcule
 * des agrégats côté serveur (chiffres fiables, moins de tokens), puis demande à
 * Google Gemini (offre gratuite) un résumé, des observations et des recommandations.
 * La réponse de l'IA est ensuite revalidée ici : on ne lui fait jamais confiance.
 */

const { GoogleGenAI, ApiError } = require('@google/genai');
const { z } = require('zod');

const UIDS = {
  session: 'api::study-session.study-session',
  grade: 'api::grade.grade',
  deadline: 'api::deadline.deadline',
  subject: 'api::subject.subject',
};

const DAY_MS = 24 * 60 * 60 * 1000;
const HISTORY_DAYS = 60;
const DEADLINE_HORIZON_DAYS = 21;
const MIN_COMPLETED_SESSIONS = 3;
const MIN_DURATION = 10;
const MAX_DURATION = 180;
const MAX_RECOMMENDATION_DAYS = 14;
const MAX_RECOMMENDATIONS = 3;
const MAX_OBSERVATIONS = 5;

/** Fuseau des étudiants (Tunisie) ; surchargeable via APP_TIMEZONE. */
const TIMEZONE = process.env.APP_TIMEZONE || 'Africa/Tunis';

const WEEKDAYS = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const TIME_SLOTS = ['matin', 'apres-midi', 'soir', 'nuit'];

// ── Erreurs typées (traduites en codes HTTP par le contrôleur) ──────────────

class AiNotConfiguredError extends Error {
  constructor() {
    super("L'analyse IA n'est pas configurée sur ce serveur.");
    this.name = 'AiNotConfiguredError';
  }
}

class AiUnavailableError extends Error {
  constructor(message = "L'analyse IA est momentanément indisponible. Réessaie dans quelques instants.") {
    super(message);
    this.name = 'AiUnavailableError';
  }
}

// ── Schéma de sortie structurée ─────────────────────────────────────────────

const InsightsSchema = z.object({
  resume: z.string(),
  observations: z.array(
    z.object({
      type: z.enum(['progres', 'negligee', 'moment', 'regularite', 'notes']),
      texte: z.string(),
    }),
  ),
  liensNotes: z.array(
    z.object({
      subjectName: z.string(),
      minutesRevisees: z.number(),
      moyenne: z.number(),
      commentaire: z.string(),
    }),
  ),
  recommandations: z.array(
    z.object({
      subjectId: z.string(),
      subjectName: z.string(),
      dureeMinutes: z.number(),
      date: z.string(),
      raison: z.string(),
    }),
  ),
});

const SYSTEM_PROMPT = [
  'Tu es un coach de révision pour un étudiant.',
  "Analyse uniquement les données fournies, n'invente aucun chiffre.",
  'Relie le temps de révision aux notes par matière.',
  'Repère les matières négligées, surtout celles avec un examen proche.',
  'Propose 1 à 3 sessions concrètes dans les 7 prochains jours, avec un `subjectId` choisi UNIQUEMENT dans la liste des matières fournie.',
  "Chaque date de recommandation est au format ISO 8601 avec le décalage horaire du fuseau de l'étudiant (ex. 2026-03-04T18:00:00+01:00), à une heure raisonnable.",
  'Le résumé fait 2 à 3 phrases. Donne 2 à 5 observations.',
  'Phrases courtes, ton encourageant, tutoiement, en français.',
].join(' ');

// ── Helpers de date ─────────────────────────────────────────────────────────

const localFormatter = new Intl.DateTimeFormat('en-GB', {
  timeZone: TIMEZONE,
  weekday: 'short',
  hour: '2-digit',
  hourCycle: 'h23',
});
const WEEKDAY_INDEX = { Mon: 0, Tue: 1, Wed: 2, Thu: 3, Fri: 4, Sat: 5, Sun: 6 };

/** Jour de la semaine (0 = lundi) et heure locale, dans le fuseau de l'étudiant. */
function localParts(date) {
  const parts = Object.fromEntries(
    localFormatter.formatToParts(date).map((p) => [p.type, p.value]),
  );
  return { weekday: WEEKDAY_INDEX[parts.weekday] ?? 0, hour: Number(parts.hour) % 24 };
}

function timeSlotOf(hour) {
  if (hour >= 5 && hour < 12) return 'matin';
  if (hour >= 12 && hour < 18) return 'apres-midi';
  if (hour >= 18 && hour < 23) return 'soir';
  return 'nuit';
}

function toDate(value) {
  const d = value instanceof Date ? value : new Date(value);
  return Number.isNaN(d.getTime()) ? null : d;
}

const round1 = (n) => Math.round(n * 10) / 10;

// ── Agrégats (fonction pure) ────────────────────────────────────────────────

/**
 * Pré-calcule les statistiques envoyées à l'IA.
 * @param {{ sessions: any[], grades: any[], deadlines: any[], subjects: any[] }} data
 * @param {Date} now
 */
function computeAggregates({ sessions, grades, deadlines, subjects }, now) {
  const nowMs = now.getTime();
  const subjectNames = new Map(subjects.map((s) => [s.documentId, s.name]));

  const pastSessions = sessions.filter((s) => {
    const d = toDate(s.date);
    return d && d.getTime() <= nowMs;
  });
  const completed = pastSessions.filter((s) => s.isCompleted === true);

  // Une ligne par matière, y compris celles jamais révisées (pour repérer les négligées).
  const bySubject = new Map();
  const ensure = (id, name) => {
    const key = id || name;
    if (!bySubject.has(key)) {
      bySubject.set(key, {
        subjectId: id || null,
        subjectName: subjectNames.get(id) || name || 'Matière inconnue',
        minutes: 0,
        sessionsTerminees: 0,
        derniereSessionMs: null,
      });
    }
    return bySubject.get(key);
  };
  for (const s of subjects) ensure(s.documentId, s.name);

  const minutesParJour = Object.fromEntries(WEEKDAYS.map((d) => [d, 0]));
  const minutesParTranche = Object.fromEntries(TIME_SLOTS.map((t) => [t, 0]));

  for (const s of completed) {
    const d = toDate(s.date);
    const minutes = Number(s.durationMinutes) || 0;
    const row = ensure(s.subjectId, s.subjectName);
    row.minutes += minutes;
    row.sessionsTerminees += 1;
    row.derniereSessionMs = Math.max(row.derniereSessionMs ?? 0, d.getTime());

    const { weekday, hour } = localParts(d);
    minutesParJour[WEEKDAYS[weekday]] += minutes;
    minutesParTranche[timeSlotOf(hour)] += minutes;
  }

  // Moyenne pondérée /20 par matière.
  const gradeSums = new Map();
  for (const g of grades) {
    const value = Number(g.value);
    const coef = Number(g.coefficient) || 1;
    if (!Number.isFinite(value)) continue;
    const key = g.subjectId || g.subjectName;
    const acc = gradeSums.get(key) || { sum: 0, coef: 0, count: 0, name: g.subjectName };
    acc.sum += value * coef;
    acc.coef += coef;
    acc.count += 1;
    gradeSums.set(key, acc);
  }

  const parMatiere = [...bySubject.entries()].map(([key, row]) => {
    const g = gradeSums.get(key) || gradeSums.get(row.subjectName);
    return {
      subjectId: row.subjectId,
      subjectName: row.subjectName,
      minutesRevisees: row.minutes,
      sessionsTerminees: row.sessionsTerminees,
      joursDepuisDerniereSession:
        row.derniereSessionMs == null ? null : Math.floor((nowMs - row.derniereSessionMs) / DAY_MS),
      moyenne: g && g.coef > 0 ? round1(g.sum / g.coef) : null,
      nombreNotes: g ? g.count : 0,
    };
  });

  const echeances = deadlines
    .map((d) => ({ ...d, due: toDate(d.dueDate) }))
    .filter((d) => d.due && d.isCompleted !== true)
    .filter((d) => d.due.getTime() >= nowMs && d.due.getTime() <= nowMs + DEADLINE_HORIZON_DAYS * DAY_MS)
    .sort((a, b) => a.due - b.due)
    .map((d) => ({
      title: d.title,
      subjectId: d.subject?.documentId || null,
      subjectName: d.subjectName,
      dueDate: d.due.toISOString(),
      joursRestants: Math.ceil((d.due.getTime() - nowMs) / DAY_MS),
      type: d.type,
      priority: d.priority,
    }));

  return {
    periodeJours: HISTORY_DAYS,
    sessionsPassees: pastSessions.length,
    sessionsTerminees: completed.length,
    tauxSessionsTerminees: pastSessions.length ? round1((completed.length / pastSessions.length) * 100) : 0,
    minutesTotales: completed.reduce((acc, s) => acc + (Number(s.durationMinutes) || 0), 0),
    minutesParJourSemaine: minutesParJour,
    minutesParTrancheHoraire: minutesParTranche,
    parMatiere,
    echeancesProches: echeances,
  };
}

// ── Validation de la réponse IA (fonction pure, testée) ─────────────────────

/**
 * Ne garde que les recommandations exploitables : matière de l'utilisateur,
 * durée bornée, date dans le futur proche. Le nom de matière vient de la base.
 * @param {any[]} recommandations
 * @param {{ documentId: string, name: string }[]} subjects
 * @param {Date} now
 */
function validateRecommendations(recommandations, subjects, now) {
  const byId = new Map(subjects.map((s) => [s.documentId, s]));
  const nowMs = now.getTime();
  const maxMs = nowMs + MAX_RECOMMENDATION_DAYS * DAY_MS;
  const result = [];

  for (const rec of Array.isArray(recommandations) ? recommandations : []) {
    const subject = byId.get(rec?.subjectId);
    if (!subject) continue;

    const duration = Number(rec.dureeMinutes);
    if (!Number.isFinite(duration)) continue;

    const date = toDate(rec.date);
    if (!date || date.getTime() <= nowMs || date.getTime() > maxMs) continue;

    result.push({
      subjectId: subject.documentId,
      subjectName: subject.name,
      dureeMinutes: Math.min(MAX_DURATION, Math.max(MIN_DURATION, Math.round(duration))),
      date: date.toISOString(),
      raison: String(rec.raison || '').trim(),
    });
    if (result.length >= MAX_RECOMMENDATIONS) break;
  }
  return result;
}

/** Remplace les chiffres « révision ↔ notes » par les vrais agrégats ; écarte les matières inconnues. */
function validateGradeLinks(liens, parMatiere) {
  const byName = new Map(parMatiere.map((m) => [m.subjectName.toLowerCase(), m]));
  const result = [];
  for (const lien of Array.isArray(liens) ? liens : []) {
    const row = byName.get(String(lien?.subjectName || '').toLowerCase());
    if (!row || row.moyenne == null) continue;
    result.push({
      subjectName: row.subjectName,
      minutesRevisees: row.minutesRevisees,
      moyenne: row.moyenne,
      commentaire: String(lien.commentaire || '').trim(),
    });
  }
  return result;
}

// ── Chargement des données ──────────────────────────────────────────────────

async function loadUserData(strapi, userId, now) {
  const owner = { owner: { id: userId } };
  const since = new Date(now.getTime() - HISTORY_DAYS * DAY_MS).toISOString();

  const [sessions, grades, deadlines, subjects] = await Promise.all([
    strapi.documents(UIDS.session).findMany({
      filters: { ...owner, date: { $gte: since } },
      fields: ['subjectId', 'subjectName', 'durationMinutes', 'date', 'isCompleted'],
      limit: 1000,
    }),
    strapi.documents(UIDS.grade).findMany({
      filters: owner,
      fields: ['title', 'value', 'coefficient', 'date', 'subjectId', 'subjectName'],
      limit: 1000,
    }),
    strapi.documents(UIDS.deadline).findMany({
      filters: { ...owner, isCompleted: false },
      fields: ['title', 'subjectName', 'dueDate', 'type', 'priority', 'isCompleted'],
      populate: { subject: { fields: ['name'] } },
      limit: 500,
    }),
    strapi.documents(UIDS.subject).findMany({
      filters: owner,
      fields: ['name', 'colorIndex'],
      limit: 200,
    }),
  ]);

  return { sessions, grades, deadlines, subjects };
}

// ── Appel Gemini ────────────────────────────────────────────────────────────

const DEFAULT_MODEL = 'gemini-3.5-flash-lite';
const RESPONSE_JSON_SCHEMA = z.toJSONSchema(InsightsSchema);

let cachedClient = null;
function getClient() {
  if (!cachedClient) {
    // Délai < 60 s côté Flutter, et une seule tentative pour rester sous ce délai.
    cachedClient = new GoogleGenAI({
      apiKey: process.env.GEMINI_API_KEY,
      httpOptions: { timeout: 50_000, retryOptions: { attempts: 1 } },
    });
  }
  return cachedClient;
}

async function askModel(strapi, payload) {
  let response;
  try {
    response = await getClient().models.generateContent({
      model: process.env.AI_MODEL || DEFAULT_MODEL,
      contents: JSON.stringify(payload),
      config: {
        systemInstruction: SYSTEM_PROMPT,
        responseMimeType: 'application/json',
        responseJsonSchema: RESPONSE_JSON_SCHEMA,
        maxOutputTokens: 4000,
      },
    });
  } catch (error) {
    if (error instanceof ApiError) {
      if (error.status === 429) {
        strapi.log.warn('[study-insights] Limite gratuite Gemini atteinte (429).');
        throw new AiUnavailableError("Trop d'analyses en ce moment. Réessaie dans une minute.");
      }
      if (error.status === 400 || error.status === 403) {
        strapi.log.error(`[study-insights] Requête refusée par Gemini (${error.status}) : clé GEMINI_API_KEY invalide ou modèle indisponible. ${error.message}`);
        throw new AiUnavailableError();
      }
      strapi.log.error(`[study-insights] Erreur API Gemini (${error.status}) : ${error.message}`);
      throw new AiUnavailableError();
    }
    strapi.log.error(`[study-insights] Appel Gemini impossible : ${error.message}`);
    throw new AiUnavailableError();
  }

  const blockReason = response.promptFeedback?.blockReason;
  const finishReason = response.candidates?.[0]?.finishReason;
  if (blockReason || (finishReason && finishReason !== 'STOP')) {
    strapi.log.warn(`[study-insights] Réponse Gemini incomplète ou bloquée (blockReason=${blockReason}, finishReason=${finishReason}).`);
    throw new AiUnavailableError("L'IA n'a pas pu analyser ton historique cette fois-ci.");
  }

  let parsed;
  try {
    parsed = InsightsSchema.safeParse(JSON.parse(response.text ?? ''));
  } catch {
    parsed = { success: false };
  }
  if (!parsed.success) {
    strapi.log.error('[study-insights] JSON Gemini non conforme au schéma.');
    throw new AiUnavailableError();
  }
  return parsed.data;
}

// ── Point d'entrée ──────────────────────────────────────────────────────────

function notEnoughDataResult() {
  return {
    resume: "Pas encore assez de données, fais quelques sessions d'abord.",
    observations: [],
    liensNotes: [],
    recommandations: [],
    donneesInsuffisantes: true,
  };
}

/**
 * @param {import('@strapi/strapi').Core.Strapi} strapi
 * @param {number} userId
 * @param {{ now?: Date }} [options]
 */
async function generateStudyInsights(strapi, userId, { now = new Date() } = {}) {
  const data = await loadUserData(strapi, userId, now);
  const completedCount = data.sessions.filter((s) => s.isCompleted === true).length;
  if (completedCount < MIN_COMPLETED_SESSIONS) {
    return notEnoughDataResult();
  }

  if (!process.env.GEMINI_API_KEY) {
    throw new AiNotConfiguredError();
  }

  const aggregates = computeAggregates(data, now);
  const payload = {
    maintenant: now.toISOString(),
    fuseauHoraire: TIMEZONE,
    maintenantLocal: now.toLocaleString('fr-FR', { timeZone: TIMEZONE, dateStyle: 'full', timeStyle: 'short' }),
    matieresValides: data.subjects.map((s) => ({ subjectId: s.documentId, name: s.name })),
    statistiques: aggregates,
  };

  const output = await askModel(strapi, payload);

  return {
    resume: String(output.resume || '').trim(),
    observations: (output.observations || []).slice(0, MAX_OBSERVATIONS),
    liensNotes: validateGradeLinks(output.liensNotes, aggregates.parMatiere),
    recommandations: validateRecommendations(output.recommandations, data.subjects, now),
    donneesInsuffisantes: false,
  };
}

module.exports = {
  generateStudyInsights,
  computeAggregates,
  validateRecommendations,
  validateGradeLinks,
  AiNotConfiguredError,
  AiUnavailableError,
  InsightsSchema,
};
