import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_exception.dart';
import '../network/strapi_client.dart';
import '../services/session_service.dart';
import 'stripe_payment_service.dart';
import 'subscription_models.dart';

final stripePaymentServiceProvider = Provider<StripePaymentService>(
  (_) => const StripePaymentService(),
);

/// Catalogue des 3 plans d'abonnement récupéré depuis `GET /api/subscription/plans`
/// (avec repli sur la définition locale si le serveur est hors-ligne).
final subscriptionCatalogProvider = FutureProvider<List<SubscriptionPlanInfo>>((ref) async {
  final client = ref.watch(strapiClientProvider);
  try {
    final response = await client.get('/subscription/plans', authenticated: false);
    final items = StrapiClient.unwrapList(response);
    if (items.isNotEmpty) {
      final parsed = items.map(SubscriptionPlanInfo.fromJson).toList()
        ..sort((a, b) => a.tier.rank.compareTo(b.tier.rank));
      return parsed;
    }
  } catch (_) {}
  return PlanTier.values.map(SubscriptionPlanInfo.fromTier).toList();
});

/// Résultat d'une opération de souscription ou de changement de plan.
enum PlanChangeResult {
  /// Le plan a été activé et confirmé par le backend (via webhook / synchro Stripe).
  activated,

  /// L'annulation en fin de période (retour vers Core) a été programmée.
  scheduledCancellation,

  /// La résiliation programmée a été annulée (l'abonnement se poursuit).
  resumed,

  /// L'utilisateur a fermé la feuille de paiement Stripe sans payer.
  paymentCanceled,

  /// Le paiement a été soumis mais la confirmation webhook prend plus de temps.
  confirmationPending,
}

/// Gestionnaire central de l'abonnement de l'utilisateur connecté.
///
/// Ne modifie jamais l'état local sans confirmation du backend Strapi.
class SubscriptionNotifier extends Notifier<UserSubscription> {
  @override
  UserSubscription build() {
    ref.listen<int>(sessionExpiredProvider, (previous, next) {
      if (next > (previous ?? 0)) {
        state = const UserSubscription.core();
      }
    });

    // Si un appel API renvoie 403 PLAN_UPGRADE_REQUIRED, on rafraîchit immédiatement
    // l'abonnement depuis le serveur pour synchroniser les droits d'accès.
    ref.listen<int>(planRequiredSignalProvider, (previous, next) {
      if (next > (previous ?? 0)) {
        unawaited(fetchFromBackend());
      }
    });

    return const UserSubscription.core();
  }

  void reset() => state = const UserSubscription.core();

  /// Charge l'abonnement actuel depuis `GET /api/subscription/me`.
  Future<UserSubscription> fetchFromBackend() async {
    final user = ref.read(sessionProvider);
    final token = ref.read(tokenStorageProvider).token;
    if (user == null && (token == null || token.isEmpty)) {
      state = const UserSubscription.core();
      return state;
    }

    try {
      final client = ref.read(strapiClientProvider);
      final map = await client.getMap('/subscription/me');
      final loaded = UserSubscription.fromJson(map);
      state = loaded;
      return loaded;
    } catch (_) {
      return state;
    }
  }

  /// Demande au serveur de relire l'abonnement directement auprès de Stripe (`POST /subscription/sync`).
  Future<UserSubscription> syncWithStripe({String? subscriptionId}) async {
    final client = ref.read(strapiClientProvider);
    final response = await client.post(
      '/subscription/sync',
      body: {
        if (subscriptionId != null && subscriptionId.isNotEmpty)
          'subscriptionId': subscriptionId,
      },
    );
    final updated = UserSubscription.fromJson(StrapiClient.unwrapMap(response));
    state = updated;
    ref.invalidate(subscriptionHistoryProvider);
    return updated;
  }

  /// Attend la confirmation backend (webhook Stripe ou lecture serveur) après un paiement.
  Future<bool> waitForBackendConfirmation(
    PlanTier expectedPlan, {
    String? subscriptionId,
    int maxAttempts = 6,
    Duration delay = const Duration(seconds: 1),
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final synced = attempt == 0
            ? await syncWithStripe(subscriptionId: subscriptionId)
            : await fetchFromBackend();
        if (synced.plan == expectedPlan && synced.status.isEntitled) {
          ref.invalidate(subscriptionHistoryProvider);
          return true;
        }
      } catch (_) {}
      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(delay);
      }
    }
    try {
      final synced = await syncWithStripe(subscriptionId: subscriptionId);
      return synced.plan == expectedPlan && synced.status.isEntitled;
    } catch (_) {
      return false;
    }
  }

  /// Souscrit ou change vers [targetPlan] :
  /// - Toute souscription ou tout changement vers un plan payant (`Plus` ou `Ultimate`)
  ///   crée une nouvelle session de paiement Stripe et ouvre la PaymentSheet native
  ///   dans l'application (sans réutiliser les anciennes informations de paiement).
  /// - Le passage vers `Core` (gratuit) programme l'annulation en fin de période.
  Future<PlanChangeResult> selectPlan(
    PlanTier targetPlan, {
    ThemeMode themeMode = ThemeMode.system,
  }) async {
    final current = state;

    // Cas 1 : l'utilisateur choisit le plan qu'il possède déjà
    if (current.isPaidActive && current.plan == targetPlan) {
      if (current.cancelAtPeriodEnd) {
        await resumeSubscription();
        return PlanChangeResult.resumed;
      }
      return PlanChangeResult.activated;
    }

    // Cas 2 : plan gratuit Core
    if (!targetPlan.isPaid) {
      if (!current.isPaidActive) {
        await fetchFromBackend();
        return PlanChangeResult.activated;
      }
      await cancelSubscription();
      return PlanChangeResult.scheduledCancellation;
    }

    // Cas 3 : souscription ou changement vers un plan payant (Plus ou Ultimate)
    // -> Crée systématiquement une nouvelle session PaymentSheet Stripe et l'ouvre dans Flutter.
    return _openNewPaymentSheetForPlan(targetPlan, themeMode: themeMode);
  }

  Future<PlanChangeResult> _openNewPaymentSheetForPlan(
    PlanTier targetPlan, {
    required ThemeMode themeMode,
  }) async {
    final client = ref.read(strapiClientProvider);
    final response = await client.post(
      '/subscription/payment-sheet',
      body: {'plan': targetPlan.id},
    );
    final sheetData = StrapiClient.unwrapMap(response);
    final clientSecret = (sheetData['clientSecret'] ?? '').toString();
    final subscriptionId = sheetData['subscriptionId']?.toString();
    final publishableKey = sheetData['publishableKey']?.toString();

    if (clientSecret.isEmpty) {
      throw const ApiException(
        kind: ApiErrorKind.server,
        message: 'Le serveur n\'a pas pu initialiser le paiement Stripe.',
      );
    }

    final outcome = await ref.read(stripePaymentServiceProvider).payWithPaymentSheet(
      clientSecret: clientSecret,
      publishableKey: publishableKey,
      themeMode: themeMode,
    );

    if (outcome == PaymentSheetOutcome.canceled) {
      await fetchFromBackend();
      return PlanChangeResult.paymentCanceled;
    }

    final confirmed = await waitForBackendConfirmation(
      targetPlan,
      subscriptionId: subscriptionId,
    );
    return confirmed ? PlanChangeResult.activated : PlanChangeResult.confirmationPending;
  }

  /// Programme l'annulation à la fin de la période en cours (`POST /subscription/cancel`).
  Future<UserSubscription> cancelSubscription() async {
    final client = ref.read(strapiClientProvider);
    final response = await client.post('/subscription/cancel', body: const {});
    final updated = UserSubscription.fromJson(StrapiClient.unwrapMap(response));
    state = updated;
    ref.invalidate(subscriptionHistoryProvider);
    return updated;
  }

  /// Annule la résiliation programmée (`POST /subscription/resume`).
  Future<UserSubscription> resumeSubscription() async {
    final client = ref.read(strapiClientProvider);
    final response = await client.post('/subscription/resume', body: const {});
    final updated = UserSubscription.fromJson(StrapiClient.unwrapMap(response));
    state = updated;
    ref.invalidate(subscriptionHistoryProvider);
    return updated;
  }
}

final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, UserSubscription>(SubscriptionNotifier.new);

/// Indique si l'utilisateur connecté a accès à [feature] selon son abonnement actif.
/// Point d'entrée unique pour le contrôle d'accès côté Flutter.
final hasFeatureProvider = Provider.family<bool, AppFeature>((ref, feature) {
  final sub = ref.watch(subscriptionProvider);
  return sub.hasFeature(feature);
});

/// Historique des événements d'abonnement de l'utilisateur (`GET /api/subscription/history`).
final subscriptionHistoryProvider =
    FutureProvider<List<SubscriptionEventRecord>>((ref) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) return const [];
      final client = ref.watch(strapiClientProvider);
      final list = await client.getList('/subscription/history');
      return list.map(SubscriptionEventRecord.fromJson).toList();
    });
