import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../network/api_exception.dart';
import '../../utils/bad_words_filter.dart';
import '../../utils/formatters.dart';
import '../theme/app_palette.dart';
import '../tokens/app_dimensions.dart';
import 'app_button.dart';
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
    this.attachmentName,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentSize,
  });

  factory AppChatEntry.fromJson(Map<String, dynamic> json) {
    final rawSize = json['attachmentSize'];
    final int? parsedSize = rawSize is num ? rawSize.toInt() : int.tryParse('$rawSize');
    return AppChatEntry(
      senderName: (json['senderName'] ?? 'Étudiant').toString(),
      text: (json['text'] ?? '').toString(),
      timestamp: DateTime.tryParse((json['timestamp'] ?? json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      isMe: json['isMe'] == true,
      attachmentName: json['attachmentName']?.toString(),
      attachmentUrl: json['attachmentUrl']?.toString(),
      attachmentType: json['attachmentType']?.toString(),
      attachmentSize: parsedSize,
    );
  }

  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isMe;
  final String? attachmentName;
  final String? attachmentUrl;
  final String? attachmentType;
  final int? attachmentSize;

  bool get hasAttachment =>
      (attachmentName != null && attachmentName!.trim().isNotEmpty) ||
      text.startsWith('📄 Document joint :');

  String get resolvedAttachmentName {
    if (attachmentName != null && attachmentName!.trim().isNotEmpty) {
      return attachmentName!.trim();
    }
    if (text.startsWith('📄 Document joint :')) {
      return text.replaceFirst('📄 Document joint : ', '').trim();
    }
    return '';
  }

  String get attachmentExtension {
    if (!hasAttachment) return '';
    final name = resolvedAttachmentName;
    final dot = name.lastIndexOf('.');
    if (dot != -1 && dot < name.length - 1) {
      return name.substring(dot + 1).toLowerCase();
    }
    return 'pdf';
  }

  String get formattedAttachmentSize {
    if (attachmentSize == null || attachmentSize! <= 0) return '';
    final bytes = attachmentSize!;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Discussion de groupe : liste de bulles, saisie, pièce jointe et actualisation.
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
  final Future<void> Function(
    String text, {
    String? attachmentName,
    String? attachmentUrl,
    String? attachmentType,
    int? attachmentSize,
  }) onSend;
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

  String? _selectedFileName;
  String? _selectedFilePath;
  String? _selectedFileType;
  int? _selectedFileSize;

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

  Future<void> _pickAttachment() async {
    await AppBottomSheet.show<void>(
      context,
      title: 'Joindre un document',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(Icons.folder_open_rounded, color: context.colors.primary),
            ),
            title: Text('Parcourir les fichiers de l\'appareil', style: context.text.titleSmall),
            subtitle: Text('Sélectionner un fichier (PDF, Word, etc.)', style: context.text.bodySmall),
            onTap: () async {
              Navigator.of(context).pop();
              await _pickFromDevice();
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Text(
              'DOCUMENTS D\'EXEMPLE DISPONIBLES :',
              style: context.text.labelSmall?.copyWith(color: context.colors.textSecondary),
            ),
          ),
          ListTile(
            leading: Icon(Icons.picture_as_pdf_rounded, color: Colors.red.shade700),
            title: const Text('Devoir_Maths_Algebres.pdf'),
            subtitle: const Text('Document PDF • 145.0 KB'),
            onTap: () {
              Navigator.of(context).pop();
              _selectSampleFile('Devoir_Maths_Algebres.pdf', 'pdf', 148480);
            },
          ),
          ListTile(
            leading: Icon(Icons.description_rounded, color: Colors.blue.shade700),
            title: const Text('Rapport_Projet_Studora.docx'),
            subtitle: const Text('Document Word • 88.5 KB'),
            onTap: () {
              Navigator.of(context).pop();
              _selectSampleFile('Rapport_Projet_Studora.docx', 'docx', 90624);
            },
          ),
          ListTile(
            leading: Icon(Icons.insert_drive_file_rounded, color: Colors.teal.shade700),
            title: const Text('Notes_Revision_Physique.txt'),
            subtitle: const Text('Fichier texte • 32.0 KB'),
            onTap: () {
              Navigator.of(context).pop();
              _selectSampleFile('Notes_Revision_Physique.txt', 'txt', 32768);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromDevice() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'ppt', 'pptx', 'xls', 'xlsx', 'png', 'jpg', 'jpeg'],
      );
      if (files.isNotEmpty) {
        final file = files.first;
        final fileSize = file.lengthSync() ?? await file.length() ?? 0;
        setState(() {
          _selectedFileName = file.name;
          _selectedFileSize = fileSize;
          _selectedFilePath = file.path;
          _selectedFileType = file.extension;
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Impossible de sélectionner le fichier : $e');
      }
    }
  }

  void _selectSampleFile(String name, String ext, int size) {
    setState(() {
      _selectedFileName = name;
      _selectedFileSize = size;
      _selectedFilePath = '/sdcard/Download/$name';
      _selectedFileType = ext;
    });
  }

  void _clearSelectedAttachment() {
    setState(() {
      _selectedFileName = null;
      _selectedFilePath = null;
      _selectedFileType = null;
      _selectedFileSize = null;
    });
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _textCtrl.text.trim();
    final hasAttachment = _selectedFileName != null && _selectedFileName!.isNotEmpty;

    if (text.isEmpty && !hasAttachment) return;

    if (BadWordsFilter.containsBadWords(text)) {
      AppSnackbar.error(context, 'Votre message contient des termes inappropriés et a été bloqué par la modération.');
      return;
    }

    setState(() => _sending = true);
    try {
      await widget.onSend(
        text,
        attachmentName: _selectedFileName,
        attachmentUrl: _selectedFilePath,
        attachmentType: _selectedFileType,
        attachmentSize: _selectedFileSize,
      );
      _textCtrl.clear();
      _clearSelectedAttachment();
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

      // Zone de saisie + pièce jointe en attente
      Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.border)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedFileName != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: context.colors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(_getFileIcon(_selectedFileType ?? ''), size: 20, color: context.colors.primary),
                      AppSpacing.gapSm,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFileName!,
                              style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_selectedFileSize != null && _selectedFileSize! > 0)
                              Text(
                                _formatBytes(_selectedFileSize!),
                                style: context.text.labelSmall?.copyWith(fontSize: 11, color: context.colors.textSecondary),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: _clearSelectedAttachment,
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                children: [
                  IconButton(
                    tooltip: 'Joindre un document (PDF, Word, etc.)',
                    icon: const Icon(Icons.attach_file_rounded),
                    color: context.colors.primary,
                    onPressed: _sending ? null : _pickAttachment,
                  ),
                  AppSpacing.gapXs,
                  Expanded(
                    child: AppTextField(
                      controller: _textCtrl,
                      hint: _selectedFileName != null
                          ? 'Ajouter une légende (optionnel)...'
                          : 'Écrire un message...',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.hasAttachment) ...[
                      _ChatAttachmentCard(message: message, isMe: isMe),
                      if (message.text.isNotEmpty && !message.text.startsWith('📄 Document joint'))
                        AppSpacing.gapXs,
                    ],
                    if (message.text.isNotEmpty && (!message.hasAttachment || !message.text.startsWith('📄 Document joint')))
                      Text(
                        message.text,
                        style: context.text.bodyMedium?.copyWith(
                          color: isMe ? Colors.white : context.colors.textPrimary,
                        ),
                      ),
                  ],
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

class _ChatAttachmentCard extends StatelessWidget {
  const _ChatAttachmentCard({required this.message, required this.isMe});
  final AppChatEntry message;
  final bool isMe;

  void _showDocumentViewer(BuildContext context, IconData iconData, Color iconColor) {
    Navigator.of(context).pop(); // Close bottom sheet
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(iconData, color: iconColor, size: 28),
            AppSpacing.gapSm,
            Expanded(
              child: Text(
                message.resolvedAttachmentName.isNotEmpty ? message.resolvedAttachmentName : 'Document',
                style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Aperçu du document', style: context.text.labelMedium?.copyWith(color: context.colors.textSecondary)),
                          if (message.formattedAttachmentSize.isNotEmpty)
                            Text(message.formattedAttachmentSize, style: context.text.labelSmall?.copyWith(color: context.colors.textSecondary)),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        message.attachmentExtension == 'pdf'
                            ? '📄 [Aperçu PDF - Consultable]\n\nChapitre 1 : Algèbre Linéaire et Espaces Vectoriels\n\n1. Définition d’un espace vectoriel sur un corps K.\n2. Sous-espaces vectoriels, familles génératrices, bases.\n3. Applications linéaires et matrices associées.\n\n(Document consultable et valide - Studora)'
                            : message.attachmentExtension == 'docx'
                                ? '📝 [Aperçu Document Word - Consultable]\n\nRapport Projet Studora - Analyse et Conception\n\n- Introduction au module Groupe d’Étude et Colocation.\n- Architecture technique (Strapi 5 & Flutter).\n- Validation des flux de données et collaboration en temps réel.\n\n(Document consultable et valide - Studora)'
                                : '📄 [Contenu du document]\n\n${message.resolvedAttachmentName}\n\nEnvoyé par ${message.senderName}\nDate : ${Formatters.shortDate(message.timestamp)}\n\n(Document consultable - Studora)',
                        style: context.text.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          AppButton(
            label: 'Fermer',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
          AppButton(
            label: 'Télécharger',
            icon: Icons.download_rounded,
            onPressed: () {
              Navigator.of(context).pop();
              AppSnackbar.success(context, 'Document ${message.resolvedAttachmentName} téléchargé avec succès !');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = message.attachmentExtension;
    final iconData = _getFileIcon(ext);
    final iconColor = _getFileIconColor(ext);

    return InkWell(
      onTap: () {
        AppBottomSheet.show<void>(
          context,
          title: 'Pièce jointe',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, size: 48, color: iconColor),
                ),
              ),
              AppSpacing.gapMd,
              Text(
                message.resolvedAttachmentName.isNotEmpty ? message.resolvedAttachmentName : 'Document sans nom',
                style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapXs,
              Text(
                'Envoyé par ${message.senderName} • ${Formatters.shortDate(message.timestamp)}',
                style: context.text.bodySmall?.copyWith(color: context.colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              if (message.formattedAttachmentSize.isNotEmpty) ...[
                AppSpacing.gapXs,
                Text(
                  'Taille : ${message.formattedAttachmentSize}',
                  style: context.text.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
              AppSpacing.gapLg,
              AppButton(
                label: 'Consulter le document',
                icon: Icons.visibility_rounded,
                expand: true,
                onPressed: () {
                  _showDocumentViewer(context, iconData, iconColor);
                },
              ),
              AppSpacing.gapSm,
              AppButton(
                label: 'Télécharger le document',
                icon: Icons.download_rounded,
                variant: AppButtonVariant.secondary,
                expand: true,
                onPressed: () {
                  Navigator.of(context).pop();
                  AppSnackbar.success(context, 'Document ${message.resolvedAttachmentName} téléchargé avec succès !');
                },
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: 0.2) : context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isMe ? Colors.white.withValues(alpha: 0.3) : context.colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isMe ? Colors.white.withValues(alpha: 0.25) : iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(iconData, size: 24, color: isMe ? Colors.white : iconColor),
            ),
            AppSpacing.gapSm,
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.resolvedAttachmentName.isNotEmpty ? message.resolvedAttachmentName : 'Document',
                    style: context.text.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isMe ? Colors.white : context.colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (message.formattedAttachmentSize.isNotEmpty)
                    Text(
                      message.formattedAttachmentSize,
                      style: context.text.labelSmall?.copyWith(
                        fontSize: 10,
                        color: isMe ? Colors.white.withValues(alpha: 0.8) : context.colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            AppSpacing.gapXs,
            Icon(
              Icons.download_for_offline_rounded,
              size: 20,
              color: isMe ? Colors.white : context.colors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

IconData _getFileIcon(String ext) {
  switch (ext.toLowerCase()) {
    case 'pdf':
      return Icons.picture_as_pdf_rounded;
    case 'doc':
    case 'docx':
      return Icons.description_rounded;
    case 'xls':
    case 'xlsx':
      return Icons.table_chart_rounded;
    case 'ppt':
    case 'pptx':
      return Icons.slideshow_rounded;
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
      return Icons.image_rounded;
    default:
      return Icons.insert_drive_file_rounded;
  }
}

Color _getFileIconColor(String ext) {
  switch (ext.toLowerCase()) {
    case 'pdf':
      return Colors.red.shade700;
    case 'doc':
    case 'docx':
      return Colors.blue.shade700;
    case 'xls':
    case 'xlsx':
      return Colors.green.shade700;
    case 'ppt':
    case 'pptx':
      return Colors.orange.shade700;
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
      return Colors.purple.shade600;
    default:
      return Colors.teal.shade700;
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
