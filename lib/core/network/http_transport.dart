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
