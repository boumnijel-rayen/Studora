'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.TZ = 'UTC';

const { nextDueDate, isTooEarlyToComplete, periodStart } = require('../src/api/chore/controllers/chore');

const NOW = new Date('2026-11-20T10:00:00.000Z');
const day = (iso) => new Date(iso).toISOString().slice(0, 10);

test('nextDueDate : une période après l\'échéance si elle est déjà dans le futur', () => {
  assert.equal(day(nextDueDate('2026-11-20T18:00:00.000Z', 'Quotidien', NOW)), '2026-11-21');
  assert.equal(day(nextDueDate('2026-11-20T18:00:00.000Z', 'Hebdomadaire', NOW)), '2026-11-27');
  assert.equal(day(nextDueDate('2026-11-20T18:00:00.000Z', 'Mensuel', NOW)), '2026-12-20');
});

test('nextDueDate : une tâche validée en retard ne recrée pas une occurrence déjà en retard', () => {
  const next = nextDueDate('2026-11-15T18:00:00.000Z', 'Quotidien', NOW);
  assert.ok(next > NOW);
  assert.equal(day(next), '2026-11-20');
  assert.equal(day(nextDueDate('2026-11-01T18:00:00.000Z', 'Hebdomadaire', NOW)), '2026-11-22');
});

test('nextDueDate : aucune occurrence pour une tâche ponctuelle', () => {
  assert.equal(nextDueDate('2026-11-20T18:00:00.000Z', 'Une seule fois', NOW), null);
});

test('nextDueDate gère la fréquence annuelle', () => {
  assert.equal(day(nextDueDate('2026-11-20T18:00:00.000Z', 'Annuel', NOW)), '2027-11-20');
});

test('periodStart : début du jour, de la semaine (lundi), du mois et de l\'année', () => {
  // 20/11/2026 est un vendredi.
  assert.equal(day(periodStart('2026-11-20T18:00:00.000Z', 'Quotidien')), '2026-11-20');
  assert.equal(day(periodStart('2026-11-20T18:00:00.000Z', 'Hebdomadaire')), '2026-11-16');
  assert.equal(day(periodStart('2026-11-20T18:00:00.000Z', 'Mensuel')), '2026-11-01');
  assert.equal(day(periodStart('2026-11-20T18:00:00.000Z', 'Annuel')), '2026-01-01');
  assert.equal(periodStart('2026-11-20T18:00:00.000Z', 'Une seule fois'), null);
});

test('isTooEarlyToComplete : seules les tâches de la période en cours (ou en retard) se valident', () => {
  const chore = (frequency, dueDate) => ({ frequency, dueDate });
  // Quotidien : aujourd'hui et demain (marge d'un jour) oui, après-demain non.
  assert.equal(isTooEarlyToComplete(chore('Quotidien', '2026-11-20T18:00:00.000Z'), NOW), false);
  assert.equal(isTooEarlyToComplete(chore('Quotidien', '2026-11-19T18:00:00.000Z'), NOW), false);
  assert.equal(isTooEarlyToComplete(chore('Quotidien', '2026-11-23T18:00:00.000Z'), NOW), true);
  // Hebdomadaire : la semaine suivante (lundi 23) reste bloquée jusqu'au dimanche.
  assert.equal(isTooEarlyToComplete(chore('Hebdomadaire', '2026-11-18T18:00:00.000Z'), NOW), false);
  assert.equal(isTooEarlyToComplete(chore('Hebdomadaire', '2026-11-27T18:00:00.000Z'), NOW), true);
  // Mensuel : novembre oui, décembre non.
  assert.equal(isTooEarlyToComplete(chore('Mensuel', '2026-11-28T18:00:00.000Z'), NOW), false);
  assert.equal(isTooEarlyToComplete(chore('Mensuel', '2026-12-20T18:00:00.000Z'), NOW), true);
  // Annuel : 2026 oui, 2027 non.
  assert.equal(isTooEarlyToComplete(chore('Annuel', '2026-12-31T18:00:00.000Z'), NOW), false);
  assert.equal(isTooEarlyToComplete(chore('Annuel', '2027-11-20T18:00:00.000Z'), NOW), true);
  // Ponctuelle : toujours validable.
  assert.equal(isTooEarlyToComplete(chore('Une seule fois', '2027-01-01T18:00:00.000Z'), NOW), false);
});

test('chorePermissions : seul le colocataire assigné valide, le créateur supprime', () => {
  const { chorePermissions } = require('../src/api/chore/controllers/chore');
  const aziz = { id: 1 };
  const sarra = { id: 2 };
  const colocation = { creator: { id: 1 } };
  const choreForSarra = { owner: { id: 1 }, assignedTo: { user: { id: 2 } } };
  const choreForMehdi = { owner: { id: 2 }, assignedTo: { user: null } };

  // Tâche de Sarra créée par Aziz.
  assert.deepEqual(chorePermissions(choreForSarra, { user: sarra, colocation }), {
    canComplete: true,
    canReassign: true,
    canDelete: false,
  });
  assert.deepEqual(chorePermissions(choreForSarra, { user: aziz, colocation }), {
    canComplete: false,
    canReassign: true,
    canDelete: true,
  });
  assert.deepEqual(chorePermissions(choreForSarra, { user: { id: 3 }, colocation }), {
    canComplete: false,
    canReassign: false,
    canDelete: false,
  });

  // Mehdi n'a pas de compte : son créateur (Sarra) ou le propriétaire du groupe (Aziz) valident.
  assert.equal(chorePermissions(choreForMehdi, { user: sarra, colocation }).canComplete, true);
  assert.equal(chorePermissions(choreForMehdi, { user: aziz, colocation }).canComplete, true);
  assert.equal(chorePermissions(choreForMehdi, { user: { id: 3 }, colocation }).canComplete, false);
});
