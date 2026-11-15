import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Configuration centralisée de l'environnement API Strapi.
///
/// Par défaut, l'application pointe sur le serveur local `http://localhost:1337`
/// (avec bascule automatique vers `http://10.0.2.2:1337` sur émulateur Android).
/// Pour surcharger l'URL :
/// `flutter run --dart-define=STRAPI_URL=https://...`
abstract final class ApiConfig {
  static const String _envUrl = String.fromEnvironment('STRAPI_URL');
  static const String _localUrl = 'http://localhost:1337';
  static const String _androidEmulatorUrl = 'http://10.0.2.2:1337';

  static const Duration timeout = Duration(seconds: 15);

  /// URL racine du serveur Strapi (sans `/api` final).
  static String get baseUrl {
    if (_envUrl.isNotEmpty) {
      return _envUrl.endsWith('/') ? _envUrl.substring(0, _envUrl.length - 1) : _envUrl;
    }
    // Sur un émulateur Android, localhost pointe vers l'émulateur lui-même.
    // L'alias pour joindre la machine hôte est 10.0.2.2.
    if (!kIsWeb && Platform.isAndroid) {
      return _androidEmulatorUrl;
    }
    return _localUrl;
  }

  /// URL de base des endpoints REST Strapi (`/api`).
  static String get apiBaseUrl => '$baseUrl/api';
}

