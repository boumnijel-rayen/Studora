import 'dart:js_interop';

import 'api_exception.dart';
import 'http_transport.dart';

@JS('fetch')
external JSPromise<_FetchResponse> _fetch(JSString url, JSObject init);

extension type _FetchResponse._(JSObject _) implements JSObject {
  external int get status;
  external JSPromise<JSString> text();
}

/// Transport HTTP par défaut dans le navigateur (API `fetch`), car `dart:io`
/// n'y est pas disponible.
Future<HttpTransportResponse> defaultHttpTransport(
  String method,
  Uri uri, {
  required Map<String, String> headers,
  String? body,
}) async {
  final init = <String, Object>{
    'method': method,
    'headers': headers,
    'body': ?body,
  }.jsify()! as JSObject;

  try {
    final response = await _fetch(uri.toString().toJS, init).toDart;
    final text = await response.text().toDart;
    return HttpTransportResponse(statusCode: response.status, body: text.toDart);
  } catch (_) {
    // Le navigateur ne détaille pas la cause (serveur arrêté, CORS, réseau).
    throw const ApiException(
      kind: ApiErrorKind.network,
      message: 'Impossible de se connecter au serveur Strapi. Vérifiez que le backend est démarré et votre connexion réseau.',
    );
  }
}
