import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/schedule_models.dart';
import '../providers/schedule_providers.dart';

class AddEditDeadlineScreen extends ConsumerStatefulWidget {
  const AddEditDeadlineScreen({super.key});

  @override
  ConsumerState<AddEditDeadlineScreen> createState() => _AddEditDeadlineScreenState();
}

class _AddEditDeadlineScreenState extends ConsumerState<AddEditDeadlineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _selectedSubjectId;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 2));
  DeadlineType _type = DeadlineType.homework;
  Priority _priority = Priority.medium;
  int _reminder = 30;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate() || _selectedSubjectId == null) {
      if (_selectedSubjectId == null) {
        AppSnackbar.error(context, 'Veuillez sélectionner une matière');
      }
      return;
    }

    final subject = MockSharedData.subjects.firstWhere((s) => s.id == _selectedSubjectId);

    final deadline = Deadline(
      id: 'd-${DateTime.now().millisecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      subjectId: subject.id,
      subjectName: subject.name,
      dueDate: _dueDate,
      type: _type,
      priority: _priority,
      description: _descCtrl.text.trim(),
      reminderBeforeMinutes: _reminder,
    );

    ref.read(deadlinesProvider.notifier).add(deadline);

    // Ajoute également une notification dans le centre de notifications
    ref.read(notificationsProvider.notifier).push(
      title: 'Échéance créée : ${deadline.title}',
      body: 'À rendre le ${Formatters.shortDate(deadline.dueDate)} en ${deadline.subjectName}.',
      category: NotificationCategory.deadline,
    );

    AppSnackbar.success(context, 'Échéance enregistrée avec succès !');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const subjects = MockSharedData.subjects;

    return AppScaffold(
      title: 'Nouvelle Échéance',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _titleCtrl,
                label: 'Intitulé de l\'échéance',
                hint: 'ex: Rendu TP noté, Partiel blanc...',
                validator: Validators.required(),
              ),
              AppSpacing.gapMd,
              AppDropdownField<String>(
                label: 'Matière concernée',
                value: _selectedSubjectId,
                hint: 'Sélectionner une matière',
                items: subjects.map((s) => s.id).toList(),
                itemLabel: (id) => subjects.firstWhere((s) => s.id == id).name,
                onChanged: (v) => setState(() => _selectedSubjectId = v),
              ),
              AppSpacing.gapMd,
              AppDateField(
                label: 'Date d\'échéance',
                initialValue: _dueDate,
                onChanged: (d) => setState(() => _dueDate = d),
              ),
              AppSpacing.gapMd,
              const Text('Type d\'échéance', style: TextStyle(fontWeight: FontWeight.w600)),
              AppSpacing.gapXs,
              Row(
                children: [
                  for (final t in DeadlineType.values) ...[
                    ChoiceChip(
                      label: Text(t.label),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                    ),
                    AppSpacing.gapXs,
                  ],
                ],
              ),
              AppSpacing.gapMd,
              const Text('Niveau de priorité', style: TextStyle(fontWeight: FontWeight.w600)),
              AppSpacing.gapXs,
              Row(
                children: [
                  for (final p in Priority.values) ...[
                    ChoiceChip(
                      label: Text(p.label),
                      selected: _priority == p,
                      selectedColor: p.color.withValues(alpha: 0.2),
                      onSelected: (_) => setState(() => _priority = p),
                    ),
                    AppSpacing.gapXs,
                  ],
                ],
              ),
              AppSpacing.gapMd,
              AppDropdownField<int>(
                label: 'Rappel automatique',
                value: _reminder,
                items: const [15, 30, 60, 1440],
                itemLabel: (m) => switch (m) {
                  15 => '15 minutes avant',
                  30 => '30 minutes avant',
                  60 => '1 heure avant',
                  _ => '24 heures avant',
                },
                onChanged: (v) => setState(() => _reminder = v ?? 30),
              ),
              AppSpacing.gapMd,
              AppTextField(
                controller: _descCtrl,
                label: 'Consignes & Précisions',
                hint: 'Barème, chapitres, modalité de rendu...',
                maxLines: 3,
              ),
              AppSpacing.gapXl,
              AppButton(
                label: 'Ajouter au planning',
                icon: Icons.check_rounded,
                expand: true,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
