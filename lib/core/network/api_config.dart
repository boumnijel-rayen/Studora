import 'package:flutter/foundation.dart';

/// Configuration centralisée de l'environnement API Strapi.
///
/// L'URL de base peut être surchargée au build ou à l'exécution via :
/// `flutter run --dart-define=STRAPI_URL=https://api.studora.app`
abstract final class ApiConfig {
  static const String _envUrl = String.fromEnvironment('STRAPI_URL');

  static const Duration timeout = Duration(seconds: 15);

  /// URL racine du serveur Strapi (sans `/api` final).
  static String get baseUrl {
    if (_envUrl.isNotEmpty) {
      return _envUrl.endsWith('/') ? _envUrl.substring(0, _envUrl.length - 1) : _envUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:1337';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:1337';
      default:
        return 'http://localhost:1337';
    }
  }

  /// URL de base des endpoints REST Strapi (`/api`).
  static String get apiBaseUrl => '$baseUrl/api';
}

