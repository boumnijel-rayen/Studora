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
  /// Évite d'empiler plusieurs feuilles si l'utilisateur tape vite sur « + ».
  bool _sheetOpen = false;

  Future<void> _openAddTaskSheet() async {
    if (_sheetOpen) return;
    _sheetOpen = true;

    // La feuille est poussée sur le navigateur RACINE (cf. AppBottomSheet).
    // Elle gère elle-même son état et se ferme via SON propre contexte ;
    // elle renvoie la tâche créée, ou `null` si l'utilisateur l'a fermée.
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
    final tasks = ref.watch(studyTasksProvider);
    const subjects = MockSharedData.subjects;

    return AppScaffold(
      title: 'Tâches par matière',
      actions: [
        IconButton(
          tooltip: 'Ajouter une tâche',
          icon: const Icon(Icons.add_task_rounded),
          onPressed: _openAddTaskSheet,
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          for (final sub in subjects) ...[
            _SubjectTaskSection(subject: sub, tasks: tasks.where((t) => t.subjectId == sub.id).toList()),
            AppSpacing.gapMd,
          ],
        ],
      ),
    );
  }
}

/// Contenu de la feuille « Nouvelle tâche ».
///
/// Widget autonome : il possède son contrôleur et son état, ce qui garantit
/// qu'ils vivent exactement aussi longtemps que la feuille elle-même.
class _AddTaskSheet extends ConsumerStatefulWidget {
  const _AddTaskSheet();

  @override
  ConsumerState<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<_AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  String? _subjectId = MockSharedData.subjects.first.id;
  String? _error;

  /// Empêche une double soumission (et donc un double `pop`).
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitting) return;
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final title = _titleCtrl.text.trim();
    final subjectId = _subjectId!;

    // Règle métier : pas de doublon dans une même matière.
    final exists = ref
        .read(studyTasksProvider)
        .any((t) => t.subjectId == subjectId && t.title.toLowerCase() == title.toLowerCase());
    if (exists) {
      setState(() => _error = 'Cette tâche existe déjà pour cette matière.');
      return;
    }

    _submitting = true;
    final task = StudyTask(
      id: 't-${DateTime.now().microsecondsSinceEpoch}',
      subjectId: subjectId,
      title: title,
    );

    try {
      // Le provider notifie immédiatement l'écran : la liste se met à jour.
      ref.read(studyTasksProvider.notifier).add(task);
    } catch (e) {
      _submitting = false;
      setState(() => _error = 'Impossible d\'ajouter la tâche. Réessaie dans un instant.');
      return;
    }

    // Fermeture via le contexte de la feuille → dépile bien la feuille
    // (navigateur racine), et non la page sous-jacente.
    Navigator.of(context).pop(task);
  }

  @override
  Widget build(BuildContext context) {
    const subjects = MockSharedData.subjects;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDropdownField<String>(
            label: 'Matière',
            value: _subjectId,
            items: subjects.map((s) => s.id).toList(),
            itemLabel: (id) => subjects.firstWhere((s) => s.id == id).name,
            onChanged: (v) => setState(() => _subjectId = v),
            validator: (v) => v == null ? 'Choisis une matière' : null,
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
              for (final t in tasks) ...[
                CheckboxListTile(
                  title: Text(
                    t.title,
                    style: TextStyle(
                      decoration: t.isCompleted ? TextDecoration.lineThrough : null,
                      color: t.isCompleted ? context.colors.textSecondary : null,
                    ),
                  ),
                  value: t.isCompleted,
                  onChanged: (_) => ref.read(studyTasksProvider.notifier).toggle(t.id),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
