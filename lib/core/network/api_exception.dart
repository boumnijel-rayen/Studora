/// Catégorie d'erreur API permettant à l'interface d'afficher l'état approprié.
enum ApiErrorKind {
  /// Impossible de joindre le serveur (hors-ligne, DNS, timeout, connexion refusée).
  network,

  /// Session absente ou expirée (HTTP 401).
  unauthorized,

  /// Permissions insuffisantes pour cette ressource (HTTP 403).
  forbidden,

  /// Ressource introuvable (HTTP 404).
  notFound,

  /// Erreur de validation des données envoyées (HTTP 400 / 422).
  validation,

  /// Erreur interne du serveur Strapi (HTTP 5xx).
  server,

  /// Autre erreur inattendue.
  unknown,
}

/// Exception métier normalisée levée par [StrapiClient].
class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.details,
  });

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;

  bool get isNetwork => kind == ApiErrorKind.network;
  bool get isUnauthorized => kind == ApiErrorKind.unauthorized;
  bool get isForbidden => kind == ApiErrorKind.forbidden;
  bool get isServer => kind == ApiErrorKind.server;
  bool get isValidation => kind == ApiErrorKind.validation;

  String get userTitle => switch (kind) {
    ApiErrorKind.network => 'Erreur de connexion réseau',
    ApiErrorKind.unauthorized => 'Session expirée',
    ApiErrorKind.forbidden => 'Accès non autorisé',
    ApiErrorKind.notFound => 'Contenu introuvable',
    ApiErrorKind.validation => 'Données invalides',
    ApiErrorKind.server => 'Erreur du serveur',
    ApiErrorKind.unknown => 'Une erreur est survenue',
  };

  @override
  String toString() => message;

  static ApiException fromError(Object error) {
    if (error is ApiException) return error;
    return ApiException(
      kind: ApiErrorKind.unknown,
      message: error.toString(),
    );
  }
}

