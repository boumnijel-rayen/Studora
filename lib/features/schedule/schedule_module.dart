import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/core.dart';
import 'providers/schedule_providers.dart';
import 'schedule_routes.dart';
import 'screens/add_edit_course_screen.dart';
import 'screens/add_edit_deadline_screen.dart';
import 'screens/course_detail_screen.dart';
import 'screens/deadlines_screen.dart';
import 'screens/notifications_center_screen.dart';
import 'screens/schedule_home_screen.dart';

/// Module 2 — Emploi du temps & rappels (Membre 2).
class ScheduleModule extends FeatureModule {
  const ScheduleModule();

  @override
  String get id => 'schedule';

  @override
  ModuleEntry get entry => const ModuleEntry(
    label: 'Planning',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month_rounded,
    color: AppColors.moduleSchedule,
    rootPath: ScheduleRoutes.root,
    placement: ModulePlacement.tab,
    order: 10,
    description: 'Emploi du temps, échéances et rappels',
  );

  @override
  List<RouteBase> get shellRoutes => [
    GoRoute(
      path: ScheduleRoutes.root,
      builder: (_, _) => const ScheduleHomeScreen(),
      routes: [
        GoRoute(
          path: 'courses/new',
          parentNavigatorKey: AppNavigator.rootKey,
          builder: (_, _) => const AddEditCourseScreen(),
        ),
        GoRoute(
          path: 'courses/:id',
          parentNavigatorKey: AppNavigator.rootKey,
          builder: (_, state) => CourseDetailScreen(courseId: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(
          path: 'deadlines',
          builder: (_, _) => const DeadlinesScreen(),
          routes: [
            GoRoute(
              path: 'new',
              parentNavigatorKey: AppNavigator.rootKey,
              builder: (_, _) => const AddEditDeadlineScreen(),
            ),
          ],
        ),
        GoRoute(
          path: 'notifications',
          parentNavigatorKey: AppNavigator.rootKey,
          builder: (_, _) => const NotificationsCenterScreen(),
        ),
      ],
    ),
  ];

  @override
  Widget? buildDashboardCard(BuildContext context) => Consumer(
    builder: (context, ref, _) {
      final todayCourses = ref.watch(todayCoursesProvider);
      return AppCard(
        onTap: () => context.go(ScheduleRoutes.root),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppIconBox(
                  icon: Icons.calendar_month_rounded,
                  color: AppColors.moduleSchedule,
                ),
                AppSpacing.gapSm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Emploi du temps', style: context.text.titleSmall),
                      Text(
                        '${todayCourses.length} cours prévus aujourd\'hui',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            if (todayCourses.isNotEmpty) ...[
              AppSpacing.gapSm,
              const Divider(),
              AppSpacing.gapSm,
              for (final c in todayCourses.take(2))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.subjectPalette[c.colorIndex % AppColors.subjectPalette.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      AppSpacing.gapXs,
                      Text(c.subjectName, style: context.text.bodyMedium),
                      const Spacer(),
                      Text(
                        c.timeSlot,
                        style: context.text.labelSmall?.copyWith(color: context.colors.textSecondary),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}
