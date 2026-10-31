'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const { requireUser } = require('../src/utils/ownership');
const { stripPrivateFields, randomCode } = require('../src/utils/sanitize');

test('requireUser rejects unauthenticated requests with 401 unauthorized', () => {
  let unauthorizedCalledWith = null;
  const ctx = {
    state: {},
    unauthorized(msg) {
      unauthorizedCalledWith = msg;
    },
  };
  const result = requireUser(ctx);
  assert.equal(result, null);
  assert.equal(unauthorizedCalledWith, 'Authentification requise.');
});

test('requireUser returns authenticated user when present in ctx.state.user', () => {
  const user = { id: 42, email: 'etudiant@univ.fr' };
  const ctx = {
    state: { user },
    unauthorized() {
      assert.fail('Should not call unauthorized');
    },
  };
  const result = requireUser(ctx);
  assert.deepEqual(result, user);
});

test('stripPrivateFields removes credentials at any depth without touching other fields', () => {
  const result = stripPrivateFields({
    title: 'Groupe',
    date: new Date('2026-01-01T00:00:00.000Z'),
    creator: { id: 1, password: 'hash', resetPasswordToken: 'tok', confirmationToken: 'tok' },
    members: [{ id: 2, name: 'Sara', password: 'hash' }],
  });
  assert.deepEqual(result, {
    title: 'Groupe',
    date: new Date('2026-01-01T00:00:00.000Z'),
    creator: { id: 1 },
    members: [{ id: 2, name: 'Sara' }],
  });
});

test('randomCode produces 8 characters from an unambiguous alphabet', () => {
  for (let i = 0; i < 50; i++) {
    assert.match(randomCode(), /^[A-HJ-NP-Z2-9]{8}$/);
  }
});

test('All required Strapi content-type schemas exist, are valid JSON, and enforce owner relations', () => {
  const expectedApis = [
    'app-setting',
    'user-preference',
    'subject',
    'course',
    'deadline',
    'app-notification',
    'study-task',
    'study-session',
    'grade',
    'academic-goal',
    'study-group',
    'group-message',
    'group-activity',
    'roommate-member',
    'chore',
    'expense',
    'colocation',
    'colocation-message',
  ];

  const colocationScopedApis = ['roommate-member', 'chore', 'expense', 'colocation-message'];

  const userOwnedApis = [
    'user-preference',
    'subject',
    'course',
    'deadline',
    'app-notification',
    'study-task',
    'study-session',
    'grade',
    'academic-goal',
    'roommate-member',
    'chore',
    'expense',
  ];

  for (const api of expectedApis) {
    const schemaPath = path.join(
      __dirname,
      '..',
      'src',
      'api',
      api,
      'content-types',
      api,
      'schema.json',
    );
    assert.equal(fs.existsSync(schemaPath), true, `Missing schema for ${api}`);
    const parsed = JSON.parse(fs.readFileSync(schemaPath, 'utf8'));
    assert.equal(parsed.info.singularName, api);
    assert.ok(parsed.attributes, `Missing attributes in ${api}`);

    if (userOwnedApis.includes(api)) {
      assert.ok(parsed.attributes.owner, `Missing owner relation in ${api}`);
      assert.equal(parsed.attributes.owner.target, 'plugin::users-permissions.user');
    }
    if (colocationScopedApis.includes(api)) {
      assert.equal(parsed.attributes.colocation?.target, 'api::colocation.colocation');
    }
    if (api === 'study-group') {
      assert.ok(parsed.attributes.creator, 'Missing creator relation in study-group');
      assert.ok(parsed.attributes.members, 'Missing members relation in study-group');
    }
  }
});
