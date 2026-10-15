import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../models/schedule_models.dart';
import '../providers/schedule_providers.dart';
import '../schedule_routes.dart';

class DeadlinesScreen extends ConsumerStatefulWidget {
  const DeadlinesScreen({super.key});

  @override
  ConsumerState<DeadlinesScreen> createState() => _DeadlinesScreenState();
}

class _DeadlinesScreenState extends ConsumerState<DeadlinesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allDeadlines = ref.watch(deadlinesProvider);
    final pending = allDeadlines.where((d) => !d.isCompleted).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final completed = allDeadlines.where((d) => d.isCompleted).toList();

    return AppScaffold(
      title: 'Échéances & Examens',
      actions: [
        IconButton(
          tooltip: 'Nouvelle échéance',
          icon: const Icon(Icons.add_rounded),
          onPressed: () => context.push(ScheduleRoutes.newDeadline),
        ),
      ],
      bottom: AppTabBar(
        controller: _tabCtrl,
        tabs: ['À venir (${pending.length})', 'Terminées (${completed.length})'],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _DeadlineListView(deadlines: pending, isCompletedTab: false),
          _DeadlineListView(deadlines: completed, isCompletedTab: true),
        ],
      ),
    );
  }
}

class _DeadlineListView extends ConsumerWidget {
  const _DeadlineListView({required this.deadlines, required this.isCompletedTab});
  final List<Deadline> deadlines;
  final bool isCompletedTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (deadlines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCompletedTab ? Icons.done_all_rounded : Icons.task_alt_rounded,
                size: 56,
                color: context.colors.textSecondary,
              ),
              AppSpacing.gapMd,
              Text(
                isCompletedTab ? 'Aucune tâche archivée' : 'Toutes les échéances sont validées ! 🎉',
                style: context.text.titleSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: deadlines.length,
      separatorBuilder: (_, _) => AppSpacing.gapSm,
      itemBuilder: (context, i) {
        final d = deadlines[i];
        final daysLeft = Formatters.daysUntil(d.dueDate);

        return AppCard(
          child: Row(
            children: [
              Checkbox(
                value: d.isCompleted,
                onChanged: (_) {
                  ref.read(deadlinesProvider.notifier).toggleCompleted(d.id);
                  AppSnackbar.info(
                    context,
                    d.isCompleted ? 'Échéance remise en attente' : 'Échéance marquée comme terminée !',
                  );
                },
              ),
              AppSpacing.gapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppBadge(
                          label: d.type.label,
                          tone: d.priority == Priority.high ? AppBadgeTone.error : AppBadgeTone.warning,
                          icon: d.type.icon,
                        ),
                        AppSpacing.gapXs,
                        Text(
                          d.subjectName,
                          style: context.text.labelSmall?.copyWith(color: context.colors.textSecondary),
                        ),
                      ],
                    ),
                    AppSpacing.gapXxs,
                    Text(
                      d.title,
                      style: context.text.titleSmall?.copyWith(
                        decoration: d.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (d.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(d.description, style: context.text.bodySmall, maxLines: 2),
                    ],
                    AppSpacing.gapXs,
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 14, color: context.colors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          Formatters.day(d.dueDate),
                          style: context.text.labelSmall?.copyWith(color: context.colors.textSecondary),
                        ),
                        const Spacer(),
                        if (!d.isCompleted)
                          Text(
                            daysLeft == 0
                                ? 'Aujourd\'hui !'
                                : (daysLeft > 0 ? 'Dans $daysLeft jours' : 'En retard'),
                            style: context.text.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: daysLeft <= 1 ? AppColors.error : AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                onPressed: () => ref.read(deadlinesProvider.notifier).delete(d.id),
              ),
            ],
          ),
        );
      },
    );
  }
}
