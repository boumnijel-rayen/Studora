import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../models/roommate_models.dart';

/// Choix d'un colocataire en un appui, parmi les membres actuels (avatar + prénom).
class RoommatePicker extends StatelessWidget {
  const RoommatePicker({
    super.key,
    required this.members,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Roommate> members;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Text('Aucun colocataire pour le moment.', style: context.text.bodySmall);
    }
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final m in members)
          ChoiceChip(
            avatar: AppAvatar(name: m.name, size: 24),
            label: Text(m.isMe ? '${_firstName(m.name)} (vous)' : _firstName(m.name)),
            tooltip: m.name,
            selected: m.id == selectedId,
            onSelected: (_) => onSelected(m.id),
          ),
      ],
    );
  }

  static String _firstName(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? name : trimmed.split(RegExp(r'\s+')).first;
  }
}

/// Feuille de choix d'un colocataire (réassignation d'une tâche).
/// Renvoie l'identifiant choisi, ou `null` si la feuille est fermée sans choix.
Future<String?> showRoommatePickerSheet(
  BuildContext context, {
  required List<Roommate> members,
  required String? selectedId,
  String title = 'Assigner à',
}) {
  return AppBottomSheet.show<String>(
    context,
    title: title,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final m in members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: AppAvatar(name: m.name, size: 36, showOnline: m.isPresent),
            title: Text(m.isMe ? '${m.name} (vous)' : m.name),
            subtitle: Text(m.roomNumber),
            trailing: m.id == selectedId
                ? Icon(Icons.check_circle_rounded, color: context.colors.primary)
                : null,
            onTap: () => Navigator.of(context, rootNavigator: true).pop(m.id),
          ),
      ],
    ),
  );
}
