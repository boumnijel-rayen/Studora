import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../providers/roommates_providers.dart';
import '../roommates_routes.dart';

class RoommatesHomeScreen extends ConsumerWidget {
  const RoommatesHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roommatesAsync = ref.watch(roommatesAsyncProvider);
    final choresAsync = ref.watch(choresAsyncProvider);
    final expensesAsync = ref.watch(expensesAsyncProvider);

    final roommates = roommatesAsync.value ?? const [];
    final chores = choresAsync.value ?? const [];
    final sharedExpenses = ref.watch(sharedExpensesProvider);
    final pendingChores = chores.where((c) => !c.isCompleted).toList();
    final balances = ref.watch(balancesDueProvider);
    final netBalance = ref.watch(netUserBalanceProvider);
    final currency = ref.watch(preferencesProvider).currency;

    final hasError = roommatesAsync.hasError || choresAsync.hasError || expensesAsync.hasError;
    final errorObj = roommatesAsync.error ?? choresAsync.error ?? expensesAsync.error;
    final isLoading =
        (roommatesAsync.isLoading || choresAsync.isLoading || expensesAsync.isLoading) &&
        roommates.isEmpty &&
        chores.isEmpty &&
        sharedExpenses.isEmpty;

    return AppScaffold(
      title: 'Colocation',
      subtitle: 'Vie partagée & Dépenses',
      actions: [
        IconButton(
          tooltip: 'Équilibre des comptes',
          icon: const Icon(Icons.account_balance_wallet_outlined),
          onPressed: () => context.push(RoommatesRoutes.balances),
        ),
      ],
      body: isLoading
          ? const AppLoader(message: 'Chargement de votre espace colocation...')
          : hasError && roommates.isEmpty && chores.isEmpty && sharedExpenses.isEmpty
          ? AppErrorState.fromError(
              errorObj!,
              onRetry: () {
                ref.read(roommatesAsyncProvider.notifier).refresh();
                ref.read(choresAsyncProvider.notifier).refresh();
                ref.read(expensesAsyncProvider.notifier).refresh();
              },
            )
          : RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  ref.read(roommatesAsyncProvider.notifier).refresh(),
                  ref.read(choresAsyncProvider.notifier).refresh(),
                  ref.read(expensesAsyncProvider.notifier).refresh(),
                ]);
              },
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // Carte solde global
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        const AppIconBox(
                          icon: Icons.payments_rounded,
                          color: AppColors.moduleRoommates,
                          size: 50,
                        ),
                        AppSpacing.gapMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                netBalance >= 0
                                    ? 'Solde net à recevoir'
                                    : 'Solde net à rembourser',
                                style: context.text.titleSmall,
                              ),
                              AppSpacing.gapXxs,
                              Text(
                                '${netBalance >= 0 ? '+' : ''}${Formatters.money(netBalance, symbol: currency)}',
                                style: context.text.headlineSmall?.copyWith(
                                  color: netBalance >= 0
                                      ? context.colors.success
                                      : context.colors.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                balances.isEmpty
                                    ? 'Tous les comptes sont équilibrés'
                                    : '${balances.length} remboursement${balances.length > 1 ? 's' : ''} en attente',
                                style: context.text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        AppButton(
                          label: 'Régler',
                          variant: AppButtonVariant.tonal,
                          size: AppButtonSize.sm,
                          onPressed: () => context.push(RoommatesRoutes.balances),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapLg,

                  // Raccourcis navigation
                  Row(
                    children: [
                      Expanded(
                        child: AppStatCard(
                          label: 'Tâches en attente',
                          value: '${pendingChores.length}',
                          icon: Icons.cleaning_services_rounded,
                          color: AppColors.moduleRoommates,
                          caption: 'Voir le planning',
                          onTap: () => context.push(RoommatesRoutes.chores),
                        ),
                      ),
                      AppSpacing.gapSm,
                      Expanded(
                        child: AppStatCard(
                          label: 'Dépenses du mois',
                          value:
                              '${sharedExpenses.fold<double>(0, (a, e) => a + e.amount).toStringAsFixed(0)} $currency',
                          icon: Icons.receipt_long_rounded,
                          color: AppColors.tertiary,
                          caption: 'Voir les dépenses',
                          onTap: () => context.push(RoommatesRoutes.expenses),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapLg,

                  // Les colocataires
                  AppSectionHeader(
                    title: 'Colocataires (${roommates.length})',
                    actionLabel: 'Gérer',
                    onAction: () => context.push(RoommatesRoutes.roommatesList),
                  ),
                  if (roommates.isEmpty)
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          const Icon(Icons.group_add_outlined, color: AppColors.moduleRoommates),
                          AppSpacing.gapSm,
                          Expanded(
                            child: Text(
                              'Aucun colocataire enregistré.',
                              style: context.text.bodySmall,
                            ),
                          ),
                          AppButton(
                            label: 'Ajouter',
                            size: AppButtonSize.sm,
                            variant: AppButtonVariant.tonal,
                            onPressed: () => context.push(RoommatesRoutes.newRoommate),
                          ),
                        ],
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final r in roommates) ...[
                            AppCard(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              onTap: () async {
                                try {
                                  await ref
                                      .read(roommatesAsyncProvider.notifier)
                                      .togglePresence(r.id);
                                } catch (e) {
                                  if (context.mounted) {
                                    AppSnackbar.error(
                                      context,
                                      e is ApiException
                                          ? e.message
                                          : 'Impossible de modifier la présence.',
                                    );
                                  }
                                }
                              },
                              child: Column(
                                children: [
                                  AppAvatar(name: r.name, size: 48, showOnline: r.isPresent),
                                  AppSpacing.gapSm,
                                  Text(r.name.split(' ').first, style: context.text.labelLarge),
                                  Text(r.roomNumber, style: context.text.bodySmall),
                                  AppSpacing.gapXxs,
                                  AppBadge(
                                    label: r.isPresent ? 'Présent' : 'Absent',
                                    tone: r.isPresent
                                        ? AppBadgeTone.success
                                        : AppBadgeTone.neutral,
                                  ),
                                ],
                              ),
                            ),
                            AppSpacing.gapSm,
                          ],
                        ],
                      ),
                    ),
                  AppSpacing.gapLg,

                  // Tâches ménagères du jour
                  AppSectionHeader(
                    title: 'Tâches à faire',
                    actionLabel: 'Voir tout',
                    onAction: () => context.push(RoommatesRoutes.chores),
                  ),
                  if (pendingChores.isEmpty)
                    const AppCard(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Text('Aucune tâche ménagère en attente.'),
                    )
                  else
                    for (final c in pendingChores.take(3)) ...[
                      AppCard(
                        child: Row(
                          children: [
                            Checkbox(
                              value: c.isCompleted,
                              onChanged: (_) async {
                                try {
                                  await ref.read(choresAsyncProvider.notifier).toggle(c.id);
                                  if (context.mounted) {
                                    AppSnackbar.success(context, 'Tâche ménagère validée !');
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    AppSnackbar.error(
                                      context,
                                      e is ApiException
                                          ? e.message
                                          : 'Impossible de mettre à jour la tâche.',
                                    );
                                  }
                                }
                              },
                            ),
                            AppSpacing.gapSm,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.title, style: context.text.titleSmall),
                                  Text(
                                    'Assigné à : ${c.assignedToName}',
                                    style: context.text.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            AppBadge(label: c.frequency, tone: AppBadgeTone.warning),
                          ],
                        ),
                      ),
                      AppSpacing.gapSm,
                    ],
                ],
              ),
            ),
    );
  }
}
