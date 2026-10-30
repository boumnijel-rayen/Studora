import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../models/study_models.dart';
import '../providers/study_providers.dart';
import '../study_routes.dart';

class StudyHomeScreen extends ConsumerWidget {
  const StudyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(studySessionsAsyncProvider);
    final tasksAsync = ref.watch(studyTasksAsyncProvider);
    final pomodoroCfg = ref.watch(pomodoroConfigProvider);
    final (minutesToday, sessionsCount) = ref.watch(todayStudyStatsProvider);

    return AppScaffold(
      title: 'Révisions',
      subtitle: 'Sessions & Focus Pomodoro',
      actions: [
        IconButton(
          tooltip: 'Historique & Stats',
          icon: const Icon(Icons.bar_chart_rounded),
          onPressed: () => context.push(StudyRoutes.history),
        ),
        IconButton(
          tooltip: 'Tâches par matière',
          icon: const Icon(Icons.checklist_rounded),
          onPressed: () => context.push(StudyRoutes.tasks),
        ),
      ],
      body: sessionsAsync.when(
        loading: () => const AppSkeletonList(),
        error: (err, _) => AppErrorState.fromError(
          err,
          onRetry: () {
            ref.invalidate(studySessionsAsyncProvider);
            ref.invalidate(studyTasksAsyncProvider);
          },
        ),
        data: (sessions) {
          if (tasksAsync.hasError) {
            return AppErrorState.fromError(
              tasksAsync.error!,
              onRetry: () => ref.invalidate(studyTasksAsyncProvider),
            );
          }
          final tasks = tasksAsync.asData?.value ?? const <StudyTask>[];
          final completedTasks = tasks.where((t) => t.isCompleted).length;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Bannière Minuteur Pomodoro
              AppCard(
                gradient: AppColors.focusGradient,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Minuteur Pomodoro',
                            style: context.text.titleLarge?.copyWith(color: Colors.white),
                          ),
                          AppSpacing.gapXxs,
                          Text(
                            '${pomodoroCfg.workMinutes} min de concentration intense + ${pomodoroCfg.shortBreakMinutes} min de pause',
                            style: context.text.bodyMedium?.copyWith(color: Colors.white70),
                          ),
                          AppSpacing.gapMd,
                          AppButton(
                            label: 'Lancer une session',
                            icon: Icons.play_arrow_rounded,
                            variant: AppButtonVariant.secondary,
                            onPressed: () => context.push(StudyRoutes.pomodoro),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.gapSm,
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.timer_rounded, size: 36, color: Colors.white),
                    ),
                  ],
                ),
              ),
              AppSpacing.gapLg,

              // Statistiques rapides
              Row(
                children: [
                  Expanded(
                    child: AppStatCard(
                      label: 'Temps de focus',
                      value: '${(minutesToday / 60).toStringAsFixed(1)} h',
                      icon: Icons.timelapse_rounded,
                      color: AppColors.moduleStudy,
                      caption: '$sessionsCount terminées',
                    ),
                  ),
                  AppSpacing.gapSm,
                  Expanded(
                    child: AppStatCard(
                      label: 'Tâches validées',
                      value: '$completedTasks / ${tasks.length}',
                      icon: Icons.task_alt_rounded,
                      color: AppColors.tertiary,
                      caption: '${((completedTasks / (tasks.isEmpty ? 1 : tasks.length)) * 100).toInt()}% accompli',
                      onTap: () => context.push(StudyRoutes.tasks),
                    ),
                  ),
                ],
              ),
              AppSpacing.gapLg,

              // En-tête des sessions planifiées
              AppSectionHeader(
                title: 'Sessions de révision (${sessions.length})',
                actionLabel: 'Planifier',
                onAction: () => context.push(StudyRoutes.newSession),
              ),

              if (sessions.isEmpty)
                const AppCard(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: Text('Aucune session programmée')),
                )
              else
                for (final s in sessions) ...[
                  _SessionCard(session: s),
                  AppSpacing.gapSm,
                ],
            ],
          );
        },
      ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session});
  final StudySession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = AppColors.subjectPalette[session.colorIndex % AppColors.subjectPalette.length];

    return AppCard(
      child: Row(
        children: [
          Checkbox(
            value: session.isCompleted,
            onChanged: (_) async {
              try {
                await ref.read(studySessionsAsyncProvider.notifier).toggleCompleted(session.id);
              } catch (e) {
                if (context.mounted) {
                  AppSnackbar.error(context, ApiException.fromError(e).message);
                }
              }
            },
          ),
          AppSpacing.gapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SubjectChip(label: session.subjectName, color: color),
                    const Spacer(),
                    Text(
                      '${session.durationMinutes} min',
                      style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                AppSpacing.gapXxs,
                Text(
                  session.notes.isNotEmpty ? session.notes : 'Révision générale',
                  style: context.text.titleSmall?.copyWith(
                    decoration: session.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (session.linkedDeadlineTitle != null && session.linkedDeadlineTitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Objectif / Tâche : ${session.linkedDeadlineTitle}',
                    style: context.text.bodySmall?.copyWith(color: context.colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            onPressed: () async {
              try {
                await ref.read(studySessionsAsyncProvider.notifier).delete(session.id);
              } catch (e) {
                if (context.mounted) {
                  AppSnackbar.error(context, ApiException.fromError(e).message);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
