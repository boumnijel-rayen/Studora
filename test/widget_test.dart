import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studora/app/app.dart';
import 'package:studora/core/core.dart';
import 'package:studora/features/grades/models/grade_models.dart';
import 'package:studora/features/grades/providers/grades_providers.dart';
import 'package:studora/features/groups/providers/groups_providers.dart';
import 'package:studora/features/roommates/providers/roommates_providers.dart';
import 'package:studora/features/schedule/models/schedule_models.dart';
import 'package:studora/features/schedule/providers/schedule_providers.dart';
import 'package:studora/features/study/providers/study_providers.dart';

void main() {
  test('StrapiClient normalizes Strapi v4 and v5 entities and injects JWT Bearer header', () async {
    final storage = TokenStorage();
    await storage.saveToken('jwt-token-123');

    String? capturedAuthHeader;
    final client = StrapiClient(
      tokenStorage: storage,
      baseUrl: 'http://localhost:1337/api',
      transport: (method, uri, {required headers, body}) async {
        capturedAuthHeader = headers['Authorization'];
        return HttpTransportResponse(
          statusCode: 200,
          body: jsonEncode({
            'data': [
              {
                'documentId': 'doc-v5',
                'name': 'Algorithmique',
                'shortName': 'Algo',
                'colorIndex': 1,
              },
              {
                'id': 42,
                'attributes': {
                  'name': 'Mathématiques',
                  'shortName': 'Maths',
                  'colorIndex': 0,
                },
              },
            ],
          }),
        );
      },
    );

    final list = await client.getList('/subjects');
    expect(capturedAuthHeader, 'Bearer jwt-token-123');
    expect(list.length, 2);
    expect(list[0]['id'], 'doc-v5');
    expect(list[0]['name'], 'Algorithmique');
    expect(list[1]['id'], '42');
    expect(list[1]['name'], 'Mathématiques');
  });

  test('StrapiClient triggers onUnauthorized and throws ApiException on 401', () async {
    final storage = TokenStorage();
    await storage.saveToken('expired-jwt');
    var unauthorizedCalled = false;

    final client = StrapiClient(
      tokenStorage: storage,
      baseUrl: 'http://localhost:1337/api',
      onUnauthorized: () {
        unauthorizedCalled = true;
      },
      transport: (method, uri, {required headers, body}) async {
        return HttpTransportResponse(
          statusCode: 401,
          body: jsonEncode({
            'error': {'status': 401, 'message': 'Invalid token'},
          }),
        );
      },
    );

    await expectLater(
      () => client.get('/users/me'),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.unauthorized),
      ),
    );
    expect(unauthorizedCalled, isTrue);
  });

  test('Session, Preferences & Feature Modules communicate with Strapi API without mock data', () async {
    final storage = TokenStorage();

    final mockClient = StrapiClient(
      tokenStorage: storage,
      baseUrl: 'http://localhost:1337/api',
      transport: (method, uri, {required headers, body}) async {
        final path = uri.path;

        if (method == 'POST' && path.endsWith('/auth/local')) {
          return HttpTransportResponse(
            statusCode: 200,
            body: jsonEncode({
              'jwt': 'valid-jwt-token',
              'user': {
                'id': 1,
                'email': 'etudiant@univ.fr',
                'firstName': 'Camille',
                'lastName': 'Durand',
                'university': 'Université Paris-Saclay',
                'program': 'Licence 3 Informatique',
                'semester': 'Semestre 5',
                'studentId': 'ETU-2026-001',
                'role': {'type': 'authenticated', 'name': 'Authenticated'},
              },
            }),
          );
        }

        if (method == 'GET' && path.endsWith('/users/me')) {
          return HttpTransportResponse(
            statusCode: 200,
            body: jsonEncode({
              'id': 1,
              'email': 'etudiant@univ.fr',
              'firstName': 'Camille',
              'lastName': 'Durand',
              'university': 'Université Paris-Saclay',
              'program': 'Licence 3 Informatique',
              'semester': 'Semestre 5',
              'studentId': 'ETU-2026-001',
              'role': {'type': 'authenticated', 'name': 'Authenticated'},
            }),
          );
        }

        if (method == 'GET' && path.endsWith('/user-preferences/me')) {
          return HttpTransportResponse(
            statusCode: 200,
            body: jsonEncode({
              'data': {
                'documentId': 'pref-1',
                'themeMode': 'dark',
                'notificationsEnabled': true,
                'reminderMinutesBefore': 30,
                'currency': '€',
                'onboardingSeen': true,
                'pomodoroWorkMinutes': 25,
                'pomodoroShortBreakMinutes': 5,
                'pomodoroLongBreakMinutes': 15,
                'pomodoroSessionsBeforeLongBreak': 4,
              },
            }),
          );
        }

        if (method == 'GET' && path.endsWith('/courses')) {
          return HttpTransportResponse(
            statusCode: 200,
            body: jsonEncode({
              'data': [
                {
                  'documentId': 'course-1',
                  'subjectId': 'sub-1',
                  'subjectName': 'Algorithmique',
                  'room': 'Amphi A',
                  'teacher': 'Pr. Bernard',
                  'dayOfWeek': DateTime.now().weekday,
                  'startTime': '08:30',
                  'endTime': '10:30',
                  'colorIndex': 1,
                },
              ],
            }),
          );
        }

        if (method == 'POST' && path.endsWith('/courses')) {
          final decoded = jsonDecode(body!) as Map<String, dynamic>;
          final data = decoded['data'] as Map<String, dynamic>;
          return HttpTransportResponse(
            statusCode: 201,
            body: jsonEncode({
              'data': {
                'documentId': 'course-2',
                ...data,
              },
            }),
          );
        }

        if (method == 'GET' && path.endsWith('/study-tasks')) {
          return HttpTransportResponse(
            statusCode: 200,
            body: jsonEncode({
              'data': [
                {
                  'documentId': 'task-1',
                  'title': 'Réviser les arbres binaires',
                  'subjectId': 'sub-1',
                  'isCompleted': false,
                },
              ],
            }),
          );
        }

        if (method == 'GET' && path.endsWith('/study-groups')) {
          return HttpTransportResponse(
            statusCode: 200,
            body: jsonEncode({
              'data': [
                {
                  'documentId': 'grp-1',
                  'name': 'Groupe Algo L3',
                  'subjectId': 'sub-1',
                  'subjectName': 'Algorithmique',
                  'description': 'Entraide TD',
                  'code': 'STU-1234',
                  'colorIndex': 1,
                  'memberNames': ['Camille Durand', 'Thomas Petit'],
                },
              ],
            }),
          );
        }

        if (method == 'GET' && path.endsWith('/grades')) {
          return HttpTransportResponse(
            statusCode: 200,
            body: jsonEncode({
              'data': [
                {
                  'documentId': 'grade-1',
                  'subjectId': 'sub-1',
                  'subjectName': 'Algorithmique',
                  'title': 'Partiel 1',
                  'value': 16.0,
                  'coefficient': 2.0,
                  'date': '2026-10-15T00:00:00.000Z',
                },
              ],
            }),
          );
        }

        if (method == 'GET' && path.endsWith('/roommate-members')) {
          return HttpTransportResponse(
            statusCode: 200,
            body: jsonEncode({
              'data': [
                {
                  'documentId': 'rm-1',
                  'name': 'Camille Durand',
                  'phone': '06 11 22 33 44',
                  'email': 'camille@univ.fr',
                  'roomNumber': 'Chambre 1',
                  'isPresent': true,
                },
                {
                  'documentId': 'rm-2',
                  'name': 'Thomas Petit',
                  'phone': '06 55 66 77 88',
                  'email': 'thomas@univ.fr',
                  'roomNumber': 'Chambre 2',
                  'isPresent': true,
                },
              ],
            }),
          );
        }

        if (method == 'GET' && path.endsWith('/expenses')) {
          return HttpTransportResponse(
            statusCode: 200,
            body: jsonEncode({
              'data': [
                {
                  'documentId': 'exp-1',
                  'title': 'Courses communes',
                  'amount': 40.0,
                  'paidByName': 'Camille Durand',
                  'date': '2026-10-20T00:00:00.000Z',
                  'category': 'Alimentation',
                  'isSettlement': false,
                },
              ],
            }),
          );
        }

        return HttpTransportResponse(
          statusCode: 200,
          body: jsonEncode({'data': []}),
        );
      },
    );

    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        strapiClientProvider.overrideWithValue(mockClient),
      ],
    );
    addTearDown(container.dispose);

    // 1. Connexion utilisateur
    await container.read(sessionProvider.notifier).login(
      identifier: 'etudiant@univ.fr',
      password: 'Password123!',
    );
    final user = container.read(currentUserProvider);
    expect(user, isNotNull);
    expect(user?.fullName, 'Camille Durand');
    expect(storage.token, 'valid-jwt-token');

    // 2. Module Planning (cours récupérés + ajout CRUD)
    final courses = await container.read(coursesAsyncProvider.future);
    expect(courses.length, 1);
    expect(courses.first.subjectName, 'Algorithmique');

    final addedCourse = await container.read(coursesAsyncProvider.notifier).add(
      const Course(
        id: '',
        subjectId: 'sub-1',
        subjectName: 'Algorithmique',
        room: 'Salle 102',
        teacher: 'M. Leroy',
        dayOfWeek: 2,
        startTime: TimeOfDay(hour: 14, minute: 0),
        endTime: TimeOfDay(hour: 16, minute: 0),
        colorIndex: 1,
      ),
    );
    expect(addedCourse.id, 'course-2');
    expect(container.read(coursesProvider).length, 2);

    // 3. Module Révisions (tâches)
    final tasks = await container.read(studyTasksAsyncProvider.future);
    expect(tasks.length, 1);
    expect(tasks.first.title, 'Réviser les arbres binaires');

    // 4. Module Groupes
    final groups = await container.read(groupsAsyncProvider.future);
    expect(groups.length, 1);
    expect(groups.first.code, 'STU-1234');

    // 5. Module Notes & Moyennes
    final grades = await container.read(gradesAsyncProvider.future);
    expect(grades.length, 1);
    expect(container.read(overallAverageProvider), 16.0);
    expect(
      Grade(
        id: 'g',
        subjectId: 's',
        subjectName: 'S',
        title: 'T',
        value: 16,
        coefficient: 1,
        date: DateTime(2026),
      ).value,
      16.0,
    );

    // 6. Module Colocation & calcul dynamique des soldes
    await container.read(roommatesAsyncProvider.future);
    await container.read(expensesAsyncProvider.future);
    final balances = container.read(balancesDueProvider);
    expect(balances.length, 1);
    expect(balances.first.fromPerson, 'Thomas Petit');
    expect(balances.first.toPerson, 'Camille Durand');
    expect(balances.first.amount, 20.0);
    expect(container.read(netUserBalanceProvider), 20.0);
  });

  testWidgets('StudoraApp démarre sur le Splash et redirige vers l\'authentification sans données mockées', (tester) async {
    final storage = TokenStorage();
    final offlineClient = StrapiClient(
      tokenStorage: storage,
      baseUrl: 'http://localhost:1337/api',
      transport: (method, uri, {required headers, body}) async {
        return HttpTransportResponse(
          statusCode: 200,
          body: jsonEncode({'data': null}),
        );
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(storage),
          strapiClientProvider.overrideWithValue(offlineClient),
        ],
        child: const StudoraApp(),
      ),
    );

    expect(find.text('Studora'), findsOneWidget);
    expect(find.text('Organise tes études, simplement.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
  });
}
