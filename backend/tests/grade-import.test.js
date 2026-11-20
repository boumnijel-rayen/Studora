'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  GradeImportError,
  MAX_FILE_BYTES,
  MAX_SCANS_PER_HOUR,
  parseUpload,
  normalizeScannedGrades,
  consumeScanQuota,
} = require('../src/utils/grade-import');

const SUBJECTS = [
  { documentId: 'sub-math', name: 'Mathématiques' },
  { documentId: 'sub-algo', name: 'Algorithmique' },
];

function raw(overrides = {}) {
  return {
    subjectName: 'Maths S1',
    matchedSubjectId: 'sub-math',
    title: 'Partiel',
    value: 14,
    scale: 20,
    coefficient: 2,
    date: '2026-10-12',
    uncertain: false,
    ...overrides,
  };
}

test('normalizeScannedGrades keeps a matched grade and uses the stored subject name', () => {
  const [grade] = normalizeScannedGrades([raw()], SUBJECTS);
  assert.deepEqual(grade, {
    subjectId: 'sub-math',
    subjectName: 'Mathématiques',
    title: 'Partiel',
    value: 14,
    originalValue: 14,
    originalScale: 20,
    coefficient: 2,
    date: '2026-10-12',
    uncertain: false,
  });
});

test('normalizeScannedGrades converts other scales to a grade out of 20', () => {
  const grades = normalizeScannedGrades([raw({ value: 7, scale: 10 }), raw({ value: 45, scale: 60 })], SUBJECTS);
  assert.deepEqual(grades.map((g) => g.value), [14, 15]);
  assert.equal(grades[0].originalScale, 10);
});

test('normalizeScannedGrades drops impossible values', () => {
  const grades = normalizeScannedGrades(
    [raw({ value: 25 }), raw({ value: -1 }), raw({ value: 'abc' }), raw({ value: 12 })],
    SUBJECTS,
  );
  assert.equal(grades.length, 1);
  assert.equal(grades[0].value, 12);
});

test('normalizeScannedGrades ignores a subject id that is not the user\'s', () => {
  const [grade] = normalizeScannedGrades([raw({ matchedSubjectId: 'someone-else', subjectName: 'Physique' })], SUBJECTS);
  assert.equal(grade.subjectId, null);
  assert.equal(grade.subjectName, 'Physique');
});

test('normalizeScannedGrades falls back to an exact subject name match', () => {
  const [grade] = normalizeScannedGrades([raw({ matchedSubjectId: null, subjectName: ' algorithmique ' })], SUBJECTS);
  assert.equal(grade.subjectId, 'sub-algo');
});

test('normalizeScannedGrades applies defaults for missing title, coefficient and date', () => {
  const [grade] = normalizeScannedGrades(
    [raw({ title: '  ', coefficient: null, date: '12/10/2026', scale: 0 })],
    SUBJECTS,
  );
  assert.equal(grade.title, 'Évaluation');
  assert.equal(grade.coefficient, 1);
  assert.equal(grade.date, null);
  assert.equal(grade.originalScale, 20);
});

test('normalizeScannedGrades rejects impossible calendar dates and tolerates non-arrays', () => {
  assert.equal(normalizeScannedGrades([raw({ date: '2026-02-31' })], SUBJECTS)[0].date, null);
  assert.deepEqual(normalizeScannedGrades(null, SUBJECTS), []);
});

test('parseUpload accepts a supported file and strips whitespace from the base64', () => {
  const upload = parseUpload({ mimeType: 'IMAGE/PNG', fileBase64: 'aGVs\nbG8=' });
  assert.deepEqual(upload, { mimeType: 'image/png', base64: 'aGVsbG8=' });
});

test('parseUpload rejects unsupported, empty and oversized files with a 400', () => {
  const cases = [
    { mimeType: 'text/plain', fileBase64: 'aGVsbG8=' },
    { mimeType: 'image/png', fileBase64: '' },
    { mimeType: 'image/png', fileBase64: 'pas du base64 !' },
    { mimeType: 'application/pdf', fileBase64: 'A'.repeat(Math.ceil((MAX_FILE_BYTES * 4) / 3) + 8) },
  ];
  for (const body of cases) {
    assert.throws(
      () => parseUpload(body),
      (error) => error instanceof GradeImportError && error.status === 400,
    );
  }
});

test('consumeScanQuota blocks after the hourly limit and frees up an hour later', () => {
  const userId = 'quota-test-user';
  const start = 1_000_000;
  for (let i = 0; i < MAX_SCANS_PER_HOUR; i += 1) {
    assert.equal(consumeScanQuota(userId, start + i), true);
  }
  assert.equal(consumeScanQuota(userId, start + 100), false);
  assert.equal(consumeScanQuota(userId, start + 60 * 60 * 1000 + 50), true);
});
