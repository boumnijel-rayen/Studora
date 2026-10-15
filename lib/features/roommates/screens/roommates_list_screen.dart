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
    final roommates = ref.watch(roommatesProvider);

    return AppScaffold(
      title: 'Colocataires',
      subtitle: '${roommates.length} personnes dans le logement',
      actions: [
        IconButton(
          tooltip: 'Nouveau colocataire',
          icon: const Icon(Icons.person_add_rounded),
          onPressed: () => context.push(RoommatesRoutes.newRoommate),
        ),
      ],
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: roommates.length,
        separatorBuilder: (_, _) => AppSpacing.gapSm,
        itemBuilder: (context, i) {
          final r = roommates[i];
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
                          Text(r.name, style: context.text.titleSmall),
                          AppSpacing.gapXs,
                          AppBadge(
                            label: r.isPresent ? 'À l\'appart' : 'Absent',
                            tone: r.isPresent ? AppBadgeTone.success : AppBadgeTone.neutral,
                          ),
                        ],
                      ),
                      AppSpacing.gapXxs,
                      Text('${r.roomNumber} • ${r.phone}', style: context.text.bodySmall),
                      Text(r.email, style: context.text.bodySmall?.copyWith(color: context.colors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.phone_outlined, color: AppColors.primary),
                  onPressed: () => AppSnackbar.info(context, 'Appel vers ${r.phone} simulé'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
