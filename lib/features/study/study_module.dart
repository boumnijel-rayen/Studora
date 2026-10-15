import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/core.dart';
import 'providers/study_providers.dart';
import 'screens/create_session_screen.dart';
import 'screens/pomodoro_settings_screen.dart';
import 'screens/pomodoro_timer_screen.dart';
import 'screens/study_history_screen.dart';
import 'screens/study_home_screen.dart';
import 'screens/study_tasks_screen.dart';
import 'study_routes.dart';

/// Module 3 — Révisions & Pomodoro (Membre 3).
class StudyModule extends FeatureModule {
  const StudyModule();

  @override
  String get id => 'study';

  @override
  ModuleEntry get entry => const ModuleEntry(
    label: 'Révisions',
    icon: Icons.timer_outlined,
    selectedIcon: Icons.timer_rounded,
    color: AppColors.moduleStudy,
    rootPath: StudyRoutes.root,
    placement: ModulePlacement.tab,
    order: 20,
    description: 'Sessions de révision et Pomodoro',
  );

  @override
  List<RouteBase> get shellRoutes => [
    GoRoute(
      path: StudyRoutes.root,
      builder: (_, _) => const StudyHomeScreen(),
      routes: [
        GoRoute(
          path: 'sessions/new',
          parentNavigatorKey: AppNavigator.rootKey,
          builder: (_, _) => const CreateSessionScreen(),
        ),
        GoRoute(
          path: 'tasks',
          builder: (_, _) => const StudyTasksScreen(),
        ),
        GoRoute(
          path: 'history',
          builder: (_, _) => const StudyHistoryScreen(),
        ),
        GoRoute(
          path: 'pomodoro',
          parentNavigatorKey: AppNavigator.rootKey,
          builder: (_, _) => const PomodoroTimerScreen(),
          routes: [
            GoRoute(
              path: 'settings',
              parentNavigatorKey: AppNavigator.rootKey,
              builder: (_, _) => const PomodoroSettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ];

  @override
  Widget? buildDashboardCard(BuildContext context) => Consumer(
    builder: (context, ref, _) {
      final (minutesToday, sessionsCompleted) = ref.watch(todayStudyStatsProvider);
      return AppCard(
        onTap: () => context.go(StudyRoutes.root),
        child: Row(
          children: [
            const AppIconBox(icon: Icons.timer_rounded, color: AppColors.moduleStudy),
            AppSpacing.gapSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Révisions & Focus', style: context.text.titleSmall),
                  Text(
                    '$sessionsCompleted session${sessionsCompleted > 1 ? 's' : ''} • $minutesToday min cumulées',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            AppButton(
              label: 'Focus',
              icon: Icons.play_arrow_rounded,
              size: AppButtonSize.sm,
              variant: AppButtonVariant.tonal,
              onPressed: () => context.push(StudyRoutes.pomodoro),
            ),
          ],
        ),
      );
    },
  );
}
