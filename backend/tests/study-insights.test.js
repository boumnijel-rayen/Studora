'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  validateRecommendations,
  validateGradeLinks,
  computeAggregates,
} = require('../src/utils/study-insights');

const NOW = new Date('2026-03-02T10:00:00.000Z'); // lundi
const DAY = 24 * 60 * 60 * 1000;
const inDays = (n) => new Date(NOW.getTime() + n * DAY).toISOString();

const SUBJECTS = [
  { documentId: 'maths-doc', name: 'Mathématiques', colorIndex: 1 },
  { documentId: 'algo-doc', name: 'Algorithmique', colorIndex: 2 },
];

const rec = (overrides = {}) => ({
  subjectId: 'maths-doc',
  subjectName: 'Maths',
  dureeMinutes: 45,
  date: inDays(1),
  raison: 'Examen dans 4 jours',
  ...overrides,
});

test('validateRecommendations drops recommendations whose subjectId is not one of the user subjects', () => {
  const result = validateRecommendations(
    [rec({ subjectId: 'inconnu' }), rec({ subjectId: 'algo-doc' })],
    SUBJECTS,
    NOW,
  );
  assert.equal(result.length, 1);
  assert.equal(result[0].subjectId, 'algo-doc');
});

test('validateRecommendations replaces subjectName with the real subject name', () => {
  const [result] = validateRecommendations([rec({ subjectName: 'Nom inventé' })], SUBJECTS, NOW);
  assert.equal(result.subjectName, 'Mathématiques');
});

test('validateRecommendations clamps durations between 10 and 180 minutes', () => {
  const result = validateRecommendations(
    [rec({ dureeMinutes: 3 }), rec({ dureeMinutes: 500 }), rec({ dureeMinutes: 44.6 })],
    SUBJECTS,
    NOW,
  );
  assert.deepEqual(result.map((r) => r.dureeMinutes), [10, 180, 45]);
});

test('validateRecommendations rejects past dates, invalid dates and dates more than 14 days ahead', () => {
  const result = validateRecommendations(
    [
      rec({ date: inDays(-1) }),
      rec({ date: NOW.toISOString() }),
      rec({ date: 'pas une date' }),
      rec({ date: inDays(15) }),
      rec({ date: inDays(14) }),
    ],
    SUBJECTS,
    NOW,
  );
  assert.equal(result.length, 1);
  assert.equal(result[0].date, inDays(14));
});

test('validateRecommendations drops non-numeric durations and keeps at most 3 items', () => {
  const result = validateRecommendations(
    [rec({ dureeMinutes: 'beaucoup' }), rec(), rec(), rec(), rec()],
    SUBJECTS,
    NOW,
  );
  assert.equal(result.length, 3);
});

test('validateRecommendations tolerates a missing or malformed list', () => {
  assert.deepEqual(validateRecommendations(undefined, SUBJECTS, NOW), []);
  assert.deepEqual(validateRecommendations([null, 'x'], SUBJECTS, NOW), []);
});

test('computeAggregates uses completed sessions only and computes weighted averages', () => {
  const aggregates = computeAggregates(
    {
      subjects: SUBJECTS,
      sessions: [
        { subjectId: 'maths-doc', subjectName: 'Mathématiques', durationMinutes: 60, date: inDays(-2), isCompleted: true },
        { subjectId: 'maths-doc', subjectName: 'Mathématiques', durationMinutes: 30, date: inDays(-1), isCompleted: false },
        { subjectId: 'maths-doc', subjectName: 'Mathématiques', durationMinutes: 99, date: inDays(2), isCompleted: false },
      ],
      grades: [
        { subjectId: 'maths-doc', subjectName: 'Mathématiques', value: 10, coefficient: 1 },
        { subjectId: 'maths-doc', subjectName: 'Mathématiques', value: 16, coefficient: 2 },
      ],
      deadlines: [
        { title: 'Examen', subjectName: 'Algorithmique', subject: { documentId: 'algo-doc' }, dueDate: inDays(4), type: 'exam', priority: 'high' },
        { title: 'Trop loin', subjectName: 'Algorithmique', dueDate: inDays(30), type: 'exam' },
      ],
    },
    NOW,
  );

  assert.equal(aggregates.sessionsPassees, 2); // la session future ne compte pas
  assert.equal(aggregates.sessionsTerminees, 1);
  assert.equal(aggregates.tauxSessionsTerminees, 50);
  assert.equal(aggregates.minutesTotales, 60);

  const maths = aggregates.parMatiere.find((m) => m.subjectId === 'maths-doc');
  assert.equal(maths.minutesRevisees, 60);
  assert.equal(maths.moyenne, 14);
  assert.equal(maths.joursDepuisDerniereSession, 2);

  const algo = aggregates.parMatiere.find((m) => m.subjectId === 'algo-doc');
  assert.equal(algo.minutesRevisees, 0);
  assert.equal(algo.joursDepuisDerniereSession, null);

  assert.equal(aggregates.echeancesProches.length, 1);
  assert.equal(aggregates.echeancesProches[0].joursRestants, 4);
});

test('validateGradeLinks overwrites model numbers with real aggregates and drops unknown subjects', () => {
  const parMatiere = [{ subjectName: 'Mathématiques', minutesRevisees: 60, moyenne: 14 }];
  const result = validateGradeLinks(
    [
      { subjectName: 'mathématiques', minutesRevisees: 999, moyenne: 20, commentaire: 'Bien' },
      { subjectName: 'Physique', minutesRevisees: 10, moyenne: 8, commentaire: '?' },
    ],
    parMatiere,
  );
  assert.deepEqual(result, [
    { subjectName: 'Mathématiques', minutesRevisees: 60, moyenne: 14, commentaire: 'Bien' },
  ]);
});
