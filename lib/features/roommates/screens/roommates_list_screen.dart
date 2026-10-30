import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../providers/roommates_providers.dart';
import '../roommates_routes.dart';

class RoommatesListScreen extends ConsumerWidget {
  const RoommatesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roommatesAsync = ref.watch(roommatesAsyncProvider);
    final roommates = roommatesAsync.value ?? const [];

    return AppScaffold(
      title: 'Colocataires',
      subtitle: '${roommates.length} personne${roommates.length > 1 ? 's' : ''} dans le logement',
      actions: [
        IconButton(
          tooltip: 'Nouveau colocataire',
          icon: const Icon(Icons.person_add_rounded),
          onPressed: () => context.push(RoommatesRoutes.newRoommate),
        ),
      ],
      body: AppAsyncView(
        value: roommatesAsync,
        isEmpty: (items) => items.isEmpty,
        empty: AppEmptyState(
          icon: Icons.people_outline_rounded,
          title: 'Aucun colocataire',
          message: 'Ajoutez les membres de votre colocation pour partager les tâches et dépenses.',
          actionLabel: 'Ajouter un colocataire',
          onAction: () => context.push(RoommatesRoutes.newRoommate),
        ),
        onRetry: () => ref.read(roommatesAsyncProvider.notifier).refresh(),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: items.length,
          separatorBuilder: (_, _) => AppSpacing.gapSm,
          itemBuilder: (context, i) {
            final r = items[i];
            return AppCard(
              child: Row(
                children: [
                  AppAvatar(name: r.name, size: 48, showOnline: r.isPresent),
                  AppSpacing.gapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                r.name,
                                style: context.text.titleSmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            AppSpacing.gapXs,
                            GestureDetector(
                              onTap: () => ref
                                  .read(roommatesAsyncProvider.notifier)
                                  .togglePresence(r.id),
                              child: AppBadge(
                                label: r.isPresent ? 'À l\'appart' : 'Absent',
                                tone: r.isPresent ? AppBadgeTone.success : AppBadgeTone.neutral,
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.gapXxs,
                        Text('${r.roomNumber} • ${r.phone}', style: context.text.bodySmall),
                        Text(
                          r.email,
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Supprimer',
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    onPressed: () async {
                      try {
                        await ref.read(roommatesAsyncProvider.notifier).delete(r.id);
                        if (context.mounted) {
                          AppSnackbar.info(context, 'Colocataire retiré');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AppSnackbar.error(
                            context,
                            e is ApiException
                                ? e.message
                                : 'Impossible de supprimer ce colocataire.',
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
