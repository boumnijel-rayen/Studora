import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/grade_models.dart';
import '../providers/grades_providers.dart';

class AcademicGoalsScreen extends ConsumerStatefulWidget {
  const AcademicGoalsScreen({super.key});

  @override
  ConsumerState<AcademicGoalsScreen> createState() => _AcademicGoalsScreenState();
}

class _AcademicGoalsScreenState extends ConsumerState<AcademicGoalsScreen> {
  final _titleCtrl = TextEditingController();
  final _targetCtrl = TextEditingController(text: '14.0');
  String? _selectedSubjectId;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _addGoal(BuildContext sheetContext) async {
    final title = _titleCtrl.text.trim();
    final target = double.tryParse(_targetCtrl.text.replaceAll(',', '.')) ?? 14.0;
    if (title.isEmpty) return;

    final subjects = ref.read(subjectsProvider);
    final subName = _selectedSubjectId == null
        ? 'Moyenne Générale'
        : (subjects.where((s) => s.id == _selectedSubjectId).firstOrNull?.name ?? 'Matière');

    final goal = AcademicGoal(
      id: '',
      title: title,
      targetAverage: target,
      subjectName: subName,
      subjectId: _selectedSubjectId,
    );

    try {
      await ref.read(academicGoalsAsyncProvider.notifier).add(goal);
      _titleCtrl.clear();
      if (sheetContext.mounted) {
        Navigator.pop(sheetContext);
      }
      if (mounted) {
        AppSnackbar.success(context, 'Objectif académique défini !');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, ApiException.fromError(e).message);
      }
    }
  }

  void _openCreateGoalSheet() {
    final subjects = ref.read(subjectsProvider);
    AppBottomSheet.show(
      context,
      title: 'Définir un objectif',
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Column(
          children: [
            AppTextField(
              controller: _titleCtrl,
              label: 'Titre de l\'objectif',
              hint: 'ex: Obtenir la mention Bien',
            ),
            AppSpacing.gapMd,
            AppDropdownField<String?>(
              label: 'Matière ou Général',
              value: subjects.any((s) => s.id == _selectedSubjectId) ? _selectedSubjectId : null,
              items: [null, ...subjects.map((s) => s.id)],
              itemLabel: (id) => id == null
                  ? 'Moyenne générale'
                  : subjects.firstWhere((s) => s.id == id).name,
              onChanged: (v) => setSheetState(() => _selectedSubjectId = v),
            ),
            AppSpacing.gapMd,
            AppTextField(
              controller: _targetCtrl,
              label: 'Moyenne cible (sur 20)',
              hint: 'ex: 15.0',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            AppSpacing.gapLg,
            AppButton(
              label: 'Enregistrer l\'objectif',
              expand: true,
              onPressed: () => _addGoal(sheetCtx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(academicGoalsAsyncProvider);
    final overallAvg = ref.watch(overallAverageProvider);
    final subAvgs = ref.watch(subjectAveragesProvider);

    return AppScaffold(
      title: 'Objectifs académiques',
      actions: [
        IconButton(
          tooltip: 'Nouvel objectif',
          icon: const Icon(Icons.add_rounded),
          onPressed: _openCreateGoalSheet,
        ),
      ],
      body: AppAsyncView<List<AcademicGoal>>(
        value: goalsAsync,
        isEmpty: (list) => list.isEmpty,
        empty: AppEmptyState(
          icon: Icons.flag_outlined,
          title: 'Aucun objectif défini',
          message: 'Fixez-vous un objectif de moyenne générale ou par matière pour suivre votre progression.',
          actionLabel: 'Définir un objectif',
          onAction: _openCreateGoalSheet,
        ),
        onRetry: () => ref.invalidate(academicGoalsAsyncProvider),
        data: (goals) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            for (final g in goals) ...[
              _GoalCard(
                goal: g,
                currentValue: g.subjectId == null ? overallAvg : (subAvgs[g.subjectId] ?? 0.0),
                onDelete: () async {
                  try {
                    await ref.read(academicGoalsAsyncProvider.notifier).delete(g.id);
                  } catch (e) {
                    if (context.mounted) {
                      AppSnackbar.error(context, ApiException.fromError(e).message);
                    }
                  }
                },
              ),
              AppSpacing.gapSm,
            ],
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.currentValue,
    required this.onDelete,
  });

  final AcademicGoal goal;
  final double currentValue;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final progress = goal.targetAverage > 0
        ? (currentValue / goal.targetAverage).clamp(0.0, 1.0)
        : 0.0;
    final reached = currentValue >= goal.targetAverage;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBox(
                icon: reached ? Icons.emoji_events_rounded : Icons.flag_rounded,
                color: reached ? AppColors.tertiary : AppColors.primary,
              ),
              AppSpacing.gapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.title, style: context.text.titleSmall),
                    Text(goal.subjectName, style: context.text.bodySmall),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
          AppSpacing.gapMd,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Actuel : ${currentValue.toStringAsFixed(1)} / 20',
                style: context.text.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: reached ? context.colors.success : context.colors.textSecondary,
                ),
              ),
              Text(
                'Cible : ${goal.targetAverage.toStringAsFixed(1)} / 20',
                style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          AppSpacing.gapXs,
          AppProgressBar(
            value: progress,
            color: reached ? context.colors.success : context.colors.primary,
            height: 10,
          ),
          AppSpacing.gapXxs,
          Text(
            reached
                ? 'Objectif atteint ! Félicitations 🎉'
                : 'Il vous reste ${(goal.targetAverage - currentValue).toStringAsFixed(1)} pts à rattraper',
            style: context.text.labelSmall?.copyWith(
              color: reached ? context.colors.success : context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
