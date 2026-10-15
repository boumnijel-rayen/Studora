import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/core.dart';
import 'groups_routes.dart';
import 'screens/create_group_screen.dart';
import 'screens/group_chat_screen.dart';
import 'screens/group_detail_screen.dart';
import 'screens/groups_home_screen.dart';
import 'screens/join_group_screen.dart';

/// Module 4 — Groupes d'étude (Membre 4).
class GroupsModule extends FeatureModule {
  const GroupsModule();

  @override
  String get id => 'groups';

  @override
  ModuleEntry get entry => const ModuleEntry(
    label: 'Groupes',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups_rounded,
    color: AppColors.moduleGroups,
    rootPath: GroupsRoutes.root,
    placement: ModulePlacement.tab,
    order: 30,
    description: 'Groupes d\'étude et discussions',
  );

  @override
  List<RouteBase> get shellRoutes => [
    GoRoute(
      path: GroupsRoutes.root,
      builder: (_, _) => const GroupsHomeScreen(),
      routes: [
        GoRoute(
          path: 'new',
          parentNavigatorKey: AppNavigator.rootKey,
          builder: (_, _) => const CreateGroupScreen(),
        ),
        GoRoute(
          path: 'join',
          parentNavigatorKey: AppNavigator.rootKey,
          builder: (_, _) => const JoinGroupScreen(),
        ),
        GoRoute(
          path: ':id',
          builder: (_, state) => GroupDetailScreen(groupId: state.pathParameters['id'] ?? ''),
          routes: [
            GoRoute(
              path: 'chat',
              parentNavigatorKey: AppNavigator.rootKey,
              builder: (_, state) => GroupChatScreen(groupId: state.pathParameters['id'] ?? ''),
            ),
          ],
        ),
      ],
    ),
  ];

  @override
  Widget? buildDashboardCard(BuildContext context) => AppCard(
    onTap: () => context.go(GroupsRoutes.root),
    child: Row(
      children: [
        const AppIconBox(icon: Icons.groups_rounded, color: AppColors.moduleGroups),
        AppSpacing.gapSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Groupes d\'étude', style: context.text.titleSmall),
              Text('2 groupes actifs • 1 message non lu', style: context.text.bodySmall),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
  );
}
