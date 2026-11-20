import 'package:flutter/material.dart';

import '../design_system/tokens/app_colors.dart';

/// Fonctionnalités soumises à un contrôle d'accès par abonnement.
enum AppFeature {
  studyGroups(
    key: 'studyGroups',
    label: 'Groupes d\'étude',
    description:
        'Créez ou rejoignez des groupes de travail, échangez dans la messagerie de groupe et suivez les activités communes.',
    icon: Icons.groups_rounded,
    color: AppColors.moduleGroups,
  ),
  roommates(
    key: 'roommates',
    label: 'Colocation',
    description:
        'Organisez la vie en colocation : répartition des tâches ménagères, dépenses partagées, soldes et discussion.',
    icon: Icons.home_rounded,
    color: AppColors.moduleRoommates,
  );

  const AppFeature({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String key;
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  PlanTier get minimumPlan => switch (this) {
    AppFeature.studyGroups => PlanTier.plus,
    AppFeature.roommates => PlanTier.ultimate,
  };

  static AppFeature? fromKey(String? raw) {
    if (raw == null) return null;
    for (final f in AppFeature.values) {
      if (f.key == raw) return f;
    }
    return null;
  }
}

/// Les trois formules d'abonnement proposées par Studora.
enum PlanTier {
  core(
    id: 'core',
    name: 'Core',
    rank: 0,
    priceMonthly: 0,
    subtitle: 'Idéal pour organiser vos études au quotidien',
    accentColor: AppColors.moduleSchedule,
    icon: Icons.school_outlined,
  ),
  plus(
    id: 'plus',
    name: 'Plus',
    rank: 1,
    priceMonthly: 9,
    subtitle: 'Pour travailler et réviser à plusieurs',
    accentColor: AppColors.moduleGroups,
    icon: Icons.groups_rounded,
  ),
  ultimate(
    id: 'ultimate',
    name: 'Ultimate',
    rank: 2,
    priceMonthly: 14,
    subtitle: 'L\'expérience étudiante complète (études + colocation)',
    accentColor: AppColors.moduleRoommates,
    icon: Icons.workspace_premium_rounded,
  );

  const PlanTier({
    required this.id,
    required this.name,
    required this.rank,
    required this.priceMonthly,
    required this.subtitle,
    required this.accentColor,
    required this.icon,
  });

  final String id;
  final String name;
  final int rank;
  final int priceMonthly;
  final String subtitle;
  final Color accentColor;
  final IconData icon;

  bool get isPaid => priceMonthly > 0;

  String get shortPriceLabel => priceMonthly == 0 ? 'Gratuit' : '$priceMonthly \$ / mois';

  List<AppFeature> get defaultFeatures => switch (this) {
    PlanTier.core => const [],
    PlanTier.plus => const [AppFeature.studyGroups],
    PlanTier.ultimate => const [AppFeature.studyGroups, AppFeature.roommates],
  };

  List<String> get defaultHighlights => switch (this) {
    PlanTier.core => const [
      'Emploi du temps, échéances et notifications',
      'Sessions d\'étude, tâches et Pomodoro',
      'Suivi des notes et objectifs académiques',
    ],
    PlanTier.plus => const [
      'Toutes les fonctionnalités du plan Core',
      'Accès au module Groupes d\'étude (Study Groups)',
      'Discussions et activités de groupe illimitées',
    ],
    PlanTier.ultimate => const [
      'Toutes les fonctionnalités du plan Plus',
      'Accès au module Groupes d\'étude (Study Groups)',
      'Accès au module Colocation (Roommates)',
    ],
  };

  static PlanTier fromId(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final tier in PlanTier.values) {
      if (tier.id == normalized) return tier;
    }
    return PlanTier.core;
  }
}

/// Statut du cycle de vie de l'abonnement synchronisé avec Stripe.
enum SubscriptionStatus {
  active('active', 'Actif'),
  trialing('trialing', 'Période d\'essai'),
  pastDue('past_due', 'Paiement en retard'),
  incomplete('incomplete', 'Paiement en attente'),
  unpaid('unpaid', 'Impayé'),
  paused('paused', 'En pause'),
  canceled('canceled', 'Annulé'),
  expired('expired', 'Expiré');

  const SubscriptionStatus(this.key, this.label);

  final String key;
  final String label;

  bool get isEntitled =>
      this == SubscriptionStatus.active ||
      this == SubscriptionStatus.trialing ||
      this == SubscriptionStatus.pastDue;

  static SubscriptionStatus fromKey(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final s in SubscriptionStatus.values) {
      if (s.key == normalized) return s;
    }
    return SubscriptionStatus.active;
  }
}

/// Entrée du catalogue renvoyée par `GET /api/subscription/plans`.
@immutable
class SubscriptionPlanInfo {
  const SubscriptionPlanInfo({
    required this.tier,
    required this.priceMonthly,
    required this.currency,
    required this.features,
    required this.highlights,
    required this.purchasable,
  });

  factory SubscriptionPlanInfo.fromTier(PlanTier tier) => SubscriptionPlanInfo(
    tier: tier,
    priceMonthly: tier.priceMonthly,
    currency: 'usd',
    features: tier.defaultFeatures,
    highlights: tier.defaultHighlights,
    purchasable: true,
  );

  factory SubscriptionPlanInfo.fromJson(Map<String, dynamic> json) {
    final tier = PlanTier.fromId(json['id']?.toString());
    final rawFeatures = json['features'];
    final features = rawFeatures is List
        ? rawFeatures
              .map((e) => AppFeature.fromKey(e?.toString()))
              .whereType<AppFeature>()
              .toList()
        : tier.defaultFeatures;
    final rawHighlights = json['highlights'];
    final highlights = rawHighlights is List && rawHighlights.isNotEmpty
        ? rawHighlights.map((e) => e.toString()).toList()
        : tier.defaultHighlights;

    return SubscriptionPlanInfo(
      tier: tier,
      priceMonthly: (json['priceMonthly'] is num)
          ? (json['priceMonthly'] as num).toInt()
          : tier.priceMonthly,
      currency: (json['currency'] ?? 'usd').toString().toUpperCase(),
      features: features,
      highlights: highlights,
      purchasable: json['purchasable'] != false,
    );
  }

  final PlanTier tier;
  final int priceMonthly;
  final String currency;
  final List<AppFeature> features;
  final List<String> highlights;
  final bool purchasable;

  bool includesFeature(AppFeature feature) => features.contains(feature);
}

/// Abonnement actuel de l'utilisateur connecté (`GET /api/subscription/me`).
@immutable
class UserSubscription {
  const UserSubscription({
    this.plan = PlanTier.core,
    this.subscribedPlan = PlanTier.core,
    this.status = SubscriptionStatus.active,
    this.features = const [],
    this.cancelAtPeriodEnd = false,
    this.pendingPlan,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.renewsAt,
    this.accessEndsAt,
    this.canceledAt,
    this.endedAt,
    this.lastPaymentError,
    this.paymentPending = false,
  });

  const UserSubscription.core() : this();

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    final plan = PlanTier.fromId(json['plan']?.toString());
    final subscribedPlan = PlanTier.fromId(
      (json['subscribedPlan'] ?? json['plan'])?.toString(),
    );
    final status = SubscriptionStatus.fromKey(json['status']?.toString());
    final rawFeatures = json['features'];
    final features = rawFeatures is List
        ? rawFeatures
              .map((e) => AppFeature.fromKey(e?.toString()))
              .whereType<AppFeature>()
              .toList()
        : (status.isEntitled ? plan.defaultFeatures : const <AppFeature>[]);

    DateTime? parseDate(dynamic v) =>
        v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

    return UserSubscription(
      plan: plan,
      subscribedPlan: subscribedPlan,
      status: status,
      features: features,
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] == true,
      pendingPlan: json['pendingPlan'] != null
          ? PlanTier.fromId(json['pendingPlan'].toString())
          : null,
      currentPeriodStart: parseDate(json['currentPeriodStart']),
      currentPeriodEnd: parseDate(json['currentPeriodEnd']),
      renewsAt: parseDate(json['renewsAt']),
      accessEndsAt: parseDate(json['accessEndsAt']),
      canceledAt: parseDate(json['canceledAt']),
      endedAt: parseDate(json['endedAt']),
      lastPaymentError: json['lastPaymentError']?.toString(),
      paymentPending: json['paymentPending'] == true,
    );
  }

  /// Plan effectif donnant accès aux fonctionnalités.
  final PlanTier plan;

  /// Plan enregistré sur l'abonnement (peut différer de [plan] si `incomplete`).
  final PlanTier subscribedPlan;

  final SubscriptionStatus status;
  final List<AppFeature> features;
  final bool cancelAtPeriodEnd;
  final PlanTier? pendingPlan;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? renewsAt;
  final DateTime? accessEndsAt;
  final DateTime? canceledAt;
  final DateTime? endedAt;
  final String? lastPaymentError;
  final bool paymentPending;

  bool hasFeature(AppFeature feature) => features.contains(feature);

  bool get isPaidActive => plan.isPaid && status.isEntitled;
}

/// Événement d'historique d'abonnement (`GET /api/subscription/history`).
@immutable
class SubscriptionEventRecord {
  const SubscriptionEventRecord({
    required this.type,
    this.plan,
    this.previousPlan,
    this.status,
    this.amount,
    this.currency,
    this.occurredAt,
  });

  factory SubscriptionEventRecord.fromJson(Map<String, dynamic> json) =>
      SubscriptionEventRecord(
        type: (json['type'] ?? '').toString(),
        plan: json['plan'] != null ? PlanTier.fromId(json['plan'].toString()) : null,
        previousPlan: json['previousPlan'] != null
            ? PlanTier.fromId(json['previousPlan'].toString())
            : null,
        status: json['status']?.toString(),
        amount: (json['amount'] is num) ? (json['amount'] as num).toInt() : null,
        currency: json['currency']?.toString(),
        occurredAt: json['occurredAt'] is String
            ? DateTime.tryParse(json['occurredAt'] as String)
            : null,
      );

  final String type;
  final PlanTier? plan;
  final PlanTier? previousPlan;
  final String? status;
  final int? amount;
  final String? currency;
  final DateTime? occurredAt;

  String get readableLabel => switch (type) {
    'plan.changed' =>
      previousPlan != null && plan != null
          ? 'Passage du plan ${previousPlan!.name} au plan ${plan!.name}'
          : 'Changement de formule',
    'invoice.paid' => 'Paiement mensuel confirmé',
    'invoice.payment_failed' => 'Échec du paiement mensuel',
    'customer.subscription.created' => 'Création de l\'abonnement',
    'customer.subscription.updated' => 'Mise à jour de l\'abonnement',
    'customer.subscription.deleted' => 'Fin de l\'abonnement',
    _ => type,
  };
}
