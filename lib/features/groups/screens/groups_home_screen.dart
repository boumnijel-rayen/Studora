import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../groups_routes.dart';
import '../models/group_models.dart';
import '../providers/groups_providers.dart';

class GroupsHomeScreen extends ConsumerStatefulWidget {
  const GroupsHomeScreen({super.key});

  @override
  ConsumerState<GroupsHomeScreen> createState() => _GroupsHomeScreenState();
}

class _GroupsHomeScreenState extends ConsumerState<GroupsHomeScreen> {
  final _searchCtrl = TextEditingController();
  int _tabIndex = 0; // 0 = Mes groupes, 1 = Découvrir

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsAsyncProvider);
    final query = _searchCtrl.text.trim().toLowerCase();

    return AppScaffold(
      title: 'Groupes d\'étude',
      subtitle: 'Entraide & Travaux dirigés',
      actions: [
        IconButton(
          tooltip: 'Rejoindre via code',
          icon: const Icon(Icons.vpn_key_rounded),
          onPressed: () => context.push(GroupsRoutes.join),
        ),
        IconButton(
          tooltip: 'Créer un groupe',
          icon: const Icon(Icons.group_add_rounded),
          onPressed: () => context.push(GroupsRoutes.newGroup),
        ),
      ],
      body: groupsAsync.when(
        loading: () => const AppSkeletonList(),
        error: (err, _) => AppErrorState.fromError(
          err,
          onRetry: () => ref.invalidate(groupsAsyncProvider),
        ),
        data: (allGroups) {
          final filtered = allGroups.where((g) {
            final matchesQuery = query.isEmpty ||
                g.name.toLowerCase().contains(query) ||
                g.subjectName.toLowerCase().contains(query);
            final matchesTab = _tabIndex == 0 ? g.isJoined : !g.isJoined;
            return matchesQuery && matchesTab;
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              AppSearchField(
                controller: _searchCtrl,
                hint: 'Rechercher un groupe ou une matière...',
                onChanged: (_) => setState(() {}),
              ),
              AppSpacing.gapMd,

              AppSegmentedControl<int>(
                segments: const {0: 'Mes groupes', 1: 'Découvrir'},
                selected: _tabIndex,
                onChanged: (i) => setState(() => _tabIndex = i),
              ),
              AppSpacing.gapLg,

              if (filtered.isEmpty)
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.group_off_rounded, size: 48, color: context.colors.textSecondary),
                        AppSpacing.gapMd,
                        Text(
                          _tabIndex == 0
                              ? 'Vous n\'avez pas encore rejoint de groupe'
                              : 'Aucun groupe disponible pour cette recherche',
                          style: context.text.titleSmall,
                          textAlign: TextAlign.center,
                        ),
                        AppSpacing.gapSm,
                        AppButton(
                          label: 'Rejoindre via un code d\'invitation',
                          variant: AppButtonVariant.tonal,
                          size: AppButtonSize.sm,
                          onPressed: () => context.push(GroupsRoutes.join),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final g in filtered) ...[
                  _GroupCard(group: g),
                  AppSpacing.gapSm,
                ],
            ],
          );
        },
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});
  final StudyGroup group;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.subjectPalette[group.colorIndex % AppColors.subjectPalette.length];

    return AppCard(
      onTap: () => context.push('/groups/${group.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SubjectChip(label: group.subjectName, color: color),
              const Spacer(),
              AppBadge(label: 'Code : ${group.code}', tone: AppBadgeTone.neutral),
            ],
          ),
          AppSpacing.gapSm,
          Text(group.name, style: context.text.titleMedium),
          AppSpacing.gapXxs,
          Text(group.description, style: context.text.bodyMedium, maxLines: 2),
          AppSpacing.gapMd,
          Row(
            children: [
              AppAvatarStack(names: group.memberNames, size: 28),
              AppSpacing.gapSm,
              Text(
                '${group.memberNames.length} membre${group.memberNames.length > 1 ? 's' : ''}',
                style: context.text.labelSmall?.copyWith(color: context.colors.textSecondary),
              ),
              const Spacer(),
              if (group.isJoined)
                TextButton.icon(
                  onPressed: () => context.push('/groups/${group.id}/chat'),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Discussion'),
                )
              else
                const AppBadge(label: 'À rejoindre', tone: AppBadgeTone.primary),
            ],
          ),
        ],
      ),
    );
  }
}
