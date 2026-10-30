import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:studora/core/core.dart';
import 'package:studora/features/roommates/providers/roommates_providers.dart';
import 'package:studora/features/roommates/screens/add_expense_screen.dart';
import 'package:studora/features/roommates/screens/colocation_chat_screen.dart';
import 'package:studora/features/roommates/screens/roommates_home_screen.dart';
import 'package:studora/features/roommates/screens/roommates_list_screen.dart';

/// Backend minimal en mémoire, suffisant pour parcourir les écrans du module.
class _FakeBackend {
  Map<String, dynamic>? colocation;
  final messages = <Map<String, dynamic>>[];
  final expenses = <Map<String, dynamic>>[];
  final members = <Map<String, dynamic>>[
    {
      'documentId': 'me',
      'name': 'Camille Durand',
      'roomNumber': 'Chambre 1',
      'hasAccount': true,
      'isMe': true,
      'isOwner': true,
      'isActive': true,
    },
    {
      'documentId': 'other',
      'name': 'Thomas Petit',
      'roomNumber': 'Chambre 2',
      'hasAccount': false,
      'isMe': false,
      'isActive': true,
    },
  ];

  Future<HttpTransportResponse> handle(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    String? body,
  }) async {
    final path = uri.path;
    final data = body == null ? null : (jsonDecode(body) as Map<String, dynamic>)['data'];

    HttpTransportResponse ok(Object? payload) =>
        HttpTransportResponse(statusCode: 200, body: jsonEncode({'data': payload}));

    if (path.endsWith('/auth/local')) {
      return HttpTransportResponse(
        statusCode: 200,
        body: jsonEncode({
          'jwt': 'token',
          'user': {'id': 1, 'email': 'c@univ.fr', 'firstName': 'Camille', 'lastName': 'Durand'},
        }),
      );
    }
    if (path.endsWith('/colocations/mine')) return ok(colocation);
    if (method == 'POST' && path.endsWith('/colocations')) {
      colocation = {
        'documentId': 'col',
        'name': data['name'],
        'address': data['address'],
        'code': 'ABCD2345',
        'isCreator': true,
      };
      return ok(colocation);
    }
    if (path.endsWith('/colocations/leave')) {
      colocation = null;
      return ok({'left': true});
    }
    if (path.endsWith('/roommate-members')) return ok(colocation == null ? [] : members);
    if (method == 'GET' && path.endsWith('/colocation-messages')) return ok(messages);
    if (method == 'POST' && path.endsWith('/colocation-messages')) {
      messages.add({
        'documentId': 'm${messages.length}',
        'text': data['text'],
        'senderName': 'Camille Durand',
        'timestamp': '2026-10-30T10:00:00.000Z',
        'isMe': true,
      });
      return ok(messages.last);
    }
    if (method == 'POST' && path.endsWith('/expenses')) {
      expenses.add({'documentId': 'e', ...data as Map<String, dynamic>});
      return ok(expenses.last);
    }
    return ok(<Object>[]);
  }
}

void main() {
  late _FakeBackend backend;
  late ProviderContainer container;

  setUpAll(() => initializeDateFormatting('fr_FR'));

  setUp(() async {
    backend = _FakeBackend();
    final storage = TokenStorage();
    container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        strapiClientProvider.overrideWithValue(
          StrapiClient(tokenStorage: storage, baseUrl: 'http://test/api', transport: backend.handle),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionProvider.notifier).login(identifier: 'c@univ.fr', password: 'x');
  });

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('without a colocation the home screen offers create and join, then opens the dashboard', (tester) async {
    await pumpScreen(tester, const RoommatesHomeScreen());
    expect(find.text('Rejoindre un groupe'), findsOneWidget);
    expect(find.text('Créer un groupe'), findsNothing);

    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();
    expect(find.text('Créer un groupe'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'ex: Appart Victor Hugo'), 'Appart Test');
    await tester.tap(find.text('Créer le groupe'));
    await tester.pumpAndSettle();
    expect(backend.colocation, isNull, reason: 'the address is required');

    await tester.enterText(find.widgetWithText(TextFormField, 'ex: 12 rue Victor Hugo, Tunis'), '12 rue Test');
    await tester.tap(find.text('Créer le groupe'));
    await tester.pumpAndSettle();

    expect(backend.colocation?['name'], 'Appart Test');
    expect(find.text('Appart Test'), findsWidgets);
    expect(find.text('12 rue Test'), findsOneWidget);
    expect(find.textContaining('ABCD2345'), findsOneWidget);
    expect(find.text('Rejoindre un groupe'), findsNothing);
    expect(find.text('Colocataires (2)'), findsOneWidget);
  });

  testWidgets('members screen shows the invite code and leaving asks for confirmation', (tester) async {
    await container.read(colocationAsyncProvider.notifier).create(name: 'Appart', address: '1 rue');
    await pumpScreen(tester, const RoommatesListScreen());

    expect(find.textContaining('ABCD2345'), findsOneWidget);
    expect(find.text('Camille Durand (vous)'), findsOneWidget);
    expect(find.text('Propriétaire du groupe'), findsOneWidget);
    expect(find.text('Sans compte Studora'), findsOneWidget);

    await tester.tap(find.text('Quitter la colocation'));
    await tester.pumpAndSettle();
    expect(backend.colocation, isNotNull, reason: 'nothing happens before the confirmation');
    expect(find.text('Quitter la colocation ?'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(backend.colocation, isNotNull);
  });

  testWidgets('new expense is shared between the selected members only', (tester) async {
    await container.read(colocationAsyncProvider.notifier).create(name: 'Appart', address: '1 rue');
    await container.read(roommatesAsyncProvider.future);
    await pumpScreen(tester, const AddExpenseScreen());

    expect(find.widgetWithText(FilterChip, 'Thomas Petit'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Thomas Petit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'ex: 45.80'), '12,50');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ex: Courses supermarché, Sacs poubelles, Détergent...'),
      'Pain',
    );
    await tester.tap(find.text('Enregistrer la dépense'));
    await tester.pump();

    final saved = backend.expenses.single;
    expect(saved['amount'], 12.5);
    expect(saved['paidById'], 'me');
    expect(saved['participantIds'], ['me']);
    await tester.pumpAndSettle();
  });

  testWidgets('chat sends a message and shows it', (tester) async {
    await container.read(colocationAsyncProvider.notifier).create(name: 'Appart', address: '1 rue');
    await pumpScreen(tester, const ColocationChatScreen());
    expect(find.text('Aucun message'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Écrire un message...'), 'Bonjour');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(backend.messages.single['text'], 'Bonjour');
    expect(find.text('Bonjour'), findsOneWidget);
    expect(find.text('Aucun message'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
