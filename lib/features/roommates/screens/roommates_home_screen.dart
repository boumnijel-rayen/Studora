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
    final roommates = ref.watch(roommatesProvider);
    final chores = ref.watch(choresProvider);
    final expenses = ref.watch(expensesProvider);
    final pendingChores = chores.where((c) => !c.isCompleted).toList();
    final balances = ref.watch(balancesDueProvider);

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
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Carte solde global
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                const AppIconBox(icon: Icons.payments_rounded, color: AppColors.moduleRoommates, size: 50),
                AppSpacing.gapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Solde net à recevoir', style: context.text.titleSmall),
                      AppSpacing.gapXxs,
                      Text(
                        '+28,00 €',
                        style: context.text.headlineSmall?.copyWith(
                          color: context.colors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('${balances.length} colocataires vous doivent de l\'argent', style: context.text.bodySmall),
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
                  value: '${expenses.fold<double>(0, (a, e) => a + e.amount).toStringAsFixed(0)} €',
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
                        Text(r.name.split(' ').first, style: context.text.labelLarge),
                        Text(r.roomNumber, style: context.text.bodySmall),
                        AppSpacing.gapXxs,
                        AppBadge(
                          label: r.isPresent ? 'Présent' : 'Absent',
                          tone: r.isPresent ? AppBadgeTone.success : AppBadgeTone.neutral,
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
          for (final c in pendingChores.take(3)) ...[
            AppCard(
              child: Row(
                children: [
                  Checkbox(
                    value: c.isCompleted,
                    onChanged: (_) {
                      ref.read(choresProvider.notifier).toggle(c.id);
                      AppSnackbar.success(context, 'Tâche ménagère validée !');
                    },
                  ),
                  AppSpacing.gapSm,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.title, style: context.text.titleSmall),
                        Text('Assigné à : ${c.assignedToName}', style: context.text.bodySmall),
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
    );
  }
}
