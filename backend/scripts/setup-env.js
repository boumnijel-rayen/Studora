'use strict';

/**
 * Génère un fichier `.env` avec des secrets aléatoires à partir de `.env.example`.
 * Usage : `npm run setup:env` (n'écrase jamais un .env existant).
 */
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const target = path.join(root, '.env');
const example = path.join(root, '.env.example');

if (fs.existsSync(target)) {
  console.log('.env existe déjà : aucune modification.');
  process.exit(0);
}

const secret = () => crypto.randomBytes(32).toString('base64');
const values = {
  APP_KEYS: [secret(), secret(), secret(), secret()].join(','),
  API_TOKEN_SALT: secret(),
  ADMIN_JWT_SECRET: secret(),
  TRANSFER_TOKEN_SALT: secret(),
  JWT_SECRET: secret(),
  ENCRYPTION_KEY: secret(),
};

const content = fs
  .readFileSync(example, 'utf8')
  .split(/\r?\n/)
  .map((line) => {
    const match = line.match(/^([A-Z_]+)=/);
    if (match && values[match[1]]) return `${match[1]}=${values[match[1]]}`;
    return line;
  })
  .join('\n');

fs.writeFileSync(target, content, { mode: 0o600 });
console.log('.env généré avec des secrets aléatoires.');

