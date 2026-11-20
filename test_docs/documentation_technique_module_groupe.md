# Documentation Technique & Guide de Révision — Module Groupe d'Étude (Studora)

> [!NOTE]
> Ce document est spécialement rédigé pour vous (niveau débutant en Flutter) afin de préparer sereinement votre soutenance et validation technique et fonctionnelle avec votre professeur. Il détaille l'architecture complète, chaque classe, chaque modèle, chaque provider et les règles métier implémentées (Flutter + Backend Strapi 5).

---

## Sommaire
1. [Architecture Globale (Client-Serveur)](#1-architecture-globale-client-serveur)
2. [Le Backend : Strapi 5 (Modèles & Contrôleurs)](#2-le-backend--strapi-5-modèles--contrôleurs)
3. [Le Frontend Flutter : Modèles de Données (`group_models.dart`)](#3-le-frontend-flutter--modèles-de-données)
4. [Gestion d'État et Services (`groups_providers.dart`)](#4-gestion-détat-et-services)
5. [Les Écrans et Composants UI en Détail](#5-les-écrans-et-composants-ui-en-détail)
6. [Les Règles Métier Clés Implémentées & Validées](#6-les-règles-métier-clés-implémentées--validées)
7. [Foire Aux Questions (Q&A Professeur)](#7-foire-aux-questions-qa-professeur)

---

## 1. Architecture Globale (Client-Serveur)

L'application **Studora** repose sur une architecture moderne et réactive découplée :
- **Backend (Serveur Node.js / Strapi 5)** : Gère la base de données relationnelle (SQLite/PostgreSQL), l'authentification JWT, les droits d'accès et expose des API REST sécurisées (`/api/study-groups`, `/api/group-messages`, `/api/group-activities`).
- **Frontend (Application Mobile Flutter / Dart)** : Développé en architecture réactive avec **Riverpod** pour la gestion d'état asynchrone (`AsyncNotifier` & `FutureProvider.family`), et **GoRouter** pour la navigation.

---

## 2. Le Backend : Strapi 5 (Modèles & Contrôleurs)

### A. `StudyGroup` (`backend/src/api/study-group/controllers/study-group.js`)
- **Rôle** : Gère la création, la consultation, la suppression et l'adhésion aux groupes d'étude.
- **Sérialisation (`serializeGroup`)** : Masque le code d'invitation aux utilisateurs non-membres du groupe (`code: isJoined ? group.code : ''`).
- **Contrôle Admin (`joinByCode`)** : Vérifie si l'utilisateur tentant de rejoindre le groupe par code en est le créateur. Si oui, renvoie une erreur HTTP 400 (`badRequest`) avec un message explicite.

### B. `GroupMessage` (`backend/src/api/group-message/controllers/group-message.js`)
- **Rôle** : Enregistre et diffuse les messages textuels et les pièces jointes.
- **Sécurité** : Valide l'appartenance de l'u tilisateur via le middleware `isMemberOfGroup`.

### C. `GroupActivity` (`backend/src/api/group-activity/controllers/group-activity.js`)
- **Rôle** : Gère la planification et la suppression des séances de révision collective.
- **Contrôle de Date** : Refuse la création si la date transmise est antérieure à aujourd'hui (`activityDay < today`).
- **Suppression Robuste (`delete` & `remove`)** : Supprime l'activité par `documentId` ou `id` numérique avec validation de sécurité `isMemberOfGroup` et fallback direct en base de données.

### D. Helper de Sécurité (`backend/src/utils/study-groups.js`)
- **Méthode `isMemberOfGroup`** : Vérifie si un utilisateur est créateur ou membre d'un groupe. Elle normalise les identifiants (conversion `String(id)`) pour gérer en toute sécurité la compatibilité entre les IDs numériques et les `documentId` de Strapi 5.

---

## 3. Le Frontend Flutter : Modèles de Données

Fichier : [`lib/features/groups/models/group_models.dart`](file:///C:/Users/MSI/Studora/lib/features/groups/models/group_models.dart)

### 1. La classe `StudyGroup`
Représente un groupe d'étude.
- **Champs principaux** :
  - `id` : Identifiant unique (priorise `documentId` puis `id` numérique pour Strapi v5).
  - `name` : Nom du groupe (ex: *"Entraide Algorithmique"*).
  - `description` : Description et règles du groupe.
  - `subjectId` / `subjectName` : Matière rattachée.
  - `code` : Code d'invitation unique (ex: *"ALG104"*).
  - `memberNames` : Liste des noms des membres inscrits.
  - `isJoined` : Booléen indiquant si l'utilisateur connecté appartient au groupe.
- **Méthode `fromJson`** : Décode le JSON renvoyé par Strapi vers l'objet Dart typé.

### 2. La classe `GroupMessage`
Représente un message de discussion.
- **Champs de pièces jointes** : `attachmentName`, `attachmentUrl`, `attachmentType`, `attachmentSize`.
- **Getters malins** :
  - `hasAttachment` : Détecte si le message contient un document joint.
  - `resolvedAttachmentName` : Extrait proprement le nom du fichier.
  - `attachmentExtension` : Extrait l'extension (`pdf`, `docx`, `png`...) pour déterminer l'icône et la couleur adaptées.
  - `formattedAttachmentSize` : Formate la taille du fichier (ex: *"148.0 KB"*).

### 3. La classe `GroupActivity`
Représente une séance planifiée.
- **Champs** : `id`, `groupId`, `title`, `description`, `date` (`DateTime`), `location`, `time` (Horaire ex: *"19:00"*), `duration` (Durée estimée ex: *"2h"*), `participantNames`.

---

## 4. Gestion d'État et Services

Fichier : [`lib/features/groups/providers/groups_providers.dart`](file:///C:/Users/MSI/Studora/lib/features/groups/providers/groups_providers.dart)

### A. `GroupsAsyncNotifier` (Riverpod `AsyncNotifier`)
- Gère la liste globale des groupes sous forme de `AsyncValue<List<StudyGroup>>`.
- **`addGroup(...)`** : Crée un groupe via `POST /api/study-groups`.
- **`joinGroup(...)`** : Rejoint un groupe par code via `POST /api/study-groups/join`.

### B. `groupMessagesFamilyProvider` & `groupActivitiesFamilyProvider`
- Les `FutureProvider.family` qui chargent de manière isolée et réactive les messages et activités du groupe sélectionné.

### C. `GroupChatService`
- **`sendMessage(...)`** : Envoie un message textuel ou un fichier joint sur `/api/group-messages`.
- **`createActivity(...)`** : Crée une activité sur `/api/group-activities`.
- **`deleteActivity(activityId, groupId)`** : Envoie la requête de suppression à `/api/group-activities/$id` et invalide le provider pour rafraîchir l'affichage instantanément.

---

## 5. Les Écrans et Composants UI en Détail

1. **`GroupsHomeScreen`** ([groups_home_screen.dart](file:///C:/Users/MSI/Studora/lib/features/groups/screens/groups_home_screen.dart)) :
   - Vue principale listant vos groupes d'étude et les groupes disponibles.
2. **`CreateGroupScreen`** ([create_group_screen.dart](file:///C:/Users/MSI/Studora/lib/features/groups/screens/create_group_screen.dart)) :
   - Formulaire de création de groupe. Génère le code et définit le créateur comme admin.
3. **`JoinGroupScreen`** ([join_group_screen.dart](file:///C:/Users/MSI/Studora/lib/features/groups/screens/join_group_screen.dart)) :
   - Champ de saisie du code de groupe. Gère l'interdiction de s'auto-rejoindre pour le créateur.
4. **`GroupDetailScreen`** ([group_detail_screen.dart](file:///C:/Users/MSI/Studora/lib/features/groups/screens/group_detail_screen.dart)) :
   - Écran à 3 onglets (*Informations*, *Membres*, *Activités*).
   - Formulaire de création d'activité avec alerte rouge en cas de date invalide.
   - Onglet Activités avec badges dynamiques (**"À venir"** / **"Passée"**) et bouton de suppression sur confirmation.
5. **`GroupChatScreen`** & **`AppChatView`** ([group_chat_screen.dart](file:///C:/Users/MSI/Studora/lib/features/groups/screens/group_chat_screen.dart) & [app_chat.dart](file:///C:/Users/MSI/Studora/lib/core/design_system/widgets/app_chat.dart)) :
   - Chatroom avec modération anti-injures `BadWordsFilter`.
   - Bouton trombone 📎 (sélection locale ou documents d'exemple en 1 clic).
   - Espace dédié aux pièces jointes avec recherche textuelle et filtres (*Tous*, *PDF*, *Word*, *Images*, *Autres*).
   - Visionneuse interactive de documents (`_ChatAttachmentCard` avec prévisualisation et téléchargement).

---

## 6. Les Règles Métier Clés Implémentées & Validées

1. **Contrôle de date à la création de l'activité** :
   - *Principe* : Interdiction de sélectionner une date passée.
   - *Implémentation* : Restriction sur le calendrier (`firstDate: DateTime.now()`) et bandeau d'erreur rouge explicite dans le formulaire.
2. **Restriction du code de groupe pour l'Administrateur** :
   - *Principe* : Le créateur d'un groupe ne peut pas utiliser son propre code d'invitation pour se rejoindre.
   - *Implémentation* : Contrôle côté backend Strapi (`group.creator?.id === user.id`) et affichage d'un message d'erreur rouge côté mobile.
3. **Visualisation fonctionnelle des pièces jointes** :
   - *Principe* : Consultation et téléchargement des documents partagés.
   - *Implémentation* : Dialogue d'aperçu de contenu avec statut consultable et snackbar de confirmation de téléchargement.
4. **Gestion des Activités Passées (Statut & Suppression)** :
   - *Principe* : Détection automatique des séances passées, changement de badge (**"Passée"**) et possibilité de supprimer l'activité.
   - *Implémentation* : Comparaison avec la date du jour (`isBefore(today)`), affichage de l'icône poubelle rouge avec confirmation `AppConfirmDialog` et suppression effective en base de données.

---

## 7. Foire Aux Questions (Q&A Professeur)

- **Q : Comment l'application gère-t-elle la communication avec Strapi 5 ?**
  *R : Via la classe `StrapiClient` qui centralise les appels HTTP (GET, POST, DELETE), applique les tokens d'authentification Bearer JWT et convertit les exceptions d'API.*
- **Q : Comment la modération du chat est-elle assurée ?**
  *R : En amont de l'envoi par le composant `BadWordsFilter` qui analyse le texte et bloque le message en affichant un avertissement si des termes inappropriés sont détectés.*
- **Q : Comment fonctionne la suppression d'une activité passée ?**
  *R : Lorsqu'une activité est identifiée comme passée, le bouton de suppression envoie une requête DELETE à l'API Strapi qui vérifie les droits du membre et supprime la séance.*
