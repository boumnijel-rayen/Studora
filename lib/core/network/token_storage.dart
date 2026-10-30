import 'dart:io';

import 'package:flutter/foundation.dart';

/// Stockage du jeton d'authentification JWT.
///
/// En mémoire + persistance fichier local (hors Web) lorsque l'utilisateur
/// coche « Se souvenir », sans exposer de secret backend dans le code.
class TokenStorage {
  String? _token;
  bool _persist = true;

  String? get token => _token;

  File? _sessionFile() {
    if (kIsWeb) return null;
    try {
      final dir = Directory.systemTemp;
      return File('${dir.path}/studora_session.jwt');
    } catch (_) {
      return null;
    }
  }

  Future<String?> readToken() async {
    if (_token != null) return _token;
    final file = _sessionFile();
    if (file == null) return null;
    try {
      if (await file.exists()) {
        final raw = (await file.readAsString()).trim();
        if (raw.isNotEmpty) {
          _token = raw;
          return _token;
        }
      }
    } catch (_) {
      // Ignore les erreurs d'accès disque en environnement de test/sandbox
    }
    return null;
  }

  Future<void> saveToken(String token, {bool rememberMe = true}) async {
    _token = token;
    _persist = rememberMe;
    final file = _sessionFile();
    if (file == null) return;
    try {
      if (_persist) {
        await file.writeAsString(token, flush: true);
      } else if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore en environnement de test
    }
  }

  Future<void> clearToken() async {
    _token = null;
    final file = _sessionFile();
    if (file == null) return;
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

