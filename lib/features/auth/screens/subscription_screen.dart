import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';

/// Écran de consultation et de gestion de l'abonnement Studora (Core, Plus, Ultimate).
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  PlanTier? _busyPlan;
  bool _isSyncing = false;

  Future<void> _handlePlanAction(PlanTier targetTier) async {
    if (_busyPlan != null) return;
    final sub = ref.read(subscriptionProvider);

    // Demande de confirmation uniquement lors d'un retour vers le plan gratuit Core
    // (les changements vers Plus ou Ultimate ouvrent directement une nouvelle PaymentSheet Stripe).
    if (sub.isPaidActive && targetTier == PlanTier.core) {
      final confirmed = await AppConfirmDialog.show(
        context,
        title: 'Rétrograder vers le plan gratuit Core ?',
        message:
            'Vous conserverez l\'accès à votre plan ${sub.plan.name} jusqu\'à la fin de la période en cours. '
            'Vos groupes et colocations seront conservés mais verrouillés ensuite.',
        confirmLabel: 'Confirmer',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _busyPlan = targetTier);
    try {
      final prefs = ref.read(preferencesProvider);
      final result = await ref
          .read(subscriptionProvider.notifier)
          .selectPlan(targetTier, themeMode: prefs.themeMode);

      if (!mounted) return;
      final isProratedUpgrade = sub.isPaidActive && targetTier.rank > sub.plan.rank;
      final proratedDiff = targetTier.priceMonthly - sub.plan.priceMonthly;
      switch (result) {
        case PlanChangeResult.activated:
          AppSnackbar.success(
            context,
            isProratedUpgrade
                ? 'Passage au plan ${targetTier.name} confirmé (facturé $proratedDiff \$ au prorata) !'
                : 'Votre abonnement ${targetTier.name} est maintenant actif !',
          );
        case PlanChangeResult.scheduledCancellation:
          AppSnackbar.info(
            context,
            'Le retour au plan Core est programmé pour la fin de la période en cours.',
          );
        case PlanChangeResult.resumed:
          AppSnackbar.success(
            context,
            'La résiliation a été annulée : votre abonnement ${sub.plan.name} se poursuit.',
          );
        case PlanChangeResult.paymentCanceled:
          AppSnackbar.info(context, 'Paiement annulé. Votre plan reste inchangé.');
        case PlanChangeResult.confirmationPending:
          AppSnackbar.info(
            context,
            'Paiement reçu, confirmation Stripe en cours… Actualisez dans quelques secondes.',
          );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, e.message);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, ApiException.fromError(e).message);
    } finally {
      if (mounted) {
        setState(() => _busyPlan = null);
      }
    }
  }

  Future<void> _handleSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      await ref.read(subscriptionProvider.notifier).syncWithStripe();
      if (!mounted) return;
      AppSnackbar.success(context, 'Statut de l\'abonnement synchronisé avec Stripe.');
    } on ApiException catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, e.message);
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  (String? label, AppButtonVariant variant) _actionForPlan(
    UserSubscription current,
    PlanTier candidate,
  ) {
    if (current.plan == candidate) {
      if (current.cancelAtPeriodEnd && candidate.isPaid) {
        return ('Reprendre le plan ${candidate.name}', AppButtonVariant.primary);
      }
      return (null, AppButtonVariant.secondary);
    }

    if (candidate.rank > current.plan.rank) {
      if (current.isPaidActive) {
        final diff = candidate.priceMonthly - current.plan.priceMonthly;
        return (
          'Passer au plan ${candidate.name} ($diff \$ au prorata)',
          AppButtonVariant.primary,
        );
      }
      return (
        'Passer au plan ${candidate.name} (${candidate.shortPriceLabel})',
        AppButtonVariant.primary,
      );
    }

    if (candidate == PlanTier.core && current.cancelAtPeriodEnd) {
      return (null, AppButtonVariant.secondary);
    }

    return (
      'Rétrograder vers ${candidate.name}',
      AppButtonVariant.secondary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(subscriptionProvider);
    final catalogAsync = ref.watch(subscriptionCatalogProvider);
    final historyAsync = ref.watch(subscriptionHistoryProvider);
    final plans =
        catalogAsync.asData?.value ??
        PlanTier.values.map(SubscriptionPlanInfo.fromTier).toList();

    return AppScaffold(
      title: 'Mon Abonnement',
      subtitle: 'Formules Core, Plus et Ultimate',
      actions: [
        IconButton(
          tooltip: 'Synchroniser avec Stripe',
          icon: _isSyncing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync_rounded),
          onPressed: _isSyncing ? null : _handleSync,
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _CurrentSubscriptionSummaryCard(
            subscription: sub,
            isBusy: _busyPlan != null,
            onResume: () => _handlePlanAction(sub.plan),
          ),
          AppSpacing.gapLg,

          const AppSectionHeader(title: 'Comparer les formules'),
          for (final planInfo in plans) ...[
            Builder(
              builder: (context) {
                final (actionLabel, variant) = _actionForPlan(sub, planInfo.tier);
                return SubscriptionPlanCard(
                  planInfo: planInfo,
                  isCurrentPlan: sub.plan == planInfo.tier,
                  actionLabel: actionLabel,
                  actionVariant: variant,
                  isActionLoading: _busyPlan == planInfo.tier,
                  onActionPressed: actionLabel == null || _busyPlan != null
                      ? null
                      : () => _handlePlanAction(planInfo.tier),
                );
              },
            ),
            AppSpacing.gapMd,
          ],

          AppSpacing.gapSm,
          const AppSectionHeader(title: 'Tableau comparatif des modules'),
          const _FeatureComparisonTable(),

          if (historyAsync.asData?.value.isNotEmpty == true) ...[
            AppSpacing.gapLg,
            const AppSectionHeader(title: 'Historique récent'),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                children: [
                  for (final (idx, evt) in historyAsync.asData!.value.take(5).indexed) ...[
                    if (idx > 0) const Divider(height: 1),
                    AppListTile(
                      title: evt.readableLabel,
                      subtitle: evt.occurredAt != null
                          ? '${Formatters.fullDate(evt.occurredAt!.toLocal())} • ${Formatters.time(evt.occurredAt!.toLocal())}'
                          : null,
                      leading: Icon(
                        evt.type.contains('failed')
                            ? Icons.warning_amber_rounded
                            : Icons.receipt_long_rounded,
                        color: evt.type.contains('failed')
                            ? AppColors.error
                            : context.colors.primary,
                      ),
                      trailing: evt.amount != null && evt.amount! > 0
                          ? Text(
                              '${(evt.amount! / 100).toStringAsFixed(2)} ${(evt.currency ?? 'USD').toUpperCase()}',
                              style: context.text.labelMedium,
                            )
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ],
          AppSpacing.gapXl,
        ],
      ),
    );
  }
}

class _CurrentSubscriptionSummaryCard extends StatelessWidget {
  const _CurrentSubscriptionSummaryCard({
    required this.subscription,
    required this.isBusy,
    required this.onResume,
  });

  final UserSubscription subscription;
  final bool isBusy;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final tier = subscription.plan;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
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
                    Text('Formule actuelle', style: context.text.labelMedium),
                    Text(
                      'Studora ${tier.name} (${tier.shortPriceLabel})',
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              SubscriptionStatusBadge(
                status: subscription.status,
                cancelAtPeriodEnd: subscription.cancelAtPeriodEnd,
              ),
            ],
          ),
          if (subscription.renewsAt != null) ...[
            AppSpacing.gapSm,
            Row(
              children: [
                Icon(
                  Icons.event_repeat_rounded,
                  size: 18,
                  color: context.colors.textSecondary,
                ),
                AppSpacing.gapXs,
                Expanded(
                  child: Text(
                    'Prochain renouvellement automatique le ${Formatters.fullDate(subscription.renewsAt!.toLocal())}',
                    style: context.text.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          if (subscription.accessEndsAt != null) ...[
            AppSpacing.gapSm,
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.warning,
                ),
                AppSpacing.gapXs,
                Expanded(
                  child: Text(
                    'Accès ${tier.name} maintenu jusqu\'au ${Formatters.fullDate(subscription.accessEndsAt!.toLocal())}, puis retour au plan Core.',
                    style: context.text.bodySmall,
                  ),
                ),
              ],
            ),
            AppSpacing.gapSm,
            AppButton(
              label: 'Conserver mon abonnement ${tier.name}',
              variant: AppButtonVariant.tonal,
              expand: true,
              onPressed: isBusy ? null : onResume,
            ),
          ],
          if (subscription.lastPaymentError != null &&
              subscription.lastPaymentError!.isNotEmpty) ...[
            AppSpacing.gapSm,
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: AppRadius.brMd,
                border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                  AppSpacing.gapXs,
                  Expanded(
                    child: Text(
                      subscription.lastPaymentError!,
                      style: context.text.bodySmall?.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureComparisonTable extends StatelessWidget {
  const _FeatureComparisonTable();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Planning, cours & échéances', true, true, true),
      ('Sessions d\'étude & Pomodoro', true, true, true),
      ('Notes, moyennes & objectifs', true, true, true),
      ('Groupes d\'étude (Study Groups)', false, true, true),
      ('Colocation (Roommates)', false, false, true),
    ];

    Widget cellIcon(bool included) => Icon(
      included ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
      size: 18,
      color: included ? AppColors.success : context.colors.textSecondary,
    );

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Text('Fonctionnalité', style: context.text.labelMedium),
              ),
              for (final label in const ['Core', 'Plus', 'Ultimate'])
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      label,
                      style: context.text.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          AppSpacing.gapXs,
          const Divider(),
          for (final (title, inCore, inPlus, inUltimate) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(title, style: context.text.bodySmall),
                  ),
                  Expanded(flex: 2, child: Center(child: cellIcon(inCore))),
                  Expanded(flex: 2, child: Center(child: cellIcon(inPlus))),
                  Expanded(flex: 2, child: Center(child: cellIcon(inUltimate))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
