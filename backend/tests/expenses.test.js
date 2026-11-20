'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { expenseRules } = require('../src/api/expense/controllers/expense');

const aziz = { id: 1 };
const sarra = { id: 2 };
const member = (user) => ({ user });

test('canRecordPayment : ses propres dépenses ou celles d\'un colocataire sans compte', () => {
  assert.equal(expenseRules.canRecordPayment(member(aziz), aziz), true);
  assert.equal(expenseRules.canRecordPayment(member(sarra), aziz), false);
  assert.equal(expenseRules.canRecordPayment(member(null), aziz), true);
});

test('canSettle : la personne qui rembourse, ou la personne remboursée si le débiteur n\'a pas de compte', () => {
  assert.equal(expenseRules.canSettle(member(sarra), member(aziz), sarra), true);
  assert.equal(expenseRules.canSettle(member(sarra), member(aziz), aziz), false);
  assert.equal(expenseRules.canSettle(member(sarra), member(aziz), { id: 3 }), false);
  assert.equal(expenseRules.canSettle(member(null), member(aziz), aziz), true);
  assert.equal(expenseRules.canSettle(member(null), member(aziz), sarra), false);
});

test('canDelete : uniquement la personne qui a saisi l\'opération', () => {
  assert.equal(expenseRules.canDelete({ owner: aziz }, aziz), true);
  assert.equal(expenseRules.canDelete({ owner: aziz }, sarra), false);
  assert.equal(expenseRules.canDelete({ owner: null }, aziz), false);
});
