import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/group_models.dart';
import '../providers/groups_providers.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({super.key, required this.groupId});
  final String groupId;

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider) ?? MockSharedData.demoUser;
    ref.read(groupMessagesProvider.notifier).sendMessage(widget.groupId, text, user.fullName);
    _textCtrl.clear();

    _scrollToBottom();

    // Simulation d'une réponse dynamique d'un camarade de promo après 1.2s
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      ref.read(groupMessagesProvider.notifier).addIncomingMessage(
        widget.groupId,
        'Alice Dubois',
        'Top, bien noté ! J\'amènerai aussi les exercices corrigés de l\'an dernier.',
      );
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allGroups = ref.watch(groupsProvider);
    final group = allGroups.where((g) => g.id == widget.groupId).firstOrNull;
    final messagesMap = ref.watch(groupMessagesProvider);
    final messages = messagesMap[widget.groupId] ?? [];

    return AppScaffold(
      title: group?.name ?? 'Discussion de groupe',
      subtitle: '${group?.memberNames.length ?? 0} membres',
      body: Column(
        children: [
          // Liste des bulles de messages
          Expanded(
            child: ListView.separated(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: messages.length,
              separatorBuilder: (_, _) => AppSpacing.gapSm,
              itemBuilder: (context, i) {
                final m = messages[i];
                return _ChatBubble(message: m);
              },
            ),
          ),

          // Barre de saisie
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border(top: BorderSide(color: context.colors.border)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _textCtrl,
                      hint: 'Écrire un message...',
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  AppSpacing.gapSm,
                  IconButton.filled(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final GroupMessage message;

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;

    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMe) ...[
          AppAvatar(name: message.senderName, size: 30),
          AppSpacing.gapXs,
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    message.senderName,
                    style: context.text.labelSmall?.copyWith(color: context.colors.textSecondary),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isMe ? context.colors.primary : context.colors.surfaceVariant,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(AppRadius.md),
                    topRight: const Radius.circular(AppRadius.md),
                    bottomLeft: Radius.circular(isMe ? AppRadius.md : 2),
                    bottomRight: Radius.circular(isMe ? 2 : AppRadius.md),
                  ),
                ),
                child: Text(
                  message.text,
                  style: context.text.bodyMedium?.copyWith(
                    color: isMe ? Colors.white : context.colors.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                child: Text(
                  Formatters.time(message.timestamp),
                  style: context.text.labelSmall?.copyWith(fontSize: 10, color: context.colors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
