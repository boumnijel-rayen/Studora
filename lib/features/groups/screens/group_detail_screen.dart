import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../providers/groups_providers.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});
  final String groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider);
    final group = groups.where((g) => g.id == widget.groupId).firstOrNull;

    if (group == null) {
      return const AppScaffold(
        title: 'Groupe introuvable',
        body: Center(child: Text('Ce groupe n\'existe plus.')),
      );
    }

    final color = AppColors.subjectPalette[group.colorIndex % AppColors.subjectPalette.length];

    return AppScaffold(
      title: group.name,
      actions: [
        IconButton(
          tooltip: 'Ouvrir le chat',
          icon: const Icon(Icons.chat_bubble_rounded),
          onPressed: () => context.push('/groups/${group.id}/chat'),
        ),
      ],
      bottom: AppTabBar(
        controller: _tabCtrl,
        tabs: const ['Informations', 'Membres', 'Activités'],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Onglet 1 : Infos
          ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SubjectChip(label: group.subjectName, color: color),
                    AppSpacing.gapMd,
                    Text(group.name, style: context.text.headlineSmall),
                    AppSpacing.gapXs,
                    Text(group.description, style: context.text.bodyMedium),
                    AppSpacing.gapMd,
                    Row(
                      children: [
                        const Icon(Icons.vpn_key_rounded, size: 16),
                        AppSpacing.gapXs,
                        Text('Code d\'accès : ${group.code}', style: context.text.labelMedium),
                        const Spacer(),
                        TextButton(
                          onPressed: () => AppSnackbar.info(context, 'Code ${group.code} copié !'),
                          child: const Text('Copier'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AppSpacing.gapLg,
              AppButton(
                label: 'Accéder à la discussion de groupe',
                icon: Icons.chat_rounded,
                expand: true,
                onPressed: () => context.push('/groups/${group.id}/chat'),
              ),
            ],
          ),

          // Onglet 2 : Membres
          ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: group.memberNames.length,
            separatorBuilder: (_, _) => AppSpacing.gapSm,
            itemBuilder: (context, i) {
              final name = group.memberNames[i];
              return AppCard(
                child: Row(
                  children: [
                    AppAvatar(name: name, size: 40),
                    AppSpacing.gapSm,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: context.text.titleSmall),
                          Text(i == 0 ? 'Créateur du groupe' : 'Étudiant', style: context.text.bodySmall),
                        ],
                      ),
                    ),
                    if (i == 0)
                      const AppBadge(label: 'Admin', tone: AppBadgeTone.primary)
                    else
                      const AppBadge(label: 'Membre', tone: AppBadgeTone.neutral),
                  ],
                ),
              );
            },
          ),

          // Onglet 3 : Activités
          ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const AppIconBox(icon: Icons.event_rounded, color: AppColors.moduleGroups),
                        AppSpacing.gapSm,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Séance de révisions à la BU', style: context.text.titleSmall),
                              Text('Samedi prochain • 14h00 - 17h00', style: context.text.bodySmall),
                            ],
                          ),
                        ),
                        const AppBadge(label: 'À venir', tone: AppBadgeTone.success),
                      ],
                    ),
                    AppSpacing.gapSm,
                    const Text('Préparation collective des annales de partiels et révision des exercices clés.'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
