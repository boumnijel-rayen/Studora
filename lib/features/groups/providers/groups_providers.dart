import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/group_models.dart';

/// Groupes d'étude connectés à Strapi (`/api/study-groups`).
class GroupsAsyncNotifier extends AsyncNotifier<List<StudyGroup>> {
  @override
  Future<List<StudyGroup>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];

    final client = ref.read(strapiClientProvider);
    final items = await client.getList('/study-groups');
    return items.map(StudyGroup.fromJson).toList();
  }

  Future<StudyGroup> addGroup(StudyGroup group) async {
    final client = ref.read(strapiClientProvider);
    final response = await client.post('/study-groups', body: group.toJson());
    final created = StudyGroup.fromJson(StrapiClient.unwrapMap(response));
    final current = state.asData?.value ?? const <StudyGroup>[];
    state = AsyncData([...current, created]);
    return created;
  }

  Future<StudyGroup> joinGroup(String code) async {
    final client = ref.read(strapiClientProvider);
    final response = await client.post(
      '/study-groups/join',
      body: {'code': code.trim().toUpperCase()},
    );
    final joined = StudyGroup.fromJson(StrapiClient.unwrapMap(response));
    final current = state.asData?.value ?? const <StudyGroup>[];
    final exists = current.any((g) => g.id == joined.id);
    if (exists) {
      state = AsyncData([
        for (final g in current) g.id == joined.id ? joined : g,
      ]);
    } else {
      state = AsyncData([...current, joined]);
    }
    return joined;
  }

  Future<void> deleteGroup(String id) async {
    final client = ref.read(strapiClientProvider);
    await client.delete('/study-groups/$id');
    final current = state.asData?.value ?? const <StudyGroup>[];
    state = AsyncData(current.where((g) => g.id != id).toList());
  }
}

final groupsAsyncProvider =
    AsyncNotifierProvider<GroupsAsyncNotifier, List<StudyGroup>>(GroupsAsyncNotifier.new);

final groupsProvider = Provider<List<StudyGroup>>(
  (ref) => ref.watch(groupsAsyncProvider).asData?.value ?? const [],
);

/// Messages d'un groupe récupérés et envoyés via Strapi (`/api/group-messages`).
final groupMessagesFamilyProvider =
    FutureProvider.family<List<GroupMessage>, String>((ref, groupId) async {
      final user = ref.watch(currentUserProvider);
      if (user == null || groupId.isEmpty) return const [];

      final client = ref.read(strapiClientProvider);
      final items = await client.getList(
        '/group-messages',
        queryParameters: {'groupId': groupId},
      );
      return items
          .map((json) => GroupMessage.fromJson(json, currentUserId: user.id))
          .toList();
    });

/// Activités d'un groupe récupérées depuis Strapi (`/api/group-activities`).
final groupActivitiesFamilyProvider =
    FutureProvider.family<List<GroupActivity>, String>((ref, groupId) async {
      final user = ref.watch(currentUserProvider);
      if (user == null || groupId.isEmpty) return const [];

      // Les activités sont réservées aux membres du groupe.
      final groups = await ref.watch(groupsAsyncProvider.future);
      final group = groups.where((g) => g.id == groupId).firstOrNull;
      if (group == null || !group.isJoined) return const [];

      final client = ref.read(strapiClientProvider);
      final items = await client.getList(
        '/group-activities',
        queryParameters: {'groupId': groupId},
      );
      return items.map(GroupActivity.fromJson).toList();
    });

/// Service d'actions sur les messages et activités d'un groupe.
class GroupChatService {
  GroupChatService(this._ref);
  final Ref _ref;

  Future<GroupMessage> sendMessage({
    required String groupId,
    required String text,
    required String senderName,
  }) async {
    final client = _ref.read(strapiClientProvider);
    final user = _ref.read(currentUserProvider);
    final response = await client.post(
      '/group-messages',
      body: {
        'groupId': groupId,
        'text': text.trim(),
        'senderName': senderName,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
    final created = GroupMessage.fromJson(
      StrapiClient.unwrapMap(response),
      currentUserId: user?.id,
    );
    _ref.invalidate(groupMessagesFamilyProvider(groupId));
    return created;
  }

  Future<GroupActivity> createActivity(GroupActivity activity) async {
    final client = _ref.read(strapiClientProvider);
    final response = await client.post('/group-activities', body: activity.toJson());
    final created = GroupActivity.fromJson(StrapiClient.unwrapMap(response));
    _ref.invalidate(groupActivitiesFamilyProvider(activity.groupId));
    return created;
  }
}

final groupChatServiceProvider = Provider<GroupChatService>(GroupChatService.new);
