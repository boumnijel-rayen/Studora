import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../groups_routes.dart';
import '../models/group_models.dart';
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

  Future<void> _openCreateActivitySheet(StudyGroup group) async {
    final titleCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var date = DateTime.now().add(const Duration(days: 2));

    await AppBottomSheet.show<void>(
      context,
      title: 'Nouvelle activité de groupe',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: titleCtrl,
              label: 'Titre de la séance',
              hint: 'ex: Révision collective à la BU',
            ),
            AppSpacing.gapMd,
            AppTextField(
              controller: locationCtrl,
              label: 'Lieu',
              hint: 'ex: Bibliothèque universitaire — Salle 2',
            ),
            AppSpacing.gapMd,
            AppDateField(
              label: 'Date',
              initialValue: date,
              onChanged: (d) => setSheetState(() => date = d),
            ),
            AppSpacing.gapMd,
            AppTextField(
              controller: descCtrl,
              label: 'Description',
              maxLines: 2,
            ),
            AppSpacing.gapLg,
            AppButton(
              label: 'Planifier l\'activité',
              icon: Icons.check_rounded,
              expand: true,
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                try {
                  final user = ref.read(currentUserProvider);
                  await ref.read(groupChatServiceProvider).createActivity(
                    GroupActivity(
                      id: '',
                      groupId: group.id,
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      date: date,
                      location: locationCtrl.text.trim(),
                      participantNames: user != null ? [user.fullName] : const [],
                    ),
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                } catch (e) {
                  if (ctx.mounted) {
                    AppSnackbar.error(ctx, ApiException.fromError(e).message);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsAsyncProvider);
    final activitiesAsync = ref.watch(groupActivitiesFamilyProvider(widget.groupId));

    return groupsAsync.when(
      loading: () => const AppScaffold(title: 'Groupe', body: AppLoader()),
      error: (err, _) => AppScaffold(
        title: 'Erreur',
        body: AppErrorState.fromError(
          err,
          onRetry: () => ref.invalidate(groupsAsyncProvider),
        ),
      ),
      data: (groups) {
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
            if (group.isJoined)
              IconButton(
                tooltip: 'Planifier une activité',
                icon: const Icon(Icons.event_available_rounded),
                onPressed: () => _openCreateActivitySheet(group),
              ),
            if (group.isJoined)
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
                        if (group.code.isNotEmpty)
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
                          )
                        else
                          Text(
                            'Demandez le code d\'accès à un membre pour rejoindre ce groupe.',
                            style: context.text.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  AppSpacing.gapLg,
                  if (group.isJoined)
                    AppButton(
                      label: 'Accéder à la discussion de groupe',
                      icon: Icons.chat_rounded,
                      expand: true,
                      onPressed: () => context.push('/groups/${group.id}/chat'),
                    )
                  else
                    AppButton(
                      label: 'Rejoindre avec un code',
                      icon: Icons.group_add_rounded,
                      expand: true,
                      onPressed: () => context.push(GroupsRoutes.join),
                    ),
                ],
              ),

              // Onglet 2 : Membres
              group.memberNames.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'Aucun membre inscrit',
                    )
                  : ListView.separated(
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

              // Onglet 3 : Activités depuis Strapi
              AppAsyncView<List<GroupActivity>>(
                value: activitiesAsync,
                isEmpty: (list) => list.isEmpty,
                empty: AppEmptyState(
                  icon: Icons.event_note_rounded,
                  title: 'Aucune activité planifiée',
                  message: 'Programmez une séance de révision collective pour ce groupe.',
                  actionLabel: group.isJoined ? 'Planifier une séance' : null,
                  onAction: group.isJoined ? () => _openCreateActivitySheet(group) : null,
                ),
                onRetry: () => ref.invalidate(groupActivitiesFamilyProvider(widget.groupId)),
                data: (activities) => ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: activities.length,
                  separatorBuilder: (_, _) => AppSpacing.gapSm,
                  itemBuilder: (context, i) {
                    final act = activities[i];
                    return AppCard(
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
                                    Text(act.title, style: context.text.titleSmall),
                                    Text(
                                      '${Formatters.day(act.date)}${act.location.isNotEmpty ? ' • ${act.location}' : ''}',
                                      style: context.text.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const AppBadge(label: 'À venir', tone: AppBadgeTone.success),
                            ],
                          ),
                          if (act.description.isNotEmpty) ...[
                            AppSpacing.gapSm,
                            Text(act.description),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
