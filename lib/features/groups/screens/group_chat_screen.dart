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

class _GroupChatScreenState extends ConsumerState<GroupChatScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl = TabController(length: 2, vsync: this);
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedFilter = 'Tous';

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allGroups = ref.watch(groupsProvider);
    final group = allGroups.where((g) => g.id == widget.groupId).firstOrNull;
    final messagesAsync = ref.watch(groupMessagesFamilyProvider(widget.groupId));

    // Extraction des pièces jointes pour l'espace dédié
    final attachmentsList = messagesAsync.whenData(
      (messages) => messages.where((m) => m.hasAttachment).toList(),
    );

    final attachmentCount = attachmentsList.value?.length ?? 0;

    return AppScaffold(
      title: group?.name ?? 'Discussion de groupe',
      subtitle: '${group?.memberNames.length ?? 0} membres',
      actions: [
        IconButton(
          tooltip: 'Actualiser',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(groupMessagesFamilyProvider(widget.groupId)),
        ),
      ],
      bottom: AppTabBar(
        controller: _tabCtrl,
        tabs: [
          'Discussion',
          'Pièces jointes${attachmentCount > 0 ? " ($attachmentCount)" : ""}',
        ],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Onglet 1 : Discussion principale (Chat + Envoi de PJs)
          AppChatView(
            messages: messagesAsync.whenData(
              (messages) => [
                for (final m in messages)
                  AppChatEntry(
                    senderName: m.senderName,
                    text: m.text,
                    timestamp: m.timestamp,
                    isMe: m.isMe,
                    attachmentName: m.attachmentName,
                    attachmentUrl: m.attachmentUrl,
                    attachmentType: m.attachmentType,
                    attachmentSize: m.attachmentSize,
                  ),
              ],
            ),
            emptyMessage:
                'Envoyez le premier message ou document pour lancer la discussion !',
            onRefresh: () =>
                ref.invalidate(groupMessagesFamilyProvider(widget.groupId)),
            onSend: (text,
                {attachmentName,
                attachmentUrl,
                attachmentType,
                attachmentSize}) async {
              final user = ref.read(currentUserProvider);
              await ref.read(groupChatServiceProvider).sendMessage(
                    groupId: widget.groupId,
                    text: text,
                    senderName: user?.fullName ?? '',
                    attachmentName: attachmentName,
                    attachmentUrl: attachmentUrl,
                    attachmentType: attachmentType,
                    attachmentSize: attachmentSize,
                  );
            },
          ),

          // Onglet 2 : Espace dédié uniquement aux pièces jointes du groupe
          _GroupAttachmentsSpace(
            attachmentsAsync: attachmentsList,
            searchCtrl: _searchCtrl,
            selectedFilter: _selectedFilter,
            onFilterChanged: (filter) => setState(() => _selectedFilter = filter),
            onRefresh: () =>
                ref.invalidate(groupMessagesFamilyProvider(widget.groupId)),
          ),
        ],
      ),
    );
  }
}

class _GroupAttachmentsSpace extends StatelessWidget {
  const _GroupAttachmentsSpace({
    required this.attachmentsAsync,
    required this.searchCtrl,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onRefresh,
  });

  final AsyncValue<List<GroupMessage>> attachmentsAsync;
  final TextEditingController searchCtrl;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onRefresh;

  static const _filters = ['Tous', 'PDF', 'Word', 'Images', 'Autres'];

  List<GroupMessage> _filterList(List<GroupMessage> list) {
    final query = searchCtrl.text.trim().toLowerCase();
    return list.where((m) {
      final matchesSearch = query.isEmpty ||
          (m.attachmentName?.toLowerCase().contains(query) ?? false) ||
          m.senderName.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      final ext = m.attachmentExtension;
      switch (selectedFilter) {
        case 'PDF':
          return ext == 'pdf';
        case 'Word':
          return ext == 'doc' || ext == 'docx';
        case 'Images':
          return ['jpg', 'jpeg', 'png', 'gif'].contains(ext);
        case 'Autres':
          return !['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'gif'].contains(ext);
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppAsyncView<List<GroupMessage>>(
      value: attachmentsAsync,
      isEmpty: (list) => list.isEmpty,
      empty: const AppEmptyState(
        icon: Icons.folder_open_rounded,
        title: 'Aucune pièce jointe',
        message:
            'Les documents (PDF, Word, images...) partagés au fil de la discussion apparaîtront dans cet espace.',
      ),
      onRetry: onRefresh,
      data: (allAttachments) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: searchCtrl,
          builder: (context, _, __) {
            final currentFiltered = _filterList(allAttachments);

            return Column(
              children: [
                // Barre de recherche et filtre par type
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      AppTextField(
                        controller: searchCtrl,
                        hint: 'Rechercher un fichier ou un expéditeur...',
                        prefixIcon: Icons.search_rounded,
                        suffix: searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () => searchCtrl.clear(),
                              )
                            : null,
                      ),
                      AppSpacing.gapSm,
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _filters.map((f) {
                            final selected = selectedFilter == f;
                            return Padding(
                              padding:
                                  const EdgeInsets.only(right: AppSpacing.xs),
                              child: ChoiceChip(
                                label: Text(f),
                                selected: selected,
                                onSelected: (_) => onFilterChanged(f),
                                selectedColor: context.colors.primary,
                                labelStyle: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : context.colors.textPrimary,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                // Liste des pièces jointes
                Expanded(
                  child: currentFiltered.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.find_in_page_rounded,
                          title: 'Aucun résultat',
                          message:
                              'Aucun document ne correspond à vos critères de recherche.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          itemCount: currentFiltered.length,
                          separatorBuilder: (_, _) => AppSpacing.gapSm,
                          itemBuilder: (context, i) {
                            final msg = currentFiltered[i];
                            return _AttachmentListItem(message: msg);
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AttachmentListItem extends StatelessWidget {
  const _AttachmentListItem({required this.message});
  final GroupMessage message;

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

  void _openAttachmentOptions(BuildContext context, IconData iconData, Color iconColor) {
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
            'Partagé par ${message.senderName} • ${Formatters.shortDate(message.timestamp)}',
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
  }

  @override
  Widget build(BuildContext context) {
    final ext = message.attachmentExtension;
    final iconData = _getFileIcon(ext);
    final iconColor = _getFileIconColor(ext);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => _openAttachmentOptions(context, iconData, iconColor),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(iconData, size: 32, color: iconColor),
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        message.resolvedAttachmentName.isNotEmpty ? message.resolvedAttachmentName : 'Document sans nom',
                        style: context.text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (ext.isNotEmpty) ...[
                      AppSpacing.gapXs,
                      AppBadge(
                        label: ext.toUpperCase(),
                        tone: _getBadgeTone(ext),
                      ),
                    ],
                  ],
                ),
                AppSpacing.gapXs,
                Row(
                  children: [
                    AppAvatar(name: message.senderName, size: 18),
                    AppSpacing.gapXs,
                    Expanded(
                      child: Text(
                        '${message.senderName} • ${Formatters.shortDate(message.timestamp)}',
                        style: context.text.bodySmall
                            ?.copyWith(color: context.colors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (message.formattedAttachmentSize.isNotEmpty) ...[
                      AppSpacing.gapXs,
                      Text(
                        message.formattedAttachmentSize,
                        style: context.text.labelSmall?.copyWith(
                          color: context.colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          AppSpacing.gapSm,
          IconButton(
            tooltip: 'Options',
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => _openAttachmentOptions(context, iconData, iconColor),
          ),
        ],
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

AppBadgeTone _getBadgeTone(String ext) {
  switch (ext.toLowerCase()) {
    case 'pdf':
      return AppBadgeTone.error;
    case 'doc':
    case 'docx':
      return AppBadgeTone.info;
    case 'xls':
    case 'xlsx':
      return AppBadgeTone.success;
    case 'ppt':
    case 'pptx':
      return AppBadgeTone.warning;
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
      return AppBadgeTone.primary;
    default:
      return AppBadgeTone.neutral;
  }
}
