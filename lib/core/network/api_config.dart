/// Configuration centralisée de l'environnement API Strapi.
///
/// Par défaut, l'application utilise le serveur partagé de l'équipe. Pour viser
/// un Strapi local (émulateur Android) :
/// `flutter run --dart-define=STRAPI_URL=http://10.0.2.2:1337`
abstract final class ApiConfig {
  static const String _envUrl = String.fromEnvironment('STRAPI_URL');
  static const String _sharedUrl = 'https://studora-api-lz9u.onrender.com';

  static const Duration timeout = Duration(seconds: 15);

  /// URL racine du serveur Strapi (sans `/api` final).
  static String get baseUrl {
    if (_envUrl.isNotEmpty) {
      return _envUrl.endsWith('/') ? _envUrl.substring(0, _envUrl.length - 1) : _envUrl;
    }
    return _sharedUrl;
  }

  /// URL de base des endpoints REST Strapi (`/api`).
  static String get apiBaseUrl => '$baseUrl/api';
}

