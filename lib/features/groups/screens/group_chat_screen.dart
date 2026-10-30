import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../providers/groups_providers.dart';

class GroupChatScreen extends ConsumerWidget {
  const GroupChatScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allGroups = ref.watch(groupsProvider);
    final group = allGroups.where((g) => g.id == groupId).firstOrNull;
    final messagesAsync = ref.watch(groupMessagesFamilyProvider(groupId));

    return AppScaffold(
      title: group?.name ?? 'Discussion de groupe',
      subtitle: '${group?.memberNames.length ?? 0} membres',
      actions: [
        IconButton(
          tooltip: 'Actualiser les messages',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(groupMessagesFamilyProvider(groupId)),
        ),
      ],
      body: AppChatView(
        messages: messagesAsync.whenData(
          (messages) => [
            for (final m in messages)
              AppChatEntry(
                senderName: m.senderName,
                text: m.text,
                timestamp: m.timestamp,
                isMe: m.isMe,
              ),
          ],
        ),
        emptyMessage: 'Envoyez le premier message pour lancer la discussion du groupe !',
        onRefresh: () => ref.invalidate(groupMessagesFamilyProvider(groupId)),
        onSend: (text) async {
          final user = ref.read(currentUserProvider);
          await ref.read(groupChatServiceProvider).sendMessage(
            groupId: groupId,
            text: text,
            senderName: user?.fullName ?? '',
          );
        },
      ),
    );
  }
}
