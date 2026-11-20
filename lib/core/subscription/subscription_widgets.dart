import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/design_system.dart';
import '../module/feature_module.dart';
import 'subscription_models.dart';

/// Chemin central de l'écran de gestion de l'abonnement.
const String kSubscriptionRoute = '/profile/subscription';

/// Chemin de l'écran de verrouillage d'une fonctionnalité payante.
String lockedFeatureRoute(AppFeature feature) =>
    '/subscription/locked?feature=${feature.key}';

/// Badge visuel indiquant le statut d'un abonnement (Actif, Annulé, Expiré, etc.).
class SubscriptionStatusBadge extends StatelessWidget {
  const SubscriptionStatusBadge({
    super.key,
    required this.status,
    this.cancelAtPeriodEnd = false,
  });

  final SubscriptionStatus status;
  final bool cancelAtPeriodEnd;

  @override
  Widget build(BuildContext context) {
    final (String text, Color color) = switch ((status, cancelAtPeriodEnd)) {
      (SubscriptionStatus.active, true) => ('Annulation programmée', AppColors.warning),
      (SubscriptionStatus.active, false) => ('Actif', AppColors.success),
      (SubscriptionStatus.trialing, _) => ('Essai actif', AppColors.info),
      (SubscriptionStatus.pastDue, _) => ('Paiement en retard', AppColors.warning),
      (SubscriptionStatus.incomplete, _) => ('Paiement en attente', AppColors.warning),
      (SubscriptionStatus.unpaid, _) => ('Impayé', AppColors.error),
      (SubscriptionStatus.paused, _) => ('En pause', AppColors.warning),
      (SubscriptionStatus.canceled, _) => ('Annulé', AppColors.error),
      (SubscriptionStatus.expired, _) => ('Expiré', AppColors.lightTextSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadius.brFull,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: context.text.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Carte de présentation d'une formule d'abonnement (Core, Plus, Ultimate).
///
/// Utilisée à la fois lors du choix de plan à l'inscription (mode sélection)
/// et sur l'écran de gestion d'abonnement (mode action).
class SubscriptionPlanCard extends StatelessWidget {
  const SubscriptionPlanCard({
    super.key,
    required this.planInfo,
    this.isCurrentPlan = false,
    this.isSelected = false,
    this.actionLabel,
    this.actionVariant = AppButtonVariant.primary,
    this.isActionLoading = false,
    this.onTap,
    this.onActionPressed,
  });

  final SubscriptionPlanInfo planInfo;
  final bool isCurrentPlan;
  final bool isSelected;
  final String? actionLabel;
  final AppButtonVariant actionVariant;
  final bool isActionLoading;
  final VoidCallback? onTap;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    final tier = planInfo.tier;
    final highlighted = isCurrentPlan || isSelected;
    final borderColor = highlighted ? tier.accentColor : context.colors.border;

    final excludedFeatures = AppFeature.values
        .where((f) => !planInfo.includesFeature(f))
        .toList();

    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.brLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brLg,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brLg,
            border: Border.all(
              color: borderColor,
              width: highlighted ? 2 : 1,
            ),
            color: highlighted
                ? tier.accentColor.withValues(alpha: 0.05)
                : context.colors.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppIconBox(icon: tier.icon, color: tier.accentColor),
                  AppSpacing.gapSm,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                tier.name,
                                style: context.text.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (isCurrentPlan) ...[
                              AppSpacing.gapXs,
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: tier.accentColor,
                                  borderRadius: AppRadius.brFull,
                                ),
                                child: Text(
                                  'PLAN ACTUEL',
                                  style: context.text.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ] else if (tier == PlanTier.ultimate) ...[
                              AppSpacing.gapXs,
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: tier.accentColor.withValues(alpha: 0.15),
                                  borderRadius: AppRadius.brFull,
                                ),
                                child: Text(
                                  'COMPLET',
                                  style: context.text.labelSmall?.copyWith(
                                    color: tier.accentColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tier.subtitle,
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapXs,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        planInfo.priceMonthly == 0
                            ? 'FREE'
                            : '${planInfo.priceMonthly} \$',
                        style: context.text.titleLarge?.copyWith(
                          color: tier.accentColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        planInfo.priceMonthly == 0 ? '0 USD/mois' : 'USD / mois',
                        style: context.text.labelSmall?.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (onTap != null && onActionPressed == null) ...[
                    AppSpacing.gapXs,
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isSelected ? tier.accentColor : context.colors.textSecondary,
                    ),
                  ],
                ],
              ),
              AppSpacing.gapMd,
              const Divider(height: 1),
              AppSpacing.gapSm,
              for (final item in planInfo.highlights) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: AppColors.success,
                      ),
                      AppSpacing.gapXs,
                      Expanded(
                        child: Text(item, style: context.text.bodySmall),
                      ),
                    ],
                  ),
                ),
              ],
              for (final excluded in excludedFeatures) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: context.colors.textSecondary,
                      ),
                      AppSpacing.gapXs,
                      Expanded(
                        child: Text(
                          'Sans accès au module ${excluded.label}',
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (actionLabel != null) ...[
                AppSpacing.gapMd,
                AppButton(
                  label: actionLabel!,
                  variant: actionVariant,
                  isLoading: isActionLoading,
                  expand: true,
                  onPressed: onActionPressed,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Écran affiché lorsqu'un utilisateur tente d'accéder à un module nécessitant
/// un plan d'abonnement supérieur.
class LockedFeatureScreen extends StatelessWidget {
  const LockedFeatureScreen({
    super.key,
    required this.feature,
    required this.currentPlan,
    this.inShell = false,
  });

  final AppFeature feature;
  final PlanTier currentPlan;
  final bool inShell;

  @override
  Widget build(BuildContext context) {
    final requiredPlan = feature.minimumPlan;

    return AppScaffold(
      title: feature.label,
      subtitle: 'Fonctionnalité réservée au plan ${requiredPlan.name}',
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      AppIconBox(
                        icon: feature.icon,
                        color: feature.color,
                        size: 64,
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          size: 18,
                          color: requiredPlan.accentColor,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapMd,
                  Text(
                    'Débloquez ${feature.label}',
                    style: context.text.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapXs,
                  Text(
                    feature.description,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapMd,
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: requiredPlan.accentColor.withValues(alpha: 0.1),
                      borderRadius: AppRadius.brMd,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.workspace_premium_rounded,
                          color: requiredPlan.accentColor,
                        ),
                        AppSpacing.gapSm,
                        Expanded(
                          child: Text(
                            'Votre plan actuel est ${currentPlan.name}. '
                            'Passez au plan ${requiredPlan.name} (${requiredPlan.shortPriceLabel}) '
                            '${requiredPlan == PlanTier.plus ? 'ou Ultimate ' : ''}'
                            'pour activer ce module.',
                            style: context.text.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapLg,
                  AppButton(
                    label: 'Passer au plan ${requiredPlan.name}',
                    icon: Icons.upgrade_rounded,
                    expand: true,
                    onPressed: () => context.push(kSubscriptionRoute),
                  ),
                  if (!inShell) ...[
                    AppSpacing.gapSm,
                    AppButton(
                      label: 'Retour à l\'accueil',
                      variant: AppButtonVariant.ghost,
                      expand: true,
                      onPressed: () => context.go('/home'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte affichée sur le Dashboard lorsqu'un module est verrouillé par le plan actuel.
class LockedModuleDashboardCard extends StatelessWidget {
  const LockedModuleDashboardCard({super.key, required this.module});

  final FeatureModule module;

  @override
  Widget build(BuildContext context) {
    final feature = module.requiredFeature!;
    final minPlan = feature.minimumPlan;
    return AppCard(
      onTap: () => context.push(kSubscriptionRoute),
      child: Row(
        children: [
          AppIconBox(icon: module.entry.selectedIcon, color: module.entry.color),
          AppSpacing.gapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(module.entry.label, style: context.text.titleSmall),
                    ),
                    AppSpacing.gapXs,
                    Icon(Icons.lock_rounded, size: 15, color: minPlan.accentColor),
                  ],
                ),
                Text(
                  'Disponible avec le plan ${minPlan.name} (${minPlan.shortPriceLabel})',
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.colors.textSecondary),
        ],
      ),
    );
  }
}
