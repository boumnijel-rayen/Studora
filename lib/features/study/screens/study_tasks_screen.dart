import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/study_models.dart';
import '../providers/study_providers.dart';

class StudyTasksScreen extends ConsumerStatefulWidget {
  const StudyTasksScreen({super.key});

  @override
  ConsumerState<StudyTasksScreen> createState() => _StudyTasksScreenState();
}

class _StudyTasksScreenState extends ConsumerState<StudyTasksScreen> {
  bool _sheetOpen = false;

  Future<void> _openAddTaskSheet() async {
    if (_sheetOpen) return;
    _sheetOpen = true;

    final created = await AppBottomSheet.show<StudyTask>(
      context,
      title: 'Nouvelle tâche',
      child: const _AddTaskSheet(),
    );

    _sheetOpen = false;
    if (!mounted || created == null) return;
    AppSnackbar.success(context, 'Tâche « ${created.title} » ajoutée !');
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(studyTasksAsyncProvider);
    final subjectsAsync = ref.watch(subjectsAsyncProvider);

    return AppScaffold(
      title: 'Tâches par matière',
      actions: [
        IconButton(
          tooltip: 'Nouvelle matière',
          icon: const Icon(Icons.library_add_outlined),
          onPressed: () => showCreateSubjectSheet(context, ref),
        ),
        IconButton(
          tooltip: 'Ajouter une tâche',
          icon: const Icon(Icons.add_task_rounded),
          onPressed: _openAddTaskSheet,
        ),
      ],
      body: tasksAsync.when(
        loading: () => const AppSkeletonList(),
        error: (err, _) => AppErrorState.fromError(
          err,
          onRetry: () {
            ref.invalidate(studyTasksAsyncProvider);
            ref.invalidate(subjectsAsyncProvider);
          },
        ),
        data: (tasks) {
          final subjects = subjectsAsync.asData?.value ?? const <Subject>[];
          if (tasks.isEmpty) {
            return AppEmptyState(
              icon: Icons.checklist_rounded,
              title: 'Aucune tâche enregistrée',
              message: subjects.isEmpty
                  ? 'Créez d\'abord vos matières, puis ajoutez vos tâches de révision.'
                  : 'Ajoutez vos premières tâches par matière pour suivre votre avancement.',
              actionLabel: 'Ajouter une tâche',
              onAction: _openAddTaskSheet,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              for (final sub in subjects) ...[
                _SubjectTaskSection(
                  subject: sub,
                  tasks: tasks.where((t) => t.subjectId == sub.id).toList(),
                ),
                AppSpacing.gapMd,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AddTaskSheet extends ConsumerStatefulWidget {
  const _AddTaskSheet();

  @override
  ConsumerState<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<_AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  String? _subjectId;
  DateTime? _dueDate;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final subjects = ref.read(subjectsProvider);
    if (subjects.isNotEmpty) {
      _subjectId = subjects.first.id;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_subjectId == null) {
      setState(() => _error = 'Veuillez choisir ou créer une matière.');
      return;
    }

    final title = _titleCtrl.text.trim();
    final subjectId = _subjectId!;

    final exists = ref
        .read(studyTasksProvider)
        .any((t) => t.subjectId == subjectId && t.title.toLowerCase() == title.toLowerCase());
    if (exists) {
      setState(() => _error = 'Cette tâche existe déjà pour cette matière.');
      return;
    }

    setState(() => _submitting = true);
    final draft = StudyTask(
      id: '',
      subjectId: subjectId,
      title: title,
      dueDate: _dueDate,
    );

    try {
      final created = await ref.read(studyTasksAsyncProvider.notifier).add(draft);
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = ApiException.fromError(e).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider);
    final validSubjectId = subjects.any((s) => s.id == _subjectId) ? _subjectId : null;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppDropdownField<String>(
                  label: 'Matière',
                  value: validSubjectId,
                  hint: subjects.isEmpty ? 'Créez d\'abord une matière →' : 'Choisir une matière',
                  items: subjects.map((s) => s.id).toList(),
                  itemLabel: (id) => subjects.firstWhere((s) => s.id == id).name,
                  onChanged: (v) => setState(() => _subjectId = v),
                  validator: (v) => v == null ? 'Choisis une matière' : null,
                ),
              ),
              AppSpacing.gapXs,
              IconButton.filledTonal(
                tooltip: 'Nouvelle matière',
                icon: const Icon(Icons.add_rounded),
                onPressed: () async {
                  final created = await showCreateSubjectSheet(context, ref);
                  if (created != null && mounted) {
                    setState(() => _subjectId = created.id);
                  }
                },
              ),
            ],
          ),
          AppSpacing.gapMd,
          AppTextField(
            controller: _titleCtrl,
            label: 'Intitulé de la tâche',
            hint: 'ex: Finir le TD 4, faire la fiche de synthèse...',
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Saisis un intitulé' : null,
          ),
          AppSpacing.gapMd,
          AppDateField(
            label: 'Date limite (optionnelle)',
            initialValue: _dueDate,
            onChanged: (d) => setState(() => _dueDate = d),
          ),
          if (_error != null) ...[
            AppSpacing.gapSm,
            Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 18, color: context.colors.error),
                AppSpacing.gapXs,
                Expanded(
                  child: Text(_error!, style: context.text.bodySmall?.copyWith(color: context.colors.error)),
                ),
              ],
            ),
          ],
          AppSpacing.gapLg,
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Annuler',
                  variant: AppButtonVariant.secondary,
                  expand: true,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              AppSpacing.gapSm,
              Expanded(
                flex: 2,
                child: AppButton(
                  label: 'Ajouter la tâche',
                  icon: Icons.add_task_rounded,
                  expand: true,
                  isLoading: _submitting,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubjectTaskSection extends ConsumerWidget {
  const _SubjectTaskSection({required this.subject, required this.tasks});
  final Subject subject;
  final List<StudyTask> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SubjectChip(label: subject.name, color: subject.color),
            const Spacer(),
            Text(
              '${tasks.where((t) => t.isCompleted).length} / ${tasks.length}',
              style: context.text.labelSmall?.copyWith(color: context.colors.textSecondary),
            ),
          ],
        ),
        AppSpacing.gapXs,
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              for (final t in tasks)
                ListTile(
                  leading: Checkbox(
                    value: t.isCompleted,
                    onChanged: (_) async {
                      try {
                        await ref.read(studyTasksAsyncProvider.notifier).toggle(t.id);
                      } catch (e) {
                        if (context.mounted) {
                          AppSnackbar.error(context, ApiException.fromError(e).message);
                        }
                      }
                    },
                  ),
                  title: Text(
                    t.title,
                    style: TextStyle(
                      decoration: t.isCompleted ? TextDecoration.lineThrough : null,
                      color: t.isCompleted ? context.colors.textSecondary : null,
                    ),
                  ),
                  subtitle: t.dueDate != null
                      ? Text('Échéance : ${Formatters.shortDate(t.dueDate!)}', style: context.text.bodySmall)
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    onPressed: () async {
                      try {
                        await ref.read(studyTasksAsyncProvider.notifier).delete(t.id);
                      } catch (e) {
                        if (context.mounted) {
                          AppSnackbar.error(context, ApiException.fromError(e).message);
                        }
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
