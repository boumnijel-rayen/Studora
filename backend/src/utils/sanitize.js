'use strict';

const crypto = require('crypto');

const PRIVATE_FIELDS = new Set(['password', 'resetPasswordToken', 'confirmationToken']);
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/**
 * Supprime récursivement les champs privés : `strapi.documents()` les renvoie
 * tels quels et un contrôleur personnalisé ne les filtre pas automatiquement.
 */
function stripPrivateFields(value) {
  if (Array.isArray(value)) return value.map(stripPrivateFields);
  if (value instanceof Date || value === null || typeof value !== 'object') return value;
  return Object.fromEntries(
    Object.entries(value)
      .filter(([key]) => !PRIVATE_FIELDS.has(key))
      .map(([key, val]) => [key, stripPrivateFields(val)]),
  );
}

function userDisplayName(user) {
  const full = `${user.firstName || ''} ${user.lastName || ''}`.trim();
  return full || user.username || user.email || 'Étudiant';
}

function randomCode(length = 8) {
  let code = '';
  for (let i = 0; i < length; i++) {
    code += CODE_ALPHABET[crypto.randomInt(CODE_ALPHABET.length)];
  }
  return code;
}

/** Génère un code d'invitation aléatoire non encore utilisé pour ce Content Type. */
async function generateUniqueCode(strapi, uid) {
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = randomCode();
    const existing = await strapi.documents(uid).findFirst({ filters: { code: { $eq: code } } });
    if (!existing) return code;
  }
  throw new Error('Impossible de générer un code d\'invitation unique.');
}

module.exports = {
  stripPrivateFields,
  userDisplayName,
  randomCode,
  generateUniqueCode,
};
