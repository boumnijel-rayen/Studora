import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../providers/roommates_providers.dart';
import '../services/colocation_message_notifications.dart';

class ColocationChatScreen extends ConsumerStatefulWidget {
  const ColocationChatScreen({super.key});

  @override
  ConsumerState<ColocationChatScreen> createState() => _ColocationChatScreenState();
}

class _ColocationChatScreenState extends ConsumerState<ColocationChatScreen> {
  /// Pas de notification système pour les messages déjà visibles dans cette discussion.
  late final ColocationChatPresence _presence;

  @override
  void initState() {
    super.initState();
    _presence = ref.read(colocationChatPresenceProvider)..isOpen = true;
    // Messages lus : retire la pastille (après la première image, l'état ne pouvant
    // pas être modifié pendant la construction de l'écran).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(colocationUnreadCountProvider.notifier).clear();
    });
  }

  @override
  void dispose() {
    _presence.isOpen = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
