import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../providers/grades_providers.dart';

class SubjectGradesDetailScreen extends ConsumerWidget {
  const SubjectGradesDetailScreen({super.key, required this.subjectId});
  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = ref.watch(subjectByIdProvider(subjectId));
    final gradesAsync = ref.watch(gradesAsyncProvider);

    if (subject == null) {
      return const AppScaffold(
        title: 'Matière introuvable',
        body: Center(child: Text('Cette matière n\'existe pas.')),
      );
    }

    return AppScaffold(
      title: subject.name,
      subtitle: subject.teacher.isNotEmpty ? 'Enseignant : ${subject.teacher}' : null,
      body: gradesAsync.when(
        loading: () => const AppSkeletonList(),
        error: (err, _) => AppErrorState.fromError(
          err,
          onRetry: () => ref.invalidate(gradesAsyncProvider),
        ),
        data: (allGrades) {
          final grades = allGrades.where((g) => g.subjectId == subjectId).toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          final double avg = grades.isEmpty
              ? 0.0
              : grades.fold<double>(0, (acc, g) => acc + g.value * g.coefficient) /
                  grades.fold<double>(0, (acc, g) => acc + g.coefficient);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    AppProgressRing(
                      value: (avg / 20.0).clamp(0.0, 1.0),
                      size: 80,
                      strokeWidth: 8,
                      color: subject.color,
                      child: Text(
                        grades.isEmpty ? '—' : avg.toStringAsFixed(1),
                        style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    AppSpacing.gapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Moyenne de la matière', style: context.text.titleSmall),
                          Text('Coefficient d\'examen : ${subject.coefficient}', style: context.text.bodySmall),
                          AppSpacing.gapXxs,
                          Text(
                            grades.isEmpty
                                ? 'Aucune note saisie'
                                : (avg >= 10 ? 'Matière validée ✅' : 'Matière non validée ⚠️'),
                            style: TextStyle(
                              color: grades.isEmpty
                                  ? context.colors.textSecondary
                                  : (avg >= 10 ? context.colors.success : context.colors.warning),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.gapLg,

              AppSectionHeader(
                title: 'Notes attribuées (${grades.length})',
              ),

              if (grades.isEmpty)
                const AppCard(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: Text('Aucune note saisie pour cette matière')),
                )
              else
                for (final g in grades) ...[
                  AppCard(
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: g.value >= 10
                                ? context.colors.success.withValues(alpha: 0.15)
                                : context.colors.error.withValues(alpha: 0.15),
                            borderRadius: AppRadius.brMd,
                          ),
                          child: Text(
                            g.value.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: g.value >= 10 ? context.colors.success : context.colors.error,
                            ),
                          ),
                        ),
                        AppSpacing.gapSm,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.title, style: context.text.titleSmall),
                              Text(
                                'Coeff. ${g.coefficient} • ${Formatters.shortDate(g.date)}',
                                style: context.text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20),
                          onPressed: () async {
                            try {
                              await ref.read(gradesAsyncProvider.notifier).delete(g.id);
                              if (context.mounted) {
                                AppSnackbar.info(context, 'Note supprimée');
                              }
                            } catch (e) {
                              if (context.mounted) {
                                AppSnackbar.error(context, ApiException.fromError(e).message);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapSm,
                ],
            ],
          );
        },
      ),
    );
  }
}
