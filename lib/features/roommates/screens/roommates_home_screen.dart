import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../providers/roommates_providers.dart';
import '../roommates_routes.dart';
import '../services/colocation_message_notifications.dart';
import 'colocation_info_card.dart';
import 'colocation_setup_screen.dart';

class RoommatesHomeScreen extends ConsumerWidget {
  const RoommatesHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colocationAsync = ref.watch(colocationAsyncProvider);

    return colocationAsync.when(
      skipLoadingOnRefresh: true,
      loading: () => const AppScaffold(
        title: 'Colocation',
        body: AppLoader(message: 'Chargement de votre espace colocation...'),
      ),
      error: (err, _) => AppScaffold(
        title: 'Colocation',
        body: AppErrorState.fromError(
          err,
          onRetry: () => ref.read(colocationAsyncProvider.notifier).refresh(),
        ),
      ),
      data: (colocation) => colocation == null
          ? const ColocationSetupScreen()
          : const _ColocationDashboard(),
    );
  }
}

class _ColocationDashboard extends ConsumerWidget {
  const _ColocationDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roommatesAsync = ref.watch(roommatesAsyncProvider);
    final choresAsync = ref.watch(choresAsyncProvider);
    final expensesAsync = ref.watch(expensesAsyncProvider);
    final colocation = ref.watch(colocationProvider);

    final roommates = ref.watch(roommatesProvider);
    final monthlyTotal = ref.watch(monthlyExpensesTotalProvider);
    final chores = choresAsync.value ?? const [];
    final sharedExpenses = ref.watch(sharedExpensesProvider);
    // Tâches de la période en cours ou en retard (les suivantes restent masquées).
    final pendingChores = ref.watch(visiblePendingChoresProvider);
    final balances = ref.watch(balancesDueProvider);
    final netBalance = ref.watch(netUserBalanceProvider);
    final currency = ref.watch(preferencesProvider).currency;
    final unreadMessages = ref.watch(colocationUnreadCountProvider);

    final hasError = roommatesAsync.hasError || choresAsync.hasError || expensesAsync.hasError;
    final errorObj = roommatesAsync.error ?? choresAsync.error ?? expensesAsync.error;
    final isLoading =
        (roommatesAsync.isLoading || choresAsync.isLoading || expensesAsync.isLoading) &&
        roommates.isEmpty &&
        chores.isEmpty &&
        sharedExpenses.isEmpty;

    return AppScaffold(
      title: colocation?.name ?? 'Colocation',
      subtitle: 'Vie partagée & Dépenses',
      actions: [
        IconButton(
          tooltip: unreadMessages > 0
              ? 'Discussion ($unreadMessages nouveau${unreadMessages > 1 ? 'x' : ''} message${unreadMessages > 1 ? 's' : ''})'
              : 'Discussion',
          icon: Badge(
            // Pastille rouge tant que des messages de colocataires n'ont pas été lus.
            isLabelVisible: unreadMessages > 0,
            smallSize: 9,
            backgroundColor: AppColors.error,
            child: const Icon(Icons.chat_bubble_outline_rounded),
          ),
          onPressed: () => context.push(RoommatesRoutes.chat),
        ),
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
                // Relit aussi la colocation : si l'utilisateur en a été retiré,
                // l'écran revient au choix « Rejoindre / Créer » au lieu de rester en erreur.
                ref.read(colocationAsyncProvider.notifier).refresh();
                ref.read(roommatesAsyncProvider.notifier).refresh();
                ref.read(choresAsyncProvider.notifier).refresh();
                ref.read(expensesAsyncProvider.notifier).refresh();
              },
            )
          : RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  ref.read(colocationAsyncProvider.notifier).refresh(),
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

                  if (colocation != null) ...[
                    ColocationInfoCard(colocation: colocation),
                    AppSpacing.gapLg,
                  ],

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
                              '${monthlyTotal.toStringAsFixed(0)} $currency',
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
                  if (roommates.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final r in roommates) ...[
                            AppCard(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                children: [
                                  AppAvatar(name: r.name, size: 48, showOnline: r.isPresent),
                                  AppSpacing.gapSm,
                                  Text(
                                    r.isMe ? 'Vous' : r.name.split(' ').first,
                                    style: context.text.labelLarge,
                                  ),
                                  Text(r.roomNumber, style: context.text.bodySmall),
                                  AppSpacing.gapXxs,
                                  // Présence : seulement sa propre fiche (ou celle d'un colocataire
                                  // sans compte), en touchant le badge et non toute la carte.
                                  InkWell(
                                    borderRadius: AppRadius.brSm,
                                    onTap: !r.canEdit
                                        ? null
                                        : () async {
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
                                    child: AppBadge(
                                      label: r.isPresent ? 'Présent' : 'Absent',
                                      tone: r.isPresent
                                          ? AppBadgeTone.success
                                          : AppBadgeTone.neutral,
                                    ),
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
                              // Seul le colocataire assigné valide sa tâche.
                              onChanged: !c.canComplete
                                  ? null
                                  : (_) async {
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
