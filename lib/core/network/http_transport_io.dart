import 'dart:convert';
import 'dart:io';

import 'api_config.dart';
import 'api_exception.dart';
import 'http_transport.dart';

/// Transport HTTP par défaut sur mobile et desktop (`dart:io`).
Future<HttpTransportResponse> defaultHttpTransport(
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
  } finally {
    client.close(force: false);
  }
}
