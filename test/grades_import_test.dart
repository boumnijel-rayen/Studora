import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studora/core/core.dart';
import 'package:studora/features/grades/models/grade_models.dart';
import 'package:studora/features/grades/providers/grades_providers.dart';

void main() {
  test('ScannedGrade.fromJson reads a matched grade and tolerates missing fields', () {
    final matched = ScannedGrade.fromJson({
      'subjectId': 'sub-math',
      'subjectName': 'Mathématiques',
      'title': 'Partiel',
      'value': 14,
      'originalValue': 7,
      'originalScale': 10,
      'coefficient': 2,
      'date': '2026-10-12',
      'uncertain': true,
    });
    expect(matched.subjectId, 'sub-math');
    expect(matched.value, 14.0);
    expect(matched.originalScale, 10.0);
    expect(matched.date, DateTime(2026, 10, 12));
    expect(matched.uncertain, isTrue);

    final bare = ScannedGrade.fromJson({'subjectId': null, 'subjectName': 'Physique', 'value': 9.5});
    expect(bare.subjectId, isNull);
    expect(bare.coefficient, 1.0);
    expect(bare.originalScale, 20.0);
    expect(bare.date, isNull);
    expect(bare.uncertain, isFalse);
  });

  test('scanDocument posts the file as base64 and parses the proposed grades', () async {
    String? capturedMethod;
    Uri? capturedUri;
    Map<String, dynamic>? capturedBody;

    final client = StrapiClient(
      tokenStorage: TokenStorage(),
      baseUrl: 'http://localhost:1337/api',
      transport: (method, uri, {required headers, body}) async {
        if (uri.path.endsWith('/grades/import-scan')) {
          capturedMethod = method;
          capturedUri = uri;
          capturedBody = jsonDecode(body!) as Map<String, dynamic>;
          return HttpTransportResponse(
            statusCode: 200,
            body: jsonEncode({
              'data': {
                'count': 2,
                'grades': [
                  {
                    'subjectId': 'sub-math',
                    'subjectName': 'Mathématiques',
                    'title': 'Partiel',
                    'value': 14,
                    'originalValue': 14,
                    'originalScale': 20,
                    'coefficient': 2,
                    'date': '2026-10-12',
                    'uncertain': false,
                  },
                  {
                    'subjectId': null,
                    'subjectName': 'Physique',
                    'title': 'TP 1',
                    'value': 15,
                    'originalValue': 7.5,
                    'originalScale': 10,
                    'coefficient': 1,
                    'date': null,
                    'uncertain': true,
                  },
                ],
              },
            }),
          );
        }
        return const HttpTransportResponse(statusCode: 200, body: '{"data":[]}');
      },
    );

    final container = ProviderContainer(
      overrides: [strapiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    final grades = await container
        .read(gradesAsyncProvider.notifier)
        .scanDocument(bytes: Uint8List.fromList(utf8.encode('hello')), mimeType: 'image/png');

    expect(capturedMethod, 'POST');
    expect(capturedUri.toString(), 'http://localhost:1337/api/grades/import-scan');
    expect(capturedBody, {
      'data': {'fileBase64': 'aGVsbG8=', 'mimeType': 'image/png'},
    });
    expect(grades.length, 2);
    expect(grades[0].subjectId, 'sub-math');
    expect(grades[1].subjectId, isNull);
    expect(grades[1].value, 15.0);
    expect(grades[1].uncertain, isTrue);
  });

  test('scanDocument surfaces the backend error message', () async {
    final client = StrapiClient(
      tokenStorage: TokenStorage(),
      baseUrl: 'http://localhost:1337/api',
      transport: (method, uri, {required headers, body}) async => HttpTransportResponse(
        statusCode: uri.path.endsWith('/grades/import-scan') ? 503 : 200,
        body: uri.path.endsWith('/grades/import-scan')
            ? jsonEncode({
                'data': null,
                'error': {'status': 503, 'message': 'Import non configuré.'},
              })
            : '{"data":[]}',
      ),
    );
    final container = ProviderContainer(
      overrides: [strapiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(gradesAsyncProvider.notifier)
          .scanDocument(bytes: Uint8List(1), mimeType: 'application/pdf'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Import non configuré.')),
    );
  });
}
