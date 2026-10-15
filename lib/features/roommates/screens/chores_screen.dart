import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../models/roommate_models.dart';
import '../providers/roommates_providers.dart';
import '../roommates_routes.dart';

class ChoresScreen extends ConsumerWidget {
  const ChoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chores = ref.watch(choresProvider);
    final pending = chores.where((c) => !c.isCompleted).toList();
    final completed = chores.where((c) => c.isCompleted).toList();

    return AppScaffold(
      title: 'Tâches ménagères',
      subtitle: '${pending.length} tâches à réaliser',
      actions: [
        IconButton(
          tooltip: 'Ajouter une tâche',
          icon: const Icon(Icons.add_rounded),
          onPressed: () => context.push(RoommatesRoutes.newChore),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const AppSectionHeader(title: 'Tâches en attente'),
          if (pending.isEmpty)
            const AppCard(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: Text('L\'appartement est parfaitement propre ! ✨')),
            )
          else
            for (final c in pending) ...[
              _ChoreTile(chore: c),
              AppSpacing.gapSm,
            ],
          AppSpacing.gapLg,

          if (completed.isNotEmpty) ...[
            const AppSectionHeader(title: 'Historique des tâches faites'),
            for (final c in completed) ...[
              _ChoreTile(chore: c),
              AppSpacing.gapSm,
            ],
          ],
        ],
      ),
    );
  }
}

class _ChoreTile extends ConsumerWidget {
  const _ChoreTile({required this.chore});
  final Chore chore;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppCard(
    child: Row(
      children: [
        Checkbox(
          value: chore.isCompleted,
          onChanged: (_) {
            ref.read(choresProvider.notifier).toggle(chore.id);
            AppSnackbar.info(
              context,
              chore.isCompleted ? 'Tâche remise en cours' : 'Tâche validée avec succès !',
            );
          },
        ),
        AppSpacing.gapSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chore.title,
                style: context.text.titleSmall?.copyWith(
                  decoration: chore.isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
              AppSpacing.gapXxs,
              Row(
                children: [
                  AppAvatar(name: chore.assignedToName, size: 20),
                  AppSpacing.gapXs,
                  Text(
                    chore.assignedToName,
                    style: context.text.labelSmall?.copyWith(color: context.colors.textSecondary),
                  ),
                  const Spacer(),
                  AppBadge(
                    label: chore.frequency,
                    tone: chore.isCompleted ? AppBadgeTone.neutral : AppBadgeTone.warning,
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 20),
          onPressed: () => ref.read(choresProvider.notifier).delete(chore.id),
        ),
      ],
    ),
  );
}
