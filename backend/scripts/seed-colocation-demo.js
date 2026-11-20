'use strict';

/**
 * Données de démonstration du module Colocation, pour un Strapi LOCAL (SQLite).
 *
 * Crée 5 comptes sur le plan Ultimate (mot de passe commun : Test1234!), une colocation
 * qui réunit 4 d'entre eux, un colocataire sans compte, puis des tâches, des dépenses,
 * un remboursement et des messages. Les dates sont calculées à partir du jour où le script
 * est lancé : le lancer le jour de la démonstration.
 *
 * Usage (Strapi ARRÊTÉ, depuis le dossier backend) :
 *   node scripts/seed-colocation-demo.js
 *   node scripts/seed-colocation-demo.js --join ton@email.com   (ajoute aussi un compte existant)
 *
 * Sécurité : refuse de s'exécuter sur une base PostgreSQL (le serveur partagé sur Neon),
 * sauf avec l'option --allow-remote-db. Relancer le script ne crée pas de doublons.
 */

const path = require('node:path');

process.chdir(path.join(__dirname, '..'));

const fs = require('node:fs');

/** Base de données configurée (variable d'environnement ou backend/.env), sqlite par défaut. */
function configuredDatabaseClient() {
  if (process.env.DATABASE_CLIENT) return process.env.DATABASE_CLIENT;
  try {
    const env = fs.readFileSync(path.join(process.cwd(), '.env'), 'utf8');
    const match = env.match(/^\s*DATABASE_CLIENT\s*=\s*['"]?([\w-]+)/m);
    if (match) return match[1];
  } catch (_) {
    // Pas de .env : Strapi utilisera SQLite.
  }
  return 'sqlite';
}

if (configuredDatabaseClient() !== 'sqlite' && !process.argv.includes('--allow-remote-db')) {
  console.error(
    '❌ La base configurée n\'est pas SQLite (DATABASE_CLIENT=' + configuredDatabaseClient() + ').\n' +
      '   Ce script est prévu pour un Strapi local : il ne modifie pas la base partagée.\n' +
      '   (Option --allow-remote-db pour forcer, à vos risques.)',
  );
  process.exit(1);
}

const { createStrapi, compileStrapi } = require('@strapi/strapi');
const { generateUniqueCode } = require('../src/utils/sanitize');

const PASSWORD = 'Test1234!';
const COLOCATION_NAME = 'Coloc Test – Les Berges du Lac';

const ACCOUNTS = [
  { firstName: 'Aziz', lastName: 'Créateur', email: 'aziz.coloc@studora.test', room: 'Chambre 1' },
  { firstName: 'Sarra', lastName: 'Ben Ali', email: 'sarra.coloc@studora.test', room: 'Chambre 2' },
  { firstName: 'Youssef', lastName: 'Trabelsi', email: 'youssef.coloc@studora.test', room: 'Chambre 3' },
  { firstName: 'Lina', lastName: 'Mansour', email: 'lina.coloc@studora.test', room: 'Chambre 4' },
];

// Utilisateur sans colocation, pour tester « Rejoindre avec une clé ».
const OUTSIDER = {
  firstName: 'Karim',
  lastName: 'Sans Coloc',
  email: 'karim.solo@studora.test',
};

const USER_UID = 'plugin::users-permissions.user';
const COLOC_UID = 'api::colocation.colocation';
const MEMBER_UID = 'api::roommate-member.roommate-member';
const CHORE_UID = 'api::chore.chore';
const EXPENSE_UID = 'api::expense.expense';
const MESSAGE_UID = 'api::colocation-message.colocation-message';
const SUB_UID = 'api::subscription.subscription';

function argValue(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : null;
}

function daysFromNow(days, hour = 18) {
  const d = new Date();
  d.setDate(d.getDate() + days);
  d.setHours(hour, 0, 0, 0);
  return d.toISOString();
}

async function findOrCreateUser(strapi, account, roleId) {
  const email = account.email.toLowerCase();
  const existing = await strapi.db.query(USER_UID).findOne({ where: { email } });
  if (existing) return { user: existing, created: false };

  const user = await strapi.plugin('users-permissions').service('user').add({
    username: email,
    email,
    password: PASSWORD,
    provider: 'local',
    confirmed: true,
    blocked: false,
    role: roleId,
    firstName: account.firstName,
    lastName: account.lastName,
    university: 'ESPRIT',
    program: 'Test',
    year: 4,
  });
  return { user, created: true };
}

async function upgradeToUltimate(strapi, userId) {
  const service = strapi.service(SUB_UID);
  const row = await service.ensureForUser(userId);
  await strapi.documents(SUB_UID).update({
    documentId: row.documentId,
    data: {
      plan: 'ultimate',
      status: 'active',
      cancelAtPeriodEnd: false,
      pendingPlan: null,
      currentPeriodStart: new Date().toISOString(),
      currentPeriodEnd: daysFromNow(365),
    },
  });
}

async function activeMembership(strapi, userId) {
  return strapi.documents(MEMBER_UID).findFirst({
    filters: { user: { id: { $eq: userId } }, isActive: { $eq: true } },
    populate: { colocation: true },
  });
}

function displayName(user) {
  return `${user.firstName || ''} ${user.lastName || ''}`.trim() || user.email;
}

async function addMember(strapi, colocation, user, room, ownerId) {
  return strapi.documents(MEMBER_UID).create({
    data: {
      name: displayName(user),
      email: user.email,
      phone: '',
      roomNumber: room,
      isPresent: true,
      isActive: true,
      user: user.id,
      owner: ownerId,
      colocation: colocation.documentId,
    },
  });
}

async function seed(strapi) {
  const role = await strapi.db
    .query('plugin::users-permissions.role')
    .findOne({ where: { type: 'authenticated' } });
  if (!role) throw new Error('Rôle « authenticated » introuvable : lancez d\'abord `npm run develop` une fois.');

  // 1. Comptes + plan Ultimate
  const users = [];
  for (const account of ACCOUNTS) {
    const { user, created } = await findOrCreateUser(strapi, account, role.id);
    await upgradeToUltimate(strapi, user.id);
    users.push({ ...account, user, created });
  }
  const outsider = await findOrCreateUser(strapi, OUTSIDER, role.id);
  await upgradeToUltimate(strapi, outsider.user.id);

  const joinEmail = argValue('--join');
  let joinUser = null;
  if (joinEmail) {
    joinUser = await strapi.db.query(USER_UID).findOne({ where: { email: joinEmail.trim().toLowerCase() } });
    if (!joinUser) {
      console.warn(`⚠ Aucun compte local avec l'e-mail ${joinEmail} : inscris-toi d'abord dans l'app.`);
    } else {
      await upgradeToUltimate(strapi, joinUser.id);
    }
  }

  // 2. Colocation (une seule fois)
  const creator = users[0].user;
  const creatorMembership = await activeMembership(strapi, creator.id);
  let colocation = creatorMembership?.colocation ?? null;
  let colocationCreated = false;

  if (!colocation) {
    colocation = await strapi.documents(COLOC_UID).create({
      data: {
        name: COLOCATION_NAME,
        address: '12 rue du Lac Léman, Les Berges du Lac, Tunis',
        details: 'Données de démonstration créées par scripts/seed-colocation-demo.js',
        code: await generateUniqueCode(strapi, COLOC_UID),
        creator: creator.id,
      },
    });
    colocationCreated = true;
  }

  // 3. Membres avec compte
  const members = [];
  for (const entry of users) {
    const membership = await activeMembership(strapi, entry.user.id);
    if (membership) {
      if (membership.colocation?.documentId !== colocation.documentId) {
        console.warn(`⚠ ${entry.email} est déjà dans une autre colocation : ignoré.`);
        continue;
      }
      members.push(membership);
    } else {
      members.push(await addMember(strapi, colocation, entry.user, entry.room, creator.id));
    }
  }

  if (joinUser) {
    const membership = await activeMembership(strapi, joinUser.id);
    if (!membership) {
      members.push(await addMember(strapi, colocation, joinUser, 'Chambre 5', creator.id));
    } else if (membership.colocation?.documentId !== colocation.documentId) {
      console.warn(`⚠ ${joinUser.email} est déjà dans une autre colocation : quitte-la d'abord dans l'app.`);
    }
  }

  // 4. Contenu de démonstration (seulement à la création de la colocation)
  if (colocationCreated) {
    const noAccount = await strapi.documents(MEMBER_UID).create({
      data: {
        name: 'Mehdi (sans compte)',
        email: 'mehdi.invite@studora.test',
        phone: '+216 20 000 000',
        roomNumber: 'Chambre 6',
        isPresent: false,
        isActive: true,
        owner: creator.id,
        colocation: colocation.documentId,
      },
    });
    const everyone = [...members, noAccount];
    const [m0, m1, m2, m3] = members;

    // Toutes ces tâches sont visibles le jour de la démonstration (période en cours ou en retard).
    // Les occurrences suivantes, créées à la validation, restent masquées jusqu'à leur période.
    const [u0, u1] = [users[0].user.id, (users[1] ?? users[0]).user.id];
    const chores = [
      { title: 'Arroser les plantes', who: m1, by: u0, due: 0, frequency: 'Quotidien' },
      { title: 'Sortir les poubelles', who: m0, by: u0, due: 0, frequency: 'Hebdomadaire' },
      { title: 'Laver la salle de bain', who: m2, by: u0, due: -2, frequency: 'Hebdomadaire' },
      { title: 'Faire les courses communes', who: m3 ?? m0, by: u1, due: 0, frequency: 'Mensuel' },
      { title: 'Nettoyer la cuisine', who: noAccount, by: u0, due: 0, frequency: 'Hebdomadaire' },
      { title: 'Payer la facture STEG', who: m0, by: u1, due: 3, frequency: 'Une seule fois' },
      { title: 'Détartrer le chauffe-eau', who: m1, by: u1, due: 0, frequency: 'Annuel' },
    ];
    for (const chore of chores) {
      await strapi.documents(CHORE_UID).create({
        data: {
          title: chore.title,
          dueDate: daysFromNow(chore.due),
          frequency: chore.frequency,
          isCompleted: false,
          assignedTo: chore.who.documentId,
          assignedToName: chore.who.name,
          colocation: colocation.documentId,
          owner: chore.by,
        },
      });
    }

    // Chaque dépense est saisie par la personne qui l'a payée (seule elle peut la supprimer).
    const userOf = (i) => (users[i] ?? users[0]).user.id;
    const expenses = [
      { title: 'Courses Carrefour', amount: 86.4, payer: m0, by: userOf(0), category: 'Alimentation', days: -6, among: everyone },
      { title: 'Facture internet', amount: 59.9, payer: m1, by: userOf(1), category: 'Factures', days: -4, among: members },
      { title: 'Produits ménagers', amount: 24.5, payer: m2, by: userOf(2), category: 'Ménage', days: -2, among: members },
      { title: 'Pizza du vendredi', amount: 42, payer: m3 ?? m1, by: userOf(m3 ? 3 : 1), category: 'Autre', days: -1, among: [m0, m1, m3 ?? m2] },
    ];
    for (const exp of expenses) {
      await strapi.documents(EXPENSE_UID).create({
        data: {
          title: exp.title,
          amount: exp.amount,
          category: exp.category,
          date: daysFromNow(exp.days, 12),
          isSettlement: false,
          paidBy: exp.payer.documentId,
          paidByName: exp.payer.name,
          participants: exp.among.map((m) => m.documentId),
          colocation: colocation.documentId,
          owner: exp.by,
        },
      });
    }

    await strapi.documents(EXPENSE_UID).create({
      data: {
        title: `Remboursement : ${m2.name} → ${m0.name}`,
        amount: 10,
        paidBy: m2.documentId,
        paidByName: m2.name,
        reimbursedTo: m0.documentId,
        reimbursedToName: m0.name,
        isSettlement: true,
        date: daysFromNow(-1, 20),
        category: 'Remboursement',
        colocation: colocation.documentId,
        owner: userOf(2),
      },
    });

    const messages = [
      [users[0], 'Bienvenue dans la coloc ! 🏠'],
      [users[1], 'Merci ! Qui s\'occupe des courses cette semaine ?'],
      [users[2], 'Je peux y aller samedi.'],
      [users[3] ?? users[1], 'Parfait, j\'ai ajouté la facture internet.'],
    ];
    for (let i = 0; i < messages.length; i++) {
      const [author, text] = messages[i];
      await strapi.documents(MESSAGE_UID).create({
        data: {
          text,
          senderName: displayName(author.user),
          timestamp: new Date(Date.now() - (messages.length - i) * 15 * 60 * 1000).toISOString(),
          colocation: colocation.documentId,
          sender: author.user.id,
        },
      });
    }
  }

  // 5. Vérification : le mot de passe des comptes créés fonctionne bien
  const userService = strapi.plugin('users-permissions').service('user');
  for (const entry of users) {
    const fresh = await strapi.db.query(USER_UID).findOne({ where: { id: entry.user.id } });
    entry.passwordOk = entry.created
      ? await userService.validatePassword(PASSWORD, fresh.password)
      : null;
  }

  const fullColoc = await strapi.documents(COLOC_UID).findOne({ documentId: colocation.documentId });

  console.log('\n✅ Données de démonstration prêtes (Strapi LOCAL)\n');
  console.log(`Colocation : ${fullColoc.name}`);
  console.log(`Clé d'invitation : ${fullColoc.code}\n`);
  console.log('Comptes (mot de passe commun : ' + PASSWORD + ') :');
  for (const entry of users) {
    const status = entry.created ? (entry.passwordOk ? 'créé' : 'créé ⚠ mot de passe à vérifier') : 'existant';
    console.log(`  • ${entry.email.padEnd(30)} ${entry === users[0] ? '(créateur) ' : ''}[${status}]`);
  }
  console.log(`  • ${OUTSIDER.email.padEnd(30)} (Ultimate, sans colocation → teste « Rejoindre » avec la clé)`);
  if (joinUser) console.log(`  • ${joinUser.email.padEnd(30)} (ton compte, ajouté à la colocation)`);
  console.log('');
}

(async () => {
  const appContext = await compileStrapi();
  const strapi = await createStrapi(appContext).load();
  strapi.log.level = 'error';
  let exitCode = 0;
  try {
    await seed(strapi);
  } catch (err) {
    console.error('❌ Échec du seed :', err);
    exitCode = 1;
  } finally {
    await strapi.destroy();
  }
  process.exit(exitCode);
})();
