import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studora/core/core.dart';
import 'package:studora/features/auth/screens/subscription_screen.dart';

void main() {
  group('Modèles d\'abonnement et matrice des accès', () {
    test('Core, Plus et Ultimate exposent les bons prix et fonctionnalités', () {
      expect(PlanTier.core.priceMonthly, 0);
      expect(PlanTier.core.defaultFeatures, isEmpty);

      expect(PlanTier.plus.priceMonthly, 9);
      expect(PlanTier.plus.defaultFeatures, [AppFeature.studyGroups]);

      expect(PlanTier.ultimate.priceMonthly, 14);
      expect(
        PlanTier.ultimate.defaultFeatures,
        [AppFeature.studyGroups, AppFeature.roommates],
      );

      expect(AppFeature.studyGroups.minimumPlan, PlanTier.plus);
      expect(AppFeature.roommates.minimumPlan, PlanTier.ultimate);
    });

    test('UserSubscription.fromJson active uniquement les fonctionnalités autorisées', () {
      final coreSub = UserSubscription.fromJson({
        'plan': 'core',
        'status': 'active',
        'features': <String>[],
      });
      expect(coreSub.hasFeature(AppFeature.studyGroups), isFalse);
      expect(coreSub.hasFeature(AppFeature.roommates), isFalse);

      final plusSub = UserSubscription.fromJson({
        'plan': 'plus',
        'status': 'active',
        'features': ['studyGroups'],
        'renewsAt': '2026-12-15T00:00:00.000Z',
      });
      expect(plusSub.hasFeature(AppFeature.studyGroups), isTrue);
      expect(plusSub.hasFeature(AppFeature.roommates), isFalse);
      expect(plusSub.isPaidActive, isTrue);
      expect(plusSub.renewsAt, isNotNull);

      final ultimateSub = UserSubscription.fromJson({
        'plan': 'ultimate',
        'status': 'active',
        'features': ['studyGroups', 'roommates'],
      });
      expect(ultimateSub.hasFeature(AppFeature.studyGroups), isTrue);
      expect(ultimateSub.hasFeature(AppFeature.roommates), isTrue);
    });

    test('StrapiClient traduit 403 PLAN_UPGRADE_REQUIRED en ApiErrorKind.planRequired', () async {
      var planRequiredCalled = false;
      final client = StrapiClient(
        tokenStorage: TokenStorage(),
        baseUrl: 'http://test/api',
        onPlanRequired: () => planRequiredCalled = true,
        transport: (method, uri, {required headers, body}) async {
          return HttpTransportResponse(
            statusCode: 403,
            body: jsonEncode({
              'data': null,
              'error': {
                'status': 403,
                'name': 'PolicyError',
                'message': 'Cette fonctionnalité nécessite le plan Plus.',
                'details': {
                  'code': 'PLAN_UPGRADE_REQUIRED',
                  'feature': 'studyGroups',
                  'currentPlan': 'core',
                  'requiredPlan': 'plus',
                },
              },
            }),
          );
        },
      );

      await expectLater(
        () => client.get('/study-groups'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isPlanRequired, 'isPlanRequired', isTrue)
              .having((e) => e.requiredPlan, 'requiredPlan', 'plus')
              .having((e) => e.lockedFeature, 'lockedFeature', 'studyGroups'),
        ),
      );
      expect(planRequiredCalled, isTrue);
    });
  });

  testWidgets('SubscriptionScreen affiche le plan actif et les 3 formules Core, Plus, Ultimate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final storage = TokenStorage();
    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        strapiClientProvider.overrideWithValue(
          StrapiClient(
            tokenStorage: storage,
            baseUrl: 'http://test/api',
            transport: (method, uri, {required headers, body}) async {
              if (uri.path.endsWith('/subscription/me')) {
                return HttpTransportResponse(
                  statusCode: 200,
                  body: jsonEncode({
                    'data': {
                      'plan': 'plus',
                      'subscribedPlan': 'plus',
                      'status': 'active',
                      'features': ['studyGroups'],
                      'cancelAtPeriodEnd': false,
                    },
                  }),
                );
              }
              return HttpTransportResponse(
                statusCode: 200,
                body: jsonEncode({'data': <Object>[]}),
              );
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(sessionProvider.notifier).signIn(
      const AppUser(
        id: '1',
        firstName: 'Camille',
        lastName: 'Durand',
        email: 'c@univ.fr',
      ),
    );
    await container.read(subscriptionProvider.notifier).fetchFromBackend();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SubscriptionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Studora Plus'), findsOneWidget);
    expect(find.text('PLAN ACTUEL'), findsOneWidget);
    expect(find.text('Passer au plan Ultimate (5 \$ au prorata)'), findsOneWidget);
    expect(find.text('Rétrograder vers Core'), findsOneWidget);
  });
}
