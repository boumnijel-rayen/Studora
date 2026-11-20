# Module Colocation

Ce document décrit le module Colocation (onglet **Plus → Colocation**, plan **Ultimate**) :
ce qu'il permet de faire, les règles appliquées, les fichiers concernés, et comment
préparer une démonstration sur un autre ordinateur.

## Fonctionnalités

| Fonctionnalité | Ce que l'utilisateur peut faire |
|---|---|
| **Groupe de colocation** | Créer un groupe (il en devient le propriétaire) ou le rejoindre avec une clé d'invitation, puis le quitter |
| **Colocataires** | Voir les membres, ajouter une personne sans compte Studora, modifier sa fiche, indiquer s'il est présent ou absent |
| **Tâches ménagères** | Créer une tâche (ponctuelle, quotidienne, hebdomadaire, mensuelle ou annuelle), l'assigner à un colocataire, la valider, la réassigner |
| **Dépenses communes** | Saisir une dépense et choisir entre qui elle est partagée ; voir le total du mois et sa part |
| **Soldes** | Voir qui doit combien à qui (nombre d'échanges réduit au minimum) et enregistrer un remboursement |
| **Discussion** | Envoyer des messages à toute la colocation |
| **Notifications** | Recevoir une notification sur le téléphone quand un colocataire écrit, et voir une pastille rouge sur l'icône de discussion |

### Tâches récurrentes

- Quand une tâche récurrente est validée, le serveur crée l'occurrence suivante, assignée au
  colocataire suivant (rotation). Il n'y a jamais plus d'une occurrence en attente par tâche.
- Une tâche n'est affichée que pendant **sa période** : le jour même pour « Quotidien », la
  semaine en cours (lundi → dimanche) pour « Hebdomadaire », le mois en cours pour « Mensuel »,
  l'année en cours pour « Annuel ». L'occurrence suivante reste masquée jusque-là.
  Une tâche en retard reste affichée.
- Une tâche dont la période n'a pas commencé ne peut pas être validée (le serveur refuse).
- L'historique affiche les 5 dernières tâches faites, avec un bouton pour tout afficher.

### Qui peut faire quoi

Chacun ne gère que ce qui le concerne. Ces règles sont vérifiées **par le serveur** (une
requête non autorisée reçoit une erreur 403) ; l'application masque ou grise les actions
interdites.

| Action | Autorisée pour |
|---|---|
| Valider / annuler une tâche | Le colocataire assigné. Pour un colocataire sans compte : le créateur de la tâche ou le propriétaire du groupe |
| Réassigner une tâche | Le colocataire assigné ou le créateur de la tâche |
| Modifier / supprimer une tâche | Le créateur de la tâche (avec confirmation) |
| Saisir une dépense | Pour soi-même, ou pour un colocataire sans compte |
| Supprimer une dépense ou un remboursement | La personne qui l'a saisi (avec confirmation) |
| Enregistrer un remboursement (« Régler ») | La personne qui rembourse (avec confirmation). Si elle n'a pas de compte : la personne remboursée |
| Changer la présence | Sa propre fiche, ou celle d'un colocataire sans compte |
| Retirer un colocataire qui a un compte | Le propriétaire du groupe |

### Notifications des messages

- Tant que l'application est ouverte ou en arrière-plan, elle vérifie les nouveaux messages
  toutes les 15 secondes (`GET /api/colocation-messages?since=<date>`).
- Un message d'un autre colocataire déclenche une notification système et une pastille rouge
  sur l'icône de discussion, sauf si la discussion est déjà affichée.
- Toucher la notification ouvre la discussion. Ouvrir la discussion retire la pastille.
- Limite : rien n'est reçu quand l'application est complètement fermée (pas de serveur de
  notifications push).

## Fichiers

### Application Flutter (`lib/features/roommates/`)

| Fichier | Rôle |
|---|---|
| `roommates_module.dart` | Déclare le module : routes, carte du tableau de bord, démarrage des notifications |
| `roommates_routes.dart` | Chemins des écrans (`/roommates/...`) |
| `models/roommate_models.dart` | Données : colocation, colocataire, tâche, dépense, solde ; calcul des soldes |
| `providers/roommates_providers.dart` | État partagé (Riverpod) et appels au serveur |
| `services/colocation_message_notifications.dart` | Vérification des nouveaux messages, notifications, compteur de non-lus |
| `screens/` | Écrans : accueil, colocataires, tâches, dépenses, soldes, discussion, formulaires |
| `screens/roommate_picker.dart` | Sélecteur de colocataire (avatars) utilisé pour les tâches et les dépenses |

### Serveur Strapi (`backend/src/`)

| Fichier | Rôle |
|---|---|
| `api/colocation/` | Créer, rejoindre, quitter un groupe (`/api/colocations/...`) |
| `api/roommate-member/` | Colocataires |
| `api/chore/controllers/chore.js` | Tâches : droits, récurrence, affichage par période |
| `api/expense/controllers/expense.js` | Dépenses et remboursements : droits |
| `api/colocation-message/` | Discussion (paramètre `since`) |
| `utils/colocation.js` | Fonctions communes : appartenance au groupe, retrait d'un membre |

Les réponses de l'API indiquent les droits de l'utilisateur connecté : `canComplete`,
`canReassign` et `canDelete` sur les tâches, `canDelete` sur les dépenses.

### Fichiers partagés modifiés pour les notifications

| Fichier | Modification |
|---|---|
| `pubspec.yaml` / `pubspec.lock` | Paquet `flutter_local_notifications` |
| `android/app/build.gradle.kts` | « Core library desugaring », requis par ce paquet |
| `android/app/src/main/AndroidManifest.xml` | Permission `POST_NOTIFICATIONS` (Android 13+) |

### Tests

```bash
cd backend
npm test        # dont tests/chores.test.js et tests/expenses.test.js
```

```bash
flutter test test/roommates_screens_test.dart test/roommates_balances_test.dart
```

## Préparer une démonstration sur un autre ordinateur

La démonstration utilise un Strapi **local** (base SQLite sur l'ordinateur) : elle ne touche
pas aux données de l'équipe sur Neon, et ne dépend pas du serveur Render qui peut être endormi.

### 1. Prérequis

- **Flutter 3.32.8** (la version du projet) : `flutter --version`. Avec une version plus
  récente, le build Android échoue (versions minimales de Gradle et Kotlin). Pour passer à la
  bonne version dans le dossier du SDK Flutter :
  `git fetch --tags` puis `git checkout 3.32.8` puis `flutter --version`.
- **Node.js 18 à 22** : `node -v`.
- **Android Studio** avec, dans *Tools → SDK Manager → SDK Platforms*, **Android 15 (API 35)**.
- **Windows** : activer le **Mode développeur** (`start ms-settings:developers`), nécessaire
  aux paquets Flutter qui contiennent du code natif.
- Deux émulateurs Android (*Device Manager*), pour montrer deux colocataires en même temps.

### 2. Démarrer le serveur local avec les données de démonstration

```powershell
cd backend
npm install                          # la première fois seulement
npm run setup:env                    # la première fois seulement (crée backend/.env)
npm run develop                      # une première fois pour créer la base, puis Ctrl+C
node scripts/seed-colocation-demo.js
npm run develop                      # laisser cette fenêtre ouverte pendant la démo
```

Lancer `seed-colocation-demo.js` **le jour de la démonstration** : les dates des tâches et des
dépenses sont calculées à partir de ce jour. Le script refuse de s'exécuter sur une base
PostgreSQL, pour ne pas toucher au serveur partagé.

### 3. Lancer l'application sur les deux émulateurs

```powershell
flutter pub get
flutter run -d emulator-5554
```

Attendre la fin du premier build, puis, dans un second terminal : `flutter run -d emulator-5556`
(`flutter devices` donne les noms). Sans `--dart-define=STRAPI_URL=...`, l'application utilise
le serveur local (`http://10.0.2.2:1337`). Autoriser les notifications quand Android le demande.

### 4. Comptes de démonstration

Mot de passe commun : **`Test1234!`**

| Compte | Rôle dans la démo |
|---|---|
| `aziz.coloc@studora.test` | Propriétaire du groupe (émulateur 1) |
| `sarra.coloc@studora.test` | Colocataire (émulateur 2) |
| `youssef.coloc@studora.test` | Colocataire |
| `lina.coloc@studora.test` | Colocataire |
| `karim.solo@studora.test` | Plan Ultimate sans colocation : pour montrer « Rejoindre » avec la clé |
| Mehdi | Colocataire **sans compte** (fiche seulement) |

La clé d'invitation est affichée à la fin du script et sur l'écran **Colocataires**.

### 5. Scénario de démonstration (environ 5 minutes)

1. **Accueil colocation (Aziz)** : solde net, tâches de la période, colocataires, dépenses du mois.
2. **Tâches (Aziz)** : « Sortir les poubelles » est à Aziz : il la valide ; l'occurrence de la
   semaine prochaine, assignée au colocataire suivant, n'apparaît pas (période suivante).
   La case d'« Arroser les plantes » (assignée à Sarra) est grisée : seul l'assigné valide.
3. **Réassigner** : toucher le nom sous une tâche créée par Aziz et choisir un autre colocataire.
4. **Nouvelle tâche** : choisir le colocataire en touchant son avatar, fréquence « Annuel ».
5. **Tâches (Sarra)** : Sarra valide « Arroser les plantes ». Elle ne voit pas la corbeille sur
   les tâches créées par Aziz.
6. **Dépenses (Sarra)** : nouvelle dépense ; « Payé par » ne propose que Sarra et Mehdi (sans
   compte). La corbeille n'apparaît que sur ses propres saisies.
7. **Soldes** : Mehdi doit 17,28 à Aziz. Les autres voient « En attente de … » sauf sur leurs
   propres dettes ; « Régler » demande une confirmation.
8. **Discussion et notifications** : Aziz reste sur l'accueil ; Sarra envoie un message. Sous
   15 secondes, Aziz reçoit une notification et une pastille rouge apparaît sur l'icône de
   discussion ; elle disparaît en ouvrant la discussion.
9. **Rejoindre** : se connecter avec Karim et entrer la clé d'invitation.

### En cas de problème

| Problème | Solution |
|---|---|
| « Impossible de se connecter au serveur Strapi » | Vérifier que `npm run develop` tourne ; relancer l'application sans `STRAPI_URL` |
| Connexion refusée avec un compte de démo | Le script n'a pas été lancé, ou une autre base est utilisée : relancer le script |
| Le module Colocation est verrouillé | Le compte n'est pas sur Ultimate : relancer le script (il remet les comptes de démo sur Ultimate) |
| Pas de notification | Autoriser les notifications dans les réglages Android de l'application ; rester sur l'accueil, pas dans la discussion |
| Build : « Kotlin version », « Android Gradle Plugin » | Mauvaise version de Flutter : passer à 3.32.8 (voir Prérequis) |
| Build : « Failed to install Android SDK Platform 35 » | Installer API 35 dans le SDK Manager ; ne pas lancer deux builds en même temps |
| « Building with plugins requires symlink support » | Activer le Mode développeur Windows |
| Pour repartir de zéro | Supprimer la colocation dans le panneau d'administration (Content Manager → Colocation), puis relancer le script |
