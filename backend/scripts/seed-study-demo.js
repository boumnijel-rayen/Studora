'use strict';

/**
 * Jeu de données de démonstration pour le module Study (et l'analyse IA).
 *
 * Crée (ou réinitialise) un compte de démo et le remplit de scénarios
 * qui déclenchent chaque type d'observation de l'IA, plus des cas limites
 * que le serveur doit ignorer. Les dates sont relatives à aujourd'hui,
 * donc le script reste valable quel que soit le jour où on le lance.
 *
 * Usage (Strapi doit tourner) :
 *   npm run seed:study
 *   npm run seed:study -- --email moi@exemple.com --password MonMdp123
 *   npm run seed:study -- --email moi@exemple.com --password MonMdp123 --reset
 *
 * Par défaut, seul un serveur local est accepté (jamais la base partagée Neon).
 */

const args = process.argv.slice(2);
const arg = (name) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : undefined;
};
const flag = (name) => args.includes(`--${name}`);

const BASE = (process.env.STRAPI_URL || 'http://localhost:1337').replace(/\/$/, '');
const API = `${BASE}/api`;
const DEMO_EMAIL = 'demo.study@example.test';
const EMAIL = arg('email') || DEMO_EMAIL;
const PASSWORD = arg('password') || 'Demo1234!';
// Le compte de démo est toujours réinitialisé ; un vrai compte seulement avec --reset.
const RESET = EMAIL === DEMO_EMAIL || flag('reset');

if (!/^https?:\/\/(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?$/.test(BASE) && !flag('allow-remote')) {
  console.error(`Refusé : ${BASE} n'est pas un serveur local. Ajoute --allow-remote si c'est vraiment voulu.`);
  process.exit(1);
}

// ── Helpers HTTP ────────────────────────────────────────────────────────────

let jwt = null;

async function call(method, path, body) {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(jwt ? { Authorization: `Bearer ${jwt}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  const json = text ? JSON.parse(text) : null;
  if (!res.ok) {
    const msg = json?.error?.message || text;
    const err = new Error(`${method} ${path} → ${res.status} ${msg}`);
    err.status = res.status;
    throw err;
  }
  return json;
}

const create = async (collection, data) => (await call('POST', `/${collection}`, { data })).data;

// ── Helpers de date (heure de Tunis, UTC+1 toute l'année) ───────────────────

/** Date à J+offset (négatif = passé) à hh:mm heure locale de Tunis. */
function at(dayOffset, hh, mm = 0) {
  const now = new Date();
  const d = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + dayOffset, hh - 1, mm));
  return d.toISOString();
}

// ── Scénarios ───────────────────────────────────────────────────────────────

const SUBJECTS = [
  { key: 'maths', name: 'Mathématiques', shortName: 'Maths', colorIndex: 0, iconKey: 'math', coefficient: 3, teacher: 'Mme Laurent' },
  { key: 'algo', name: 'Algorithmique', shortName: 'Algo', colorIndex: 1, iconKey: 'algo', coefficient: 3, teacher: 'M. Ben Salah' },
  { key: 'bdd', name: 'Bases de données', shortName: 'BDD', colorIndex: 2, iconKey: 'bdd', coefficient: 2, teacher: 'Mme Trabelsi' },
  { key: 'reseau', name: 'Réseaux', shortName: 'Réseaux', colorIndex: 3, iconKey: 'reseau', coefficient: 2, teacher: 'M. Gharbi' },
  { key: 'anglais', name: 'Anglais', shortName: 'Anglais', colorIndex: 4, iconKey: 'lang', coefficient: 1, teacher: 'Mrs Smith' },
];

// [matière, jour, heure, minute, durée, terminée, note]
const SESSIONS = [
  // 📈 progrès + 🔁 régularité : Maths, de plus en plus souvent, le soir.
  ['maths', -40, 19, 0, 30, true],
  ['maths', -32, 20, 0, 30, true],
  ['maths', -24, 19, 30, 45, true],
  ['maths', -17, 19, 0, 45, true],
  ['maths', -12, 20, 0, 60, true],
  ['maths', -9, 19, 0, 60, true],
  ['maths', -6, 18, 30, 60, true],
  ['maths', -4, 19, 0, 75, true],
  ['maths', -2, 20, 0, 90, true],
  // ⚠️ négligée : Algo, une seule petite session il y a 3 semaines, examen dans 3 jours.
  ['algo', -21, 22, 0, 20, true],
  // BDD : révisions moyennes l'après-midi.
  ['bdd', -15, 14, 0, 45, true],
  ['bdd', -8, 15, 0, 40, true],
  ['bdd', -3, 14, 30, 50, true],
  // 🕒 moment : Anglais, toujours le matin.
  ['anglais', -20, 8, 0, 30, true],
  ['anglais', -13, 8, 30, 30, true],
  ['anglais', -5, 9, 0, 35, true],
  // Cas limites que le serveur doit gérer :
  ['maths', -10, 21, 0, 45, false, 'Session manquée (baisse le taux de complétion)'],
  ['bdd', -1, 16, 0, 30, false, 'Session manquée hier'],
  ['bdd', 1, 17, 0, 45, false, 'Session déjà planifiée demain (future, non comptée)'],
  ['algo', -75, 10, 0, 120, true, 'Hors fenêtre de 60 jours (ignorée)'],
];

// [matière, titre, note /20, coefficient, jour]
const GRADES = [
  // 🎯 notes : Maths progresse avec le temps de révision.
  ['maths', 'DS1 Analyse', 11, 1, -35],
  ['maths', 'TP Algèbre', 14, 1, -18],
  ['maths', 'DS2 Probabilités', 16, 2, -7],
  // Algo : peu de révision, notes faibles.
  ['algo', 'TP1 Récursivité', 8.5, 1, -25],
  ['algo', 'DS1 Complexité', 9, 2, -11],
  ['bdd', 'TP SQL', 12, 1, -14],
  ['bdd', 'Mini-projet Merise', 13.5, 1, -4],
  ['anglais', 'Oral', 17, 1, -9],
  // Réseaux : aucune note, aucune session → négligée sans historique.
];

// [matière, titre, jour, heure, type, priorité, terminée]
const DEADLINES = [
  ['algo', 'Examen Algorithmique', 3, 9, 'exam', 'high', false],
  ['bdd', 'Devoir SQL avancé', 6, 23, 'homework', 'medium', false],
  ['reseau', 'Projet Réseaux (topologie)', 10, 12, 'project', 'high', false],
  ['maths', 'Examen Mathématiques', 13, 9, 'exam', 'high', false],
  // Cas limites ignorés par l'analyse :
  ['anglais', 'Essay déjà rendu', 2, 18, 'homework', 'low', true],
  ['bdd', 'Examen final BDD (dans 30 jours)', 30, 9, 'exam', 'high', false],
];

// [matière, titre, terminée, jour d'échéance | null]
const TASKS = [
  ['algo', 'Refaire les exercices de tri', false, 2],
  ['algo', 'Fiche sur la complexité', false, 1],
  ['maths', 'Annales probabilités 2025', true, null],
  ['reseau', 'Lire le cours sur le routage', false, 8],
];

// ── Exécution ───────────────────────────────────────────────────────────────

async function login() {
  try {
    const res = await call('POST', '/auth/local', { identifier: EMAIL, password: PASSWORD });
    jwt = res.jwt;
    return 'connecté';
  } catch (e) {
    if (e.status !== 400 || EMAIL !== DEMO_EMAIL) throw e;
    const res = await call('POST', '/auth/local/register', { username: EMAIL, email: EMAIL, password: PASSWORD });
    jwt = res.jwt;
    return 'créé';
  }
}

async function resetStudyData() {
  // Les collections sont filtrées par propriétaire côté serveur : on ne supprime que ses propres données.
  for (const collection of ['study-sessions', 'study-tasks', 'grades', 'deadlines', 'subjects']) {
    const { data } = await call('GET', `/${collection}`);
    for (const item of data) await call('DELETE', `/${collection}/${item.documentId}`);
  }
}

async function main() {
  console.log(`Serveur : ${BASE}`);
  const status = await login();
  console.log(`Compte ${EMAIL} : ${status}`);

  if (RESET) {
    await resetStudyData();
    console.log('Anciennes données Study de ce compte supprimées.');
  }

  const ids = {};
  for (const { key, ...data } of SUBJECTS) {
    ids[key] = (await create('subjects', data)).documentId;
  }
  const nameOf = (key) => SUBJECTS.find((s) => s.key === key).name;
  const colorOf = (key) => SUBJECTS.find((s) => s.key === key).colorIndex;

  for (const [key, day, hh, mm, duration, isCompleted, notes = ''] of SESSIONS) {
    await create('study-sessions', {
      subject: ids[key],
      subjectId: ids[key],
      subjectName: nameOf(key),
      durationMinutes: duration,
      date: at(day, hh, mm),
      colorIndex: colorOf(key),
      isCompleted,
      notes,
    });
  }

  for (const [key, title, value, coefficient, day] of GRADES) {
    await create('grades', {
      subject: ids[key],
      subjectId: ids[key],
      subjectName: nameOf(key),
      title,
      value,
      coefficient,
      date: at(day, 10),
    });
  }

  for (const [key, title, day, hh, type, priority, isCompleted] of DEADLINES) {
    await create('deadlines', {
      subject: ids[key],
      subjectName: nameOf(key),
      title,
      dueDate: at(day, hh),
      type,
      priority,
      isCompleted,
    });
  }

  for (const [key, title, isCompleted, day] of TASKS) {
    await create('study-tasks', {
      subject: ids[key],
      subjectId: ids[key],
      title,
      isCompleted,
      ...(day == null ? {} : { dueDate: at(day, 20) }),
    });
  }

  const done = SESSIONS.filter((s) => s[5] && s[1] < 0 && s[1] >= -60).length;
  console.log(
    `Ajouté : ${SUBJECTS.length} matières, ${SESSIONS.length} sessions (${done} terminées dans les 60 jours), ` +
      `${GRADES.length} notes, ${DEADLINES.length} échéances, ${TASKS.length} tâches.`,
  );
  console.log(`\nConnexion dans l'app :\n  e-mail       : ${EMAIL}\n  mot de passe : ${PASSWORD}`);
}

main().catch((e) => {
  console.error(`Échec du seed : ${e.message}`);
  process.exit(1);
});
