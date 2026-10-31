# Déployer le backend partagé (Render + Neon)

## 1. Créer la base sur Neon

1. Créer un compte sur https://neon.com, puis un projet PostgreSQL.
2. Dans **Connect**, désactiver **Connection pooling** : l'hôte ne doit pas contenir `-pooler`.
3. Noter l'hôte, le nom de la base, l'utilisateur et le mot de passe.

## 2. Créer le service sur Render

1. Créer un compte sur https://render.com et lui donner accès au dépôt GitHub.
2. Choisir **New > Blueprint**, puis le dépôt Studora : Render lit `render.yaml`.
3. Saisir `DATABASE_HOST`, `DATABASE_NAME`, `DATABASE_USERNAME` et `DATABASE_PASSWORD`.
4. Lancer le déploiement. Les secrets Strapi sont générés par Render.

## 3. Vérifier

Ouvrir `https://<service>.onrender.com/_health` : une page vide (code 204) indique que le serveur tourne.

Créer ensuite le compte administrateur sur `https://<service>.onrender.com/admin`. Le premier visiteur de cette page devient administrateur : le faire tout de suite.

## 4. Lancer l'application

L'application utilise par défaut le serveur partagé (`lib/core/network/api_config.dart`) : lancer simplement **Run** dans Android Studio.

Pour travailler avec un Strapi local sur l'émulateur Android :

```bash
flutter run --dart-define=STRAPI_URL=http://10.0.2.2:1337
```

## Limites à connaître

- **Mise en veille :** après 15 minutes sans trafic, le serveur met jusqu'à une minute à redémarrer, alors que l'application abandonne une requête après 15 secondes. Ouvrir d'abord l'adresse `/_health` dans un navigateur, puis attendre la réponse.
- **Modèles de données :** l'éditeur de modèles de l'admin est désactivé en production. Modifier les modèles en local, puis les pousser sur la branche déployée.
- **Déploiement :** chaque push sur la branche choisie dans Render redéploie le serveur et met à jour la structure de la base.
- **Quotas Neon :** 0,5 Go de stockage ; une fois un quota mensuel atteint, la base est suspendue jusqu'au mois suivant.
- **Fichiers :** le disque de Render est effacé à chaque redémarrage. Un envoi de fichiers exigerait un stockage externe.
- **Sauvegardes :** à faire régulièrement avec `pg_dump` ; Neon ne les garantit pas sur l'offre gratuite.
