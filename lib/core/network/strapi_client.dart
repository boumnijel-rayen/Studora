import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_config.dart';
import 'api_exception.dart';
import 'token_storage.dart';

/// Signature d'un transport HTTP injectable (facilite les tests unitaires/widgets).
typedef HttpTransport = Future<HttpTransportResponse> Function(
  String method,
  Uri uri, {
  required Map<String, String> headers,
  String? body,
});

class HttpTransportResponse {
  const HttpTransportResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

/// Client HTTP centralisé pour communiquer avec le backend Strapi.
///
/// Responsabilités :
/// - Ajout automatique du header `Authorization: Bearer <jwt>`
/// - Sérialisation / désérialisation JSON et normalisation des entités Strapi v4/v5
/// - Traduction des codes HTTP et erreurs socket en [ApiException] typées
/// - Notification automatique en cas de session expirée (401)
class StrapiClient {
  StrapiClient({
    required TokenStorage tokenStorage,
    String? baseUrl,
    HttpTransport? transport,
    this.onUnauthorized,
  })  : _tokenStorage = tokenStorage,
        _baseUrl = baseUrl ?? ApiConfig.apiBaseUrl,
        _transport = transport ?? _defaultTransport;

  final TokenStorage _tokenStorage;
  final String _baseUrl;
  final HttpTransport _transport;
  final void Function()? onUnauthorized;

  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    var normalizedPath = path.startsWith('/') ? path : '/$path';
    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    if (base.endsWith('/api') && normalizedPath.startsWith('/api/')) {
      normalizedPath = normalizedPath.substring(4);
    }
    final uri = Uri.parse('$base$normalizedPath');
    if (queryParameters == null || queryParameters.isEmpty) return uri;

    final stringParams = <String, String>{};
    queryParameters.forEach((key, value) {
      if (value != null) {
        stringParams[key] = value.toString();
      }
    });
    return uri.replace(queryParameters: {...uri.queryParameters, ...stringParams});
  }

  Map<String, String> _headers({required bool authenticated}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
    };
    if (authenticated) {
      final token = _tokenStorage.token;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) => _send(
    'GET',
    path,
    queryParameters: queryParameters,
    authenticated: authenticated,
  );

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool wrapData = true,
    bool authenticated = true,
  }) => _send(
    'POST',
    path,
    body: body == null ? null : (wrapData ? {'data': body} : body),
    authenticated: authenticated,
  );

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    bool wrapData = true,
    bool authenticated = true,
  }) => _send(
    'PUT',
    path,
    body: body == null ? null : (wrapData ? {'data': body} : body),
    authenticated: authenticated,
  );

  Future<dynamic> delete(
    String path, {
    bool authenticated = true,
  }) => _send(
    'DELETE',
    path,
    authenticated: authenticated,
  );

  /// Récupère et normalise une liste d'entités Strapi depuis `GET <path>`.
  Future<List<Map<String, dynamic>>> getList(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) async {
    final json = await get(
      path,
      queryParameters: queryParameters,
      authenticated: authenticated,
    );
    return unwrapList(json);
  }

  /// Récupère et normalise une entité unique Strapi depuis `GET <path>`.
  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) async {
    final json = await get(
      path,
      queryParameters: queryParameters,
      authenticated: authenticated,
    );
    return unwrapMap(json);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
    required bool authenticated,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final headers = _headers(authenticated: authenticated);
    final encodedBody = body == null ? null : jsonEncode(body);

    HttpTransportResponse response;
    try {
      response = await _transport(
        method,
        uri,
        headers: headers,
        body: encodedBody,
      ).timeout(ApiConfig.timeout);
    } on TimeoutException {
      throw const ApiException(
        kind: ApiErrorKind.network,
        message: 'Le serveur Strapi ne répond pas (délai d\'attente dépassé).',
      );
    } on SocketException {
      throw const ApiException(
        kind: ApiErrorKind.network,
        message: 'Impossible de se connecter au serveur Strapi. Vérifiez que le backend est démarré et votre connexion réseau.',
      );
    } on HttpException {
      throw const ApiException(
        kind: ApiErrorKind.network,
        message: 'Erreur de communication HTTP avec le serveur Strapi.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        kind: ApiErrorKind.network,
        message: 'Connexion au serveur impossible : $e',
      );
    }

    dynamic decoded;
    if (response.body.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }

    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      return decoded;
    }

    final errorMessage = _extractStrapiErrorMessage(decoded, status);
    final errorDetails = decoded is Map<String, dynamic> && decoded['error'] is Map<String, dynamic>
        ? (decoded['error'] as Map<String, dynamic>)['details'] as Map<String, dynamic>?
        : null;

    if (status == 401) {
      if (authenticated) {
        onUnauthorized?.call();
      }
      throw ApiException(
        kind: ApiErrorKind.unauthorized,
        statusCode: status,
        message: errorMessage ?? 'Identifiants invalides ou session expirée. Veuillez vous reconnecter.',
        details: errorDetails,
      );
    }

    if (status == 403) {
      throw ApiException(
        kind: ApiErrorKind.forbidden,
        statusCode: status,
        message: errorMessage ?? 'Vous n\'avez pas les permissions nécessaires pour effectuer cette action.',
        details: errorDetails,
      );
    }

    if (status == 404) {
      throw ApiException(
        kind: ApiErrorKind.notFound,
        statusCode: status,
        message: errorMessage ?? 'La ressource demandée est introuvable.',
        details: errorDetails,
      );
    }

    if (status == 400 || status == 422) {
      throw ApiException(
        kind: ApiErrorKind.validation,
        statusCode: status,
        message: errorMessage ?? 'Les données envoyées sont invalides.',
        details: errorDetails,
      );
    }

    if (status >= 500) {
      throw ApiException(
        kind: ApiErrorKind.server,
        statusCode: status,
        message: errorMessage ?? 'Le serveur Strapi a rencontré une erreur interne ($status).',
        details: errorDetails,
      );
    }

    throw ApiException(
      kind: ApiErrorKind.unknown,
      statusCode: status,
      message: errorMessage ?? 'Erreur HTTP $status',
      details: errorDetails,
    );
  }

  static String? _extractStrapiErrorMessage(dynamic decoded, int statusCode) {
    if (decoded is Map<String, dynamic>) {
      final err = decoded['error'];
      if (err is Map<String, dynamic>) {
        final msg = err['message']?.toString();
        if (msg != null && msg.isNotEmpty) {
          return _translateCommonStrapiMessage(msg);
        }
      }
      final msg = decoded['message']?.toString();
      if (msg != null && msg.isNotEmpty) {
        return _translateCommonStrapiMessage(msg);
      }
    }
    return null;
  }

  static String _translateCommonStrapiMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid identifier or password')) {
      return 'Adresse e-mail ou mot de passe incorrect.';
    }
    if (lower.contains('email or username are already taken') ||
        lower.contains('already taken')) {
      return 'Cette adresse e-mail est déjà associée à un compte.';
    }
    if (lower.contains('your account email is not confirmed')) {
      return 'Veuillez confirmer votre adresse e-mail avant de vous connecter.';
    }
    if (lower.contains('your account has been blocked')) {
      return 'Ce compte a été suspendu par un administrateur.';
    }
    return raw;
  }

  /// Aplatit une entité Strapi v4 (`{ id, attributes: {...} }`) ou v5 (`{ documentId, id, ... }`)
  /// en une `Map<String, dynamic>` uniforme contenant toujours une clé `id` (String).
  static Map<String, dynamic> normalizeEntity(Map<String, dynamic> raw) {
    final result = <String, dynamic>{};

    if (raw['attributes'] is Map<String, dynamic>) {
      result.addAll(raw['attributes'] as Map<String, dynamic>);
    } else {
      result.addAll(raw);
    }

    final docId = raw['documentId'] ?? result['documentId'] ?? raw['id'] ?? result['id'];
    if (docId != null) {
      result['id'] = docId.toString();
    }

    // Normalise récursivement les relations imbriquées éventuelles (`{ data: ... }`)
    for (final entry in result.entries.toList()) {
      final val = entry.value;
      if (val is Map<String, dynamic> && val.containsKey('data')) {
        final inner = val['data'];
        if (inner is Map<String, dynamic>) {
          result[entry.key] = normalizeEntity(inner);
        } else if (inner is List) {
          result[entry.key] = inner
              .whereType<Map<String, dynamic>>()
              .map(normalizeEntity)
              .toList();
        } else if (inner == null) {
          result[entry.key] = null;
        }
      } else if (val is Map<String, dynamic> &&
          (val.containsKey('documentId') || val.containsKey('attributes'))) {
        result[entry.key] = normalizeEntity(val);
      }
    }

    return result;
  }

  static Map<String, dynamic> unwrapMap(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final inner = payload['data'];
      if (inner is Map<String, dynamic>) {
        return normalizeEntity(inner);
      }
      return normalizeEntity(payload);
    }
    throw const ApiException(
      kind: ApiErrorKind.unknown,
      message: 'Format de réponse Strapi inattendu.',
    );
  }

  static List<Map<String, dynamic>> unwrapList(dynamic payload) {
    if (payload is List) {
      return payload.whereType<Map<String, dynamic>>().map(normalizeEntity).toList();
    }
    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().map(normalizeEntity).toList();
      }
    }
    return const [];
  }

  static Future<HttpTransportResponse> _defaultTransport(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    String? body,
  }) async {
    final client = HttpClient()..connectionTimeout = ApiConfig.timeout;
    try {
      final request = await client.openUrl(method, uri);
      headers.forEach(request.headers.set);
      if (body != null) {
        final bytes = utf8.encode(body);
        request.contentLength = bytes.length;
        request.add(bytes);
      }
      final response = await request.close();
      final responseBody = await utf8.decodeStream(response);
      return HttpTransportResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } finally {
      client.close(force: false);
    }
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// Compteur incrémenté lorsqu'un appel API retourne 401 (session expirée).
class SessionExpiredNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void notifyExpired() => state++;
}

final sessionExpiredProvider =
    NotifierProvider<SessionExpiredNotifier, int>(SessionExpiredNotifier.new);

final strapiClientProvider = Provider<StrapiClient>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  return StrapiClient(
    tokenStorage: storage,
    onUnauthorized: () {
      storage.clearToken();
      ref.read(sessionExpiredProvider.notifier).notifyExpired();
    },
  );
});
