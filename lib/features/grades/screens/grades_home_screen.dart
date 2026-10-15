import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../grades_routes.dart';
import '../providers/grades_providers.dart';

class GradesHomeScreen extends ConsumerWidget {
  const GradesHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overallAvg = ref.watch(overallAverageProvider);
    final subjectAvgs = ref.watch(subjectAveragesProvider);
    final grades = ref.watch(gradesProvider);
    const subjects = MockSharedData.subjects;

    return AppScaffold(
      title: 'Notes & Objectifs',
      subtitle: 'Suivi de la progression académique',
      actions: [
        IconButton(
          tooltip: 'Simulateur de note',
          icon: const Icon(Icons.calculate_outlined),
          onPressed: () => context.push(GradesRoutes.simulator),
        ),
        IconButton(
          tooltip: 'Objectifs',
          icon: const Icon(Icons.flag_outlined),
          onPressed: () => context.push(GradesRoutes.goals),
        ),
        IconButton(
          tooltip: 'Ajouter une note',
          icon: const Icon(Icons.add_rounded),
          onPressed: () => context.push(GradesRoutes.newGrade),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Carte principale : Moyenne générale
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                AppProgressRing(
                  value: overallAvg / 20.0,
                  size: 100,
                  strokeWidth: 10,
                  color: overallAvg >= 14
                      ? AppColors.tertiary
                      : (overallAvg >= 10 ? AppColors.primary : AppColors.warning),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        overallAvg.toStringAsFixed(2),
                        style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text('/ 20', style: context.text.labelSmall),
                    ],
                  ),
                ),
                AppSpacing.gapLg,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Moyenne générale', style: context.text.titleMedium),
                      AppSpacing.gapXxs,
                      Text(
                        overallAvg >= 16
                            ? 'Mention Très Bien 🌟'
                            : (overallAvg >= 14
                                ? 'Mention Bien 👍'
                                : (overallAvg >= 12 ? 'Mention Assez Bien' : 'En cours d\'acquisition')),
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AppSpacing.gapXxs,
                      Text('${grades.length} notes enregistrées au total', style: context.text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapLg,

          // Raccourcis rapides
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Simulateur',
                  icon: Icons.calculate_rounded,
                  variant: AppButtonVariant.tonal,
                  onPressed: () => context.push(GradesRoutes.simulator),
                ),
              ),
              AppSpacing.gapSm,
              Expanded(
                child: AppButton(
                  label: 'Mes Objectifs',
                  icon: Icons.flag_rounded,
                  variant: AppButtonVariant.tonal,
                  onPressed: () => context.push(GradesRoutes.goals),
                ),
              ),
            ],
          ),
          AppSpacing.gapLg,

          // Liste des matières
          AppSectionHeader(
            title: 'Moyennes par matière',
            actionLabel: 'Ajouter une note',
            onAction: () => context.push(GradesRoutes.newGrade),
          ),

          for (final sub in subjects) ...[
            _SubjectGradeTile(
              subject: sub,
              average: subjectAvgs[sub.id],
              gradesCount: grades.where((g) => g.subjectId == sub.id).length,
            ),
            AppSpacing.gapSm,
          ],
        ],
      ),
    );
  }
}

class _SubjectGradeTile extends StatelessWidget {
  const _SubjectGradeTile({
    required this.subject,
    required this.average,
    required this.gradesCount,
  });

  final Subject subject;
  final double? average;
  final int gradesCount;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => context.push('/grades/subjects/${subject.id}'),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: subject.color.withValues(alpha: 0.15),
            borderRadius: AppRadius.brMd,
          ),
          child: Icon(subject.icon, color: subject.color, size: 22),
        ),
        AppSpacing.gapSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subject.name, style: context.text.titleSmall),
              Text(
                'Coeff. ${subject.coefficient} • $gradesCount note${gradesCount > 1 ? 's' : ''}',
                style: context.text.bodySmall,
              ),
            ],
          ),
        ),
        if (average != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: average! >= 10
                  ? context.colors.success.withValues(alpha: 0.15)
                  : context.colors.error.withValues(alpha: 0.15),
              borderRadius: AppRadius.brMd,
            ),
            child: Text(
              '${average!.toStringAsFixed(1)} / 20',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: average! >= 10 ? context.colors.success : context.colors.error,
              ),
            ),
          )
        else
          Text('Pas de note', style: context.text.bodySmall),
        AppSpacing.gapSm,
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
  );
}
