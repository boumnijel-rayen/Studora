import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../models/roommate_models.dart';
import '../providers/roommates_providers.dart';
import '../roommates_routes.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider);
    final total = expenses.fold<double>(0, (a, e) => a + e.amount);

    return AppScaffold(
      title: 'Dépenses Communes',
      subtitle: '${expenses.length} dépenses enregistrées',
      actions: [
        IconButton(
          tooltip: 'Soldes',
          icon: const Icon(Icons.balance_rounded),
          onPressed: () => context.push(RoommatesRoutes.balances),
        ),
        IconButton(
          tooltip: 'Ajouter une dépense',
          icon: const Icon(Icons.add_rounded),
          onPressed: () => context.push(RoommatesRoutes.newExpense),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Carte total des dépenses
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                const AppIconBox(icon: Icons.receipt_long_rounded, color: AppColors.primary, size: 48),
                AppSpacing.gapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total dépenses partagées', style: context.text.titleSmall),
                      Text(
                        Formatters.money(total),
                        style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text('Soit ${(total / 3).toStringAsFixed(2)} € / personne (3 colocs)', style: context.text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapLg,

          AppSectionHeader(
            title: 'Historique des dépenses',
            actionLabel: 'Nouvelle dépense',
            onAction: () => context.push(RoommatesRoutes.newExpense),
          ),

          if (expenses.isEmpty)
            const AppCard(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: Text('Aucune dépense enregistrée.')),
            )
          else
            for (final exp in expenses) ...[
              _ExpenseTile(expense: exp),
              AppSpacing.gapSm,
            ],
        ],
      ),
    );
  }
}

class _ExpenseTile extends ConsumerWidget {
  const _ExpenseTile({required this.expense});
  final Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = switch (expense.category) {
      'Alimentation' => Icons.shopping_basket_rounded,
      'Factures' => Icons.wifi_rounded,
      'Ménage' => Icons.cleaning_services_rounded,
      _ => Icons.payments_rounded,
    };

    return AppCard(
      child: Row(
        children: [
          AppIconBox(icon: icon, color: AppColors.moduleRoommates, size: 42),
          AppSpacing.gapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.title, style: context.text.titleSmall),
                Text(
                  'Payé par ${expense.paidByName} • ${Formatters.shortDate(expense.date)}',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.money(expense.amount),
                style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              AppBadge(label: expense.category, tone: AppBadgeTone.neutral),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            onPressed: () => ref.read(expensesProvider.notifier).delete(expense.id),
          ),
        ],
      ),
    );
  }
}
