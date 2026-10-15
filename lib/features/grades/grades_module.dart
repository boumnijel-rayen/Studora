import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/core.dart';
import 'grades_routes.dart';
import 'providers/grades_providers.dart';
import 'screens/academic_goals_screen.dart';
import 'screens/add_edit_grade_screen.dart';
import 'screens/grade_simulator_screen.dart';
import 'screens/grades_home_screen.dart';
import 'screens/subject_grades_detail_screen.dart';

/// Module 5 — Notes & objectifs académiques (Membre 5).
class GradesModule extends FeatureModule {
  const GradesModule();

  @override
  String get id => 'grades';

  @override
  ModuleEntry get entry => const ModuleEntry(
    label: 'Notes',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights_rounded,
    color: AppColors.moduleGrades,
    rootPath: GradesRoutes.root,
    placement: ModulePlacement.more,
    order: 40,
    description: 'Moyennes, objectifs et calculs de partiels',
  );

  @override
  List<RouteBase> get shellRoutes => [
    GoRoute(
      path: GradesRoutes.root,
      builder: (_, _) => const GradesHomeScreen(),
      routes: [
        GoRoute(
          path: 'new',
          parentNavigatorKey: AppNavigator.rootKey,
          builder: (_, _) => const AddEditGradeScreen(),
        ),
        GoRoute(
          path: 'goals',
          builder: (_, _) => const AcademicGoalsScreen(),
        ),
        GoRoute(
          path: 'simulator',
          builder: (_, _) => const GradeSimulatorScreen(),
        ),
        GoRoute(
          path: 'subjects/:id',
          builder: (_, state) => SubjectGradesDetailScreen(
            subjectId: state.pathParameters['id'] ?? '',
          ),
        ),
      ],
    ),
  ];

  @override
  Widget? buildDashboardCard(BuildContext context) => Consumer(
    builder: (context, ref, _) {
      final overallAvg = ref.watch(overallAverageProvider);
      return AppCard(
        onTap: () => context.go(GradesRoutes.root),
        child: Row(
          children: [
            const AppIconBox(icon: Icons.insights_rounded, color: AppColors.moduleGrades),
            AppSpacing.gapSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Moyenne académique', style: context.text.titleSmall),
                  Text(
                    '${overallAvg.toStringAsFixed(2)} / 20 • En bonne voie',
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
