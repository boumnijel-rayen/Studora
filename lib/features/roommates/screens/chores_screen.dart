import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../models/roommate_models.dart';
import '../providers/roommates_providers.dart';
import '../roommates_routes.dart';
import 'roommate_picker.dart';

class ChoresScreen extends ConsumerStatefulWidget {
  const ChoresScreen({super.key});

  @override
  ConsumerState<ChoresScreen> createState() => _ChoresScreenState();
}

class _ChoresScreenState extends ConsumerState<ChoresScreen> {
  /// Nombre de tâches faites affichées tant que l'historique n'est pas déplié.
  static const _historyPreviewCount = 5;
  bool _showFullHistory = false;

  @override
  Widget build(BuildContext context) {
    final choresAsync = ref.watch(choresAsyncProvider);
    final chores = choresAsync.value ?? const [];
    // Tâches de la période en cours (jour, semaine, mois, année) ou en retard ;
    // les occurrences suivantes restent masquées jusqu'à leur période.
    final pending = ref.watch(visiblePendingChoresProvider);
    // Historique : les tâches faites les plus récentes d'abord.
    final completed = chores.where((c) => c.isCompleted).toList()
      ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
    final visibleHistory = _showFullHistory
        ? completed
        : completed.take(_historyPreviewCount).toList();

    return AppScaffold(
      title: 'Tâches ménagères',
      subtitle: '${pending.length} tâche${pending.length > 1 ? 's' : ''} à réaliser',
      actions: [
        IconButton(
          tooltip: 'Ajouter une tâche',
          icon: const Icon(Icons.add_rounded),
          onPressed: () => context.push(RoommatesRoutes.newChore),
        ),
      ],
      body: AppAsyncView(
        value: choresAsync,
        isEmpty: (items) => items.isEmpty,
        empty: AppEmptyState(
          icon: Icons.cleaning_services_outlined,
          title: 'Aucune tâche ménagère',
          message: 'Planifiez les tâches communes de la colocation.',
          actionLabel: 'Nouvelle tâche',
          onAction: () => context.push(RoommatesRoutes.newChore),
        ),
        onRetry: () => ref.read(choresAsyncProvider.notifier).refresh(),
        data: (_) => ListView(
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
                _ChoreTile(key: ValueKey(c.id), chore: c),
                AppSpacing.gapSm,
              ],
            AppSpacing.gapLg,

            if (completed.isNotEmpty) ...[
              const AppSectionHeader(title: 'Historique des tâches faites'),
              for (final c in visibleHistory) ...[
                _ChoreTile(key: ValueKey(c.id), chore: c),
                AppSpacing.gapSm,
              ],
              if (completed.length > _historyPreviewCount)
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _showFullHistory = !_showFullHistory),
                    child: Text(
                      _showFullHistory
                          ? 'Masquer l\'historique'
                          : 'Afficher tout l\'historique (${completed.length})',
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChoreTile extends ConsumerStatefulWidget {
  const _ChoreTile({super.key, required this.chore});
  final Chore chore;

  @override
  ConsumerState<_ChoreTile> createState() => _ChoreTileState();
}

class _ChoreTileState extends ConsumerState<_ChoreTile> {
  /// Empêche un double appui de valider puis annuler la tâche (ou de créer des doublons).
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    final wasCompleted = widget.chore.isCompleted;
    setState(() => _busy = true);
    try {
      await ref.read(choresAsyncProvider.notifier).toggle(widget.chore.id);
      if (mounted) {
        AppSnackbar.info(
          context,
          wasCompleted ? 'Tâche remise en cours' : 'Tâche validée avec succès !',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(
          context,
          e is ApiException ? e.message : 'Erreur lors de la mise à jour.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Supprimer « ${widget.chore.title} » ?',
      message: 'La tâche sera retirée du planning de la colocation.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(choresAsyncProvider.notifier).delete(widget.chore.id);
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(
          context,
          e is ApiException ? e.message : 'Impossible de supprimer la tâche.',
        );
      }
    }
  }

  /// Réassigne la tâche en choisissant un colocataire dans la liste.
  Future<void> _reassign() async {
    final members = ref.read(roommatesProvider);
    final chosen = await showRoommatePickerSheet(
      context,
      members: members,
      selectedId: widget.chore.assignedToId,
      title: 'Assigner « ${widget.chore.title} » à',
    );
    if (chosen == null || chosen == widget.chore.assignedToId || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(choresAsyncProvider.notifier).reassign(widget.chore.id, chosen);
      if (mounted) AppSnackbar.info(context, 'Tâche réassignée');
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(
          context,
          e is ApiException ? e.message : 'Impossible de réassigner la tâche.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chore = widget.chore;
    return AppCard(
      child: Row(
        children: [
          if (chore.canComplete)
            Checkbox(
              value: chore.isCompleted,
              onChanged: _busy ? null : (_) => _toggle(),
            )
          else
            // Case verrouillée : seul le colocataire assigné valide sa tâche.
            Tooltip(
              message: 'Seul ${chore.assignedToName} peut valider cette tâche',
              child: Checkbox(value: chore.isCompleted, onChanged: null),
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
                    Flexible(
                      child: InkWell(
                        // Tâche à faire : appui sur le colocataire pour la réassigner.
                        onTap: chore.isCompleted || _busy || !chore.canReassign ? null : _reassign,
                        borderRadius: AppRadius.brSm,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppAvatar(name: chore.assignedToName, size: 20),
                            AppSpacing.gapXs,
                            Flexible(
                              child: Text(
                                chore.assignedToName,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.labelSmall?.copyWith(
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ),
                            if (!chore.isCompleted && chore.canReassign)
                              Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 18,
                                color: context.colors.textSecondary,
                              ),
                          ],
                        ),
                      ),
                    ),
                    AppSpacing.gapXs,
                    Text(
                      Formatters.shortDate(chore.dueDate.toLocal()),
                      style: context.text.labelSmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
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
          if (chore.canDelete)
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              onPressed: _busy ? null : _delete,
            ),
        ],
      ),
    );
  }
}
