# Documentation Technique — Module Groupe d'Étude (Studora)

> [!NOTE]
> Ce document est conçu spécialement pour vous guider pas à pas et vous expliquer en détail l'architecture, les composants et le code source du **Module Groupe** de l'application Studora, afin de préparer sereinement votre soutenance et validation technique avec votre professeur.

---

## 1. Vue d'ensemble et Architecture globale

Le module **Groupe** permet aux étudiants de :
1. **Créer ou rejoindre** des groupes d'étude par code d'invitation unique.
2. **Discuter en temps réel** dans un chatroom dédié.
3. **Partager des documents** (PDF, Word, images, etc.) et consulter un espace exclusif regroupant toutes les pièces jointes de la discussion.
4. **Planifier des activités** de révision collective.

### Architecture Client-Serveur (Full-Stack)
- **Backend (Serveur)** : Développé avec **Strapi 5** (Node.js / SQLite). Il gère la base de données relationnelle, les routes API REST (`/api/study-groups`, `/api/group-messages`, `/api/group-activities`), l'authentification et les règles de sécurité.
- **Frontend (Application Mobile)** : Développé avec **Flutter** (Dart) en architecture réactive avec **Riverpod** pour la gestion d'état et **GoRouter** pour la navigation.

---

## 2. Le Backend (Strapi 5) : Modèles et Contrôleurs

Le backend repose sur 3 collections principales :

### A. `StudyGroup` (`api::study-group.study-group`)
- **Rôle** : Représente un groupe d'étude.
- **Champs principaux** :
  - `name` (Nom du groupe)
  - `description` (Description)
  - `code` (Code d'invitation unique généré automatiquement)
  - `subjectName` / `subjectId` (Matière associée)
  - `creator` (Relation vers l'utilisateur créateur / admin)
  - `members` (Relation Many-to-Many vers les membres)
  - `memberNames` (Liste textuelle des membres)
- **Contrôleur clé (`joinByCode`)** :
  - Vérifie si le code saisi correspond à un groupe.
  - **Contrôle Admin** : Interdit au créateur du groupe d'utiliser le code d'accès pour se rejoindre lui-même en double (*"En tant que créateur et administrateur..."*).

### B. `GroupMessage` (`api::group-message.group-message`)
- **Rôle** : Stocke les messages et les pièces jointes échangés dans le chatroom.
- **Champs principaux** :
  - `groupId` (Identifiant du groupe)
  - `text` (Contenu du message ou libellé de secours)
  - `senderName` (Nom de l'expéditeur)
  - `timestamp` (Date et heure d'envoi)
  - `attachmentName`, `attachmentUrl`, `attachmentType`, `attachmentSize` (Métadonnées du document joint).
- **Contrôleur (`create`)** :
  - Valide l'appartenance de l'utilisateur au groupe via `isMemberOfGroup`.
  - Enregistre le message et ses pièces jointes en base de données.

---

## 3. Le Frontend (Flutter) : Structure et Code

Le code Flutter du module est situé dans `lib/features/groups/` et s'articule ainsi :

### A. Les Modèles (`lib/features/groups/models/group_models.dart`)
- **`StudyGroup`** et **`GroupMessage`** convertissent les données JSON reçues de l'API en objets Dart typés.
- **Normalisation des ID (Strapi v5)** : Priorise `documentId` sur l'ID numérique pour garantir la compatibilité des requêtes.
- **Getters malins pour les pièces jointes** :
  - `hasAttachment` : Détecte si un message contient une pièce jointe (via métadonnées ou préfixe textuel).
  - `resolvedAttachmentName` : Extrait proprement le nom du fichier.
  - `attachmentExtension` : Détermine l'extension (`pdf`, `docx`, `txt`, etc.) pour afficher la bonne couleur et la bonne icône.

### C. Le Service et les Providers (`lib/features/groups/providers/groups_providers.dart`)
- **`GroupsAsyncNotifier`** : Gère la liste des groupes de l'utilisateur connecté via des appels HTTP asynchrones au client `StrapiClient`.
- **`GroupChatService`** : Fournit les méthodes `sendMessage(...)` (avec gestion des pièces jointes et fallback textuel) et `createActivity(...)`.

---

## 4. Les 5 Évolutions Clés Implémentées

### 1. Import et Envoi de Documents dans le Chat
- **Composant** : `AppChatView` et `file_picker`.
- **Fonctionnement** : L'utilisateur clique sur le bouton **Trombone 📎**, choisit soit de parcourir ses fichiers, soit de sélectionner un **document d'exemple en 1 clic** (*Devoir_Maths_Algebres.pdf*, *Rapport_Projet_Studora.docx*, etc.). Le fichier est prévisualisé avant l'envoi.

### 2. Espace Dédié aux Pièces Jointes (`_GroupAttachmentsSpace`)
- **Composant** : Deuxième onglet de l'écran `GroupChainScreen`.
- **Fonctionnement** : Filtre dynamiquement tous les messages du groupe pour n'afficher **que** les documents partagés.
- **Outils** : Barre de recherche instantanée et puces de filtrage par type (*Tous*, *PDF*, *Word*, *Images*, *Autres*).

### 3. Contrôle de Saisie sur les Activités (`GroupDetailScreen`)
- **Validation** : Lors de la création d'une activité de groupe, la date sélectionnée est comparée à la date du jour. Si elle est antérieure à aujourd'hui, l'envoi est bloqué et un message d'erreur clair s'affiche (*AppSnackbar*).

### 4. Restriction du Code de Groupe pour l'Admin
- **Sécurité** : Le créateur d'un groupe est automatiquement reconnu comme administrateur. S'il tente de saisir le code d'invitation de son propre groupe, le backend et le frontend l'en empêchent avec un message explicite.

### 5. Filtre de Modération "Bad Words" (`BadWordsFilter`)
- **Sécurité & Modération** : Avant d'envoyer tout message dans le chat, le texte est analysé par `BadWordsFilter`. Si un terme injurieux ou déplacé est détecté, l'envoi est bloqué instantanément et une alerte prévient l'utilisateur.

---

## 5. Questions / Réponses Fréquentes pour votre Professeur

- **Q : Comment Flutter communique-t-il avec Strapi ?**
  *R : Via le client HTTP centralisé `StrapiClient` qui gère l'authentification par token JWT, la sérialisation JSON automatique et la gestion des exceptions d'API.*
- **Q : Comment gérez-vous l'affichage exclusif des pièces jointes ?**
  *R : En filtrant la liste des messages de la discussion via le getter `hasAttachment` et en affichant ces éléments dans un onglet dédié doté d'une barre de recherche et de filtres par extension.*
- **Q : Comment fonctionne la sécurité sur l'envoi des messages ?**
  *R : Côté client avec le filtre anti-injures `BadWordsFilter`, et côté serveur avec le middleware `isMemberOfGroup` qui garantit que seul un membre légitime peut poster dans le groupe.*
