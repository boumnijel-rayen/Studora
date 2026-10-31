import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../models/roommate_models.dart';
import '../providers/roommates_providers.dart';
import '../roommates_routes.dart';
import 'colocation_info_card.dart';

class RoommatesListScreen extends ConsumerWidget {
  const RoommatesListScreen({super.key});

  Future<void> _togglePresence(BuildContext context, WidgetRef ref, Roommate r) async {
    try {
      await ref.read(roommatesAsyncProvider.notifier).togglePresence(r.id);
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.error(
          context,
          e is ApiException ? e.message : 'Impossible de modifier la présence.',
        );
      }
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, Roommate r) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Retirer ${r.name} ?',
      message: 'Ses dépenses restent dans l\'historique et ses tâches en attente seront réassignées.',
      confirmLabel: 'Retirer',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await ref.read(roommatesAsyncProvider.notifier).delete(r.id);
      if (context.mounted) {
        AppSnackbar.info(context, 'Colocataire retiré');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.error(
          context,
          e is ApiException ? e.message : 'Impossible de retirer ce colocataire.',
        );
      }
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final balance = ref.read(netUserBalanceProvider);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Quitter la colocation ?',
      message: balance.abs() > 0.01
          ? 'Vos comptes ne sont pas équilibrés : votre solde restera visible par les autres membres.'
          : 'Si vous êtes le dernier membre avec un compte, la colocation et ses données seront supprimées.',
      confirmLabel: 'Quitter',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await ref.read(colocationAsyncProvider.notifier).leave();
      if (context.mounted) {
        AppSnackbar.info(context, 'Vous avez quitté la colocation');
        context.go(RoommatesRoutes.root);
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.error(context, ApiException.fromError(e).message);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roommatesAsync = ref.watch(roommatesAsyncProvider);
    final roommates = ref.watch(roommatesProvider);
    final colocation = ref.watch(colocationProvider);

    return AppScaffold(
      title: 'Colocataires',
      subtitle: '${roommates.length} personne${roommates.length > 1 ? 's' : ''} dans le logement',
      actions: [
        IconButton(
          tooltip: 'Ajouter une personne sans compte',
          icon: const Icon(Icons.person_add_rounded),
          onPressed: () => context.push(RoommatesRoutes.newRoommate),
        ),
      ],
      body: AppAsyncView(
        value: roommatesAsync,
        onRetry: () => ref.read(roommatesAsyncProvider.notifier).refresh(),
        data: (_) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            for (final r in roommates) ...[
              AppCard(
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
                                  r.isMe ? '${r.name} (vous)' : r.name,
                                  style: context.text.titleSmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              AppSpacing.gapXs,
                              GestureDetector(
                                onTap: r.canEdit ? () => _togglePresence(context, ref, r) : null,
                                child: AppBadge(
                                  label: r.isPresent ? 'À l\'appart' : 'Absent',
                                  tone: r.isPresent ? AppBadgeTone.success : AppBadgeTone.neutral,
                                ),
                              ),
                            ],
                          ),
                          AppSpacing.gapXxs,
                          Text(
                            [r.roomNumber, if (r.phone.isNotEmpty) r.phone].join(' • '),
                            style: context.text.bodySmall,
                          ),
                          if (r.email.isNotEmpty)
                            Text(
                              r.email,
                              style: context.text.bodySmall?.copyWith(
                                color: context.colors.textSecondary,
                              ),
                            ),
                          if (r.isOwner)
                            Text(
                              'Propriétaire du groupe',
                              style: context.text.bodySmall?.copyWith(
                                color: context.colors.primary,
                              ),
                            ),
                          if (!r.hasAccount)
                            Text(
                              'Sans compte Studora',
                              style: context.text.bodySmall?.copyWith(
                                color: context.colors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (r.canEdit)
                      IconButton(
                        tooltip: 'Modifier',
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => context.push(RoommatesRoutes.editRoommate(r.id)),
                      ),
                    if (!r.isMe && (!r.hasAccount || colocation?.isCreator == true))
                      IconButton(
                        tooltip: 'Retirer',
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        onPressed: () => _remove(context, ref, r),
                      ),
                  ],
                ),
              ),
              AppSpacing.gapSm,
            ],
            AppSpacing.gapMd,
            if (colocation != null) ...[
              ColocationInfoCard(colocation: colocation),
              AppSpacing.gapLg,
              AppButton(
                label: 'Quitter la colocation',
                icon: Icons.logout_rounded,
                variant: AppButtonVariant.danger,
                expand: true,
                onPressed: () => _leave(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
