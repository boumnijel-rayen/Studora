import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/study_models.dart';
import '../providers/study_providers.dart';

class CreateSessionScreen extends ConsumerStatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  ConsumerState<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends ConsumerState<CreateSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  String? _selectedSubjectId;
  String? _selectedTaskId;
  int _durationMinutes = 45;
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final subjects = ref.read(subjectsProvider);
    if (!_formKey.currentState!.validate() || _selectedSubjectId == null) {
      if (_selectedSubjectId == null) {
        AppSnackbar.error(context, 'Veuillez choisir ou créer une matière');
      }
      return;
    }

    final subject = subjects.where((s) => s.id == _selectedSubjectId).firstOrNull;
    if (subject == null) return;

    final tasks = ref.read(studyTasksProvider);
    final linkedTask = tasks.where((t) => t.id == _selectedTaskId).firstOrNull;

    setState(() => _isSaving = true);

    final session = StudySession(
      id: '',
      subjectId: subject.id,
      subjectName: subject.name,
      durationMinutes: _durationMinutes,
      date: _date,
      colorIndex: subject.colorIndex,
      notes: _notesCtrl.text.trim(),
      linkedDeadlineTitle: linkedTask?.title,
      taskId: linkedTask?.id,
    );

    try {
      await ref.read(studySessionsAsyncProvider.notifier).add(session);
      if (!mounted) return;
      AppSnackbar.success(context, 'Session de révision planifiée !');
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
    final validSubjectId = subjects.any((s) => s.id == _selectedSubjectId) ? _selectedSubjectId : null;
    final subjectTasks = ref
        .watch(studyTasksProvider)
        .where((t) => t.subjectId == validSubjectId && !t.isCompleted)
        .toList();
    final validTaskId = subjectTasks.any((t) => t.id == _selectedTaskId) ? _selectedTaskId : null;

    return AppScaffold(
      title: 'Planifier une révision',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AppDropdownField<String>(
                      label: 'Matière à réviser',
                      value: validSubjectId,
                      hint: subjects.isEmpty ? 'Créez d\'abord une matière →' : 'Choisir la matière',
                      items: subjects.map((s) => s.id).toList(),
                      itemLabel: (id) => subjects.firstWhere((s) => s.id == id).name,
                      onChanged: (v) => setState(() {
                        _selectedSubjectId = v;
                        _selectedTaskId = null;
                      }),
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
              if (subjectTasks.isNotEmpty) ...[
                AppSpacing.gapMd,
                AppDropdownField<String?>(
                  label: 'Associer à une tâche (optionnel)',
                  value: validTaskId,
                  items: [null, ...subjectTasks.map((t) => t.id)],
                  itemLabel: (id) => id == null
                      ? 'Aucune tâche spécifique'
                      : subjectTasks.firstWhere((t) => t.id == id).title,
                  onChanged: (v) => setState(() => _selectedTaskId = v),
                ),
              ],
              AppSpacing.gapMd,
              AppDateField(
                label: 'Date de révision',
                initialValue: _date,
                onChanged: (d) => setState(() => _date = d),
              ),
              AppSpacing.gapMd,
              const Text('Durée prévue', style: TextStyle(fontWeight: FontWeight.w600)),
              AppSpacing.gapXs,
              Row(
                children: [
                  for (final m in [25, 45, 60, 90]) ...[
                    ChoiceChip(
                      label: Text('$m min'),
                      selected: _durationMinutes == m,
                      onSelected: (_) => setState(() => _durationMinutes = m),
                    ),
                    AppSpacing.gapXs,
                  ],
                ],
              ),
              AppSpacing.gapMd,
              AppTextField(
                controller: _notesCtrl,
                label: 'Objectif de la session',
                hint: 'ex: Résumer le chapitre 3, faire 3 exercices de TD...',
                maxLines: 3,
                validator: Validators.required('Veuillez définir un objectif'),
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
