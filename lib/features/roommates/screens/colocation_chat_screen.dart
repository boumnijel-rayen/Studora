import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../providers/roommates_providers.dart';

class ColocationChatScreen extends ConsumerWidget {
  const ColocationChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colocation = ref.watch(colocationProvider);
    final memberCount = ref.watch(roommatesProvider).length;

    return AppScaffold(
      title: colocation?.name ?? 'Discussion',
      subtitle: '$memberCount membre${memberCount > 1 ? 's' : ''}',
      actions: [
        IconButton(
          tooltip: 'Actualiser les messages',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(colocationMessagesProvider),
        ),
      ],
      body: AppChatView(
        messages: ref.watch(colocationMessagesProvider),
        emptyMessage: 'Envoyez le premier message à vos colocataires !',
        onRefresh: () => ref.invalidate(colocationMessagesProvider),
        onSend: (text) => ref.read(colocationChatServiceProvider).sendMessage(text),
      ),
    );
  }
}
