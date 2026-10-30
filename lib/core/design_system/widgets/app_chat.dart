import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../network/api_exception.dart';
import '../../utils/formatters.dart';
import '../theme/app_palette.dart';
import '../tokens/app_dimensions.dart';
import 'app_data_display.dart';
import 'app_inputs.dart';
import 'app_overlays.dart';
import 'app_states.dart';

/// Message affiché par [AppChatView].
@immutable
class AppChatEntry {
  const AppChatEntry({
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isMe,
  });

  factory AppChatEntry.fromJson(Map<String, dynamic> json) => AppChatEntry(
    senderName: (json['senderName'] ?? 'Étudiant').toString(),
    text: (json['text'] ?? '').toString(),
    timestamp: DateTime.tryParse((json['timestamp'] ?? json['createdAt'] ?? '').toString()) ??
        DateTime.now(),
    isMe: json['isMe'] == true,
  );

  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isMe;
}

/// Discussion de groupe : liste de bulles, saisie et actualisation périodique.
class AppChatView extends StatefulWidget {
  const AppChatView({
    super.key,
    required this.messages,
    required this.onSend,
    required this.onRefresh,
    this.emptyMessage = 'Envoyez le premier message pour lancer la discussion !',
    this.refreshInterval = const Duration(seconds: 8),
  });

  final AsyncValue<List<AppChatEntry>> messages;
  final Future<void> Function(String text) onSend;
  final VoidCallback onRefresh;
  final String emptyMessage;
  final Duration refreshInterval;

  @override
  State<AppChatView> createState() => _AppChatViewState();
}

class _AppChatViewState extends State<AppChatView> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _refreshTimer;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(widget.refreshInterval, (_) => widget.onRefresh());
    _scrollToBottom();
  }

  @override
  void didUpdateWidget(AppChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousCount = oldWidget.messages.value?.length ?? 0;
    if ((widget.messages.value?.length ?? 0) != previousCount) {
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await widget.onSend(text);
      _textCtrl.clear();
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
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: AppAsyncView<List<AppChatEntry>>(
          value: widget.messages,
          isEmpty: (list) => list.isEmpty,
          empty: AppEmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Aucun message',
            message: widget.emptyMessage,
          ),
          onRetry: widget.onRefresh,
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
                  onSubmitted: (_) => _send(),
                ),
              ),
              AppSpacing.gapSm,
              IconButton.filled(
                onPressed: _sending ? null : _send,
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
  );
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final AppChatEntry message;

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
                  Formatters.time(message.timestamp.toLocal()),
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
