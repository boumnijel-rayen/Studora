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
  bool _sending = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_sending) return;
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      AppSnackbar.error(context, 'Session expirée. Veuillez vous reconnecter.');
      return;
    }

    setState(() => _sending = true);
    try {
      await ref.read(groupChatServiceProvider).sendMessage(
        groupId: widget.groupId,
        text: text,
        senderName: user.fullName,
      );
      _textCtrl.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, ApiException.fromError(e).message);
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
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
    final messagesAsync = ref.watch(groupMessagesFamilyProvider(widget.groupId));

    return AppScaffold(
      title: group?.name ?? 'Discussion de groupe',
      subtitle: '${group?.memberNames.length ?? 0} membres',
      actions: [
        IconButton(
          tooltip: 'Actualiser les messages',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(groupMessagesFamilyProvider(widget.groupId)),
        ),
      ],
      body: Column(
        children: [
          // Liste des bulles de messages depuis Strapi
          Expanded(
            child: AppAsyncView<List<GroupMessage>>(
              value: messagesAsync,
              isEmpty: (list) => list.isEmpty,
              empty: const AppEmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Aucun message',
                message: 'Envoyez le premier message pour lancer la discussion du groupe !',
              ),
              onRetry: () => ref.invalidate(groupMessagesFamilyProvider(widget.groupId)),
              data: (messages) => ListView.separated(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: messages.length,
                separatorBuilder: (_, _) => AppSpacing.gapSm,
                itemBuilder: (context, i) => _ChatBubble(message: messages[i]),
              ),
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
                    onPressed: _sending ? null : _sendMessage,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded),
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
