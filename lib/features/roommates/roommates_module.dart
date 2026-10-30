import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/core.dart';
import 'providers/roommates_providers.dart';
import 'roommates_routes.dart';
import 'screens/add_chore_screen.dart';
import 'screens/add_expense_screen.dart';
import 'screens/add_roommate_screen.dart';
import 'screens/balances_screen.dart';
import 'screens/chores_screen.dart';
import 'screens/expenses_screen.dart';
import 'screens/roommates_home_screen.dart';
import 'screens/roommates_list_screen.dart';

/// Module 6 — Gestion des colocataires (Membre 6).
class RoommatesModule extends FeatureModule {
  const RoommatesModule();

  @override
  String get id => 'roommates';

  @override
  ModuleEntry get entry => const ModuleEntry(
    label: 'Colocation',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    color: AppColors.moduleRoommates,
    rootPath: RoommatesRoutes.root,
    placement: ModulePlacement.more,
    order: 50,
    description: 'Tâches partagées, colocataires et dépenses communes',
  );

  @override
  List<RouteBase> get shellRoutes => [
    GoRoute(
      path: RoommatesRoutes.root,
      builder: (_, _) => const RoommatesHomeScreen(),
      routes: [
        GoRoute(
          path: 'members',
          builder: (_, _) => const RoommatesListScreen(),
          routes: [
            GoRoute(
              path: 'new',
              parentNavigatorKey: AppNavigator.rootKey,
              builder: (_, _) => const AddRoommateScreen(),
            ),
          ],
        ),
        GoRoute(
          path: 'chores',
          builder: (_, _) => const ChoresScreen(),
          routes: [
            GoRoute(
              path: 'new',
              parentNavigatorKey: AppNavigator.rootKey,
              builder: (_, _) => const AddChoreScreen(),
            ),
          ],
        ),
        GoRoute(
          path: 'expenses',
          builder: (_, _) => const ExpensesScreen(),
          routes: [
            GoRoute(
              path: 'new',
              parentNavigatorKey: AppNavigator.rootKey,
              builder: (_, _) => const AddExpenseScreen(),
            ),
          ],
        ),
        GoRoute(
          path: 'balances',
          builder: (_, _) => const BalancesScreen(),
        ),
      ],
    ),
  ];

  @override
  Widget? buildDashboardCard(BuildContext context) => Consumer(
    builder: (context, ref, _) {
      final chores = ref.watch(choresProvider);
      final pendingCount = chores.where((c) => !c.isCompleted).length;
      final netBalance = ref.watch(netUserBalanceProvider);
      final currency = ref.watch(preferencesProvider).currency;
      final sign = netBalance >= 0 ? '+' : '';
      return AppCard(
        onTap: () => context.go(RoommatesRoutes.root),
        child: Row(
          children: [
            const AppIconBox(icon: Icons.home_rounded, color: AppColors.moduleRoommates),
            AppSpacing.gapSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Colocation', style: context.text.titleSmall),
                  Text(
                    '$pendingCount tâche${pendingCount > 1 ? 's' : ''} en attente • Solde $sign${Formatters.money(netBalance, symbol: currency)}',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      );
    },
  );
}
