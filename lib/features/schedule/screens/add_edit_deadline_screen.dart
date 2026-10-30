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
  bool _isSaving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final subjects = ref.read(subjectsProvider);
    if (!_formKey.currentState!.validate() || _selectedSubjectId == null) {
      if (_selectedSubjectId == null) {
        AppSnackbar.error(context, 'Veuillez sélectionner ou créer une matière');
      }
      return;
    }

    final subject = subjects.where((s) => s.id == _selectedSubjectId).firstOrNull;
    if (subject == null) return;

    setState(() => _isSaving = true);

    final deadline = Deadline(
      id: '',
      title: _titleCtrl.text.trim(),
      subjectId: subject.id,
      subjectName: subject.name,
      dueDate: _dueDate,
      type: _type,
      priority: _priority,
      description: _descCtrl.text.trim(),
      reminderBeforeMinutes: _reminder,
    );

    try {
      final created = await ref.read(deadlinesAsyncProvider.notifier).add(deadline);

      // Enregistre également la notification de rappel dans Strapi
      try {
        await ref.read(notificationsAsyncProvider.notifier).push(
          title: 'Échéance créée : ${created.title}',
          body: 'À rendre le ${Formatters.shortDate(created.dueDate)} en ${created.subjectName}.',
          category: NotificationCategory.deadline,
        );
      } catch (_) {}

      if (!mounted) return;
      AppSnackbar.success(context, 'Échéance enregistrée avec succès !');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSnackbar.error(context, ApiException.fromError(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider);
    final validSelectedId = subjects.any((s) => s.id == _selectedSubjectId) ? _selectedSubjectId : null;

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
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AppDropdownField<String>(
                      label: 'Matière concernée',
                      value: validSelectedId,
                      hint: subjects.isEmpty ? 'Créez d\'abord une matière →' : 'Sélectionner une matière',
                      items: subjects.map((s) => s.id).toList(),
                      itemLabel: (id) => subjects.firstWhere((s) => s.id == id).name,
                      onChanged: (v) => setState(() => _selectedSubjectId = v),
                    ),
                  ),
                  AppSpacing.gapXs,
                  IconButton.filledTonal(
                    tooltip: 'Nouvelle matière',
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () async {
                      final created = await showCreateSubjectSheet(context, ref);
                      if (created != null && mounted) {
                        setState(() => _selectedSubjectId = created.id);
                      }
                    },
                  ),
                ],
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
                isLoading: _isSaving,
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
