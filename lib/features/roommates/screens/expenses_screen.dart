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
    final expensesAsync = ref.watch(expensesAsyncProvider);
    final expenses = expensesAsync.value ?? const [];
    final sharedExpenses = ref.watch(sharedExpensesProvider);
    final myShare = ref.watch(myExpensesShareProvider);
    final currency = ref.watch(preferencesProvider).currency;

    final total = sharedExpenses.fold<double>(0, (a, e) => a + e.amount);

    return AppScaffold(
      title: 'Dépenses Communes',
      subtitle: '${expenses.length} opération${expenses.length > 1 ? 's' : ''} enregistrée${expenses.length > 1 ? 's' : ''}',
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
      body: AppAsyncView(
        value: expensesAsync,
        isEmpty: (items) => items.isEmpty,
        empty: AppEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Aucune dépense commune',
          message: 'Ajoutez vos achats partagés pour suivre l\'équilibre des comptes.',
          actionLabel: 'Nouvelle dépense',
          onAction: () => context.push(RoommatesRoutes.newExpense),
        ),
        onRetry: () => ref.read(expensesAsyncProvider.notifier).refresh(),
        data: (items) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Carte total des dépenses
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  const AppIconBox(
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.primary,
                    size: 48,
                  ),
                  AppSpacing.gapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total dépenses partagées', style: context.text.titleSmall),
                        Text(
                          Formatters.money(total, symbol: currency),
                          style: context.text.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Dont votre part : ${Formatters.money(myShare, symbol: currency)}',
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.gapLg,

            AppSectionHeader(
              title: 'Historique des opérations',
              actionLabel: 'Nouvelle dépense',
              onAction: () => context.push(RoommatesRoutes.newExpense),
            ),

            for (final exp in items) ...[
              _ExpenseTile(expense: exp, currency: currency),
              AppSpacing.gapSm,
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpenseTile extends ConsumerWidget {
  const _ExpenseTile({required this.expense, required this.currency});
  final Expense expense;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = switch (expense.category) {
      'Alimentation' => Icons.shopping_basket_rounded,
      'Factures' => Icons.wifi_rounded,
      'Ménage' => Icons.cleaning_services_rounded,
      'Remboursement' => Icons.swap_horiz_rounded,
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
                  expense.isSettlement && expense.reimbursedToName != null
                      ? '${expense.paidByName} → ${expense.reimbursedToName} • ${Formatters.shortDate(expense.date)}'
                      : 'Payé par ${expense.paidByName} • ${Formatters.shortDate(expense.date)}',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.money(expense.amount, symbol: currency),
                style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              AppBadge(
                label: expense.category,
                tone: expense.isSettlement ? AppBadgeTone.success : AppBadgeTone.neutral,
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            onPressed: () async {
              try {
                await ref.read(expensesAsyncProvider.notifier).delete(expense.id);
              } catch (e) {
                if (context.mounted) {
                  AppSnackbar.error(
                    context,
                    e is ApiException ? e.message : 'Impossible de supprimer la dépense.',
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
