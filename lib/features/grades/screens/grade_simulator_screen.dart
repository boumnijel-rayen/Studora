import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../providers/grades_providers.dart';

class GradeSimulatorScreen extends ConsumerStatefulWidget {
  const GradeSimulatorScreen({super.key});

  @override
  ConsumerState<GradeSimulatorScreen> createState() => _GradeSimulatorScreenState();
}

class _GradeSimulatorScreenState extends ConsumerState<GradeSimulatorScreen> {
  String? _selectedSubjectId;
  double _targetAverage = 14.0;
  double _examCoefficient = 2.0;

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider);
    final activeSubjectId = subjects.any((s) => s.id == _selectedSubjectId)
        ? _selectedSubjectId
        : (subjects.isNotEmpty ? subjects.first.id : null);

    final allGrades = ref.watch(gradesProvider);
    final grades = allGrades.where((g) => g.subjectId == activeSubjectId).toList();

    double currentPoints = 0;
    double currentCoeffs = 0;
    for (final g in grades) {
      currentPoints += g.value * g.coefficient;
      currentCoeffs += g.coefficient;
    }

    final double currentAvg = currentCoeffs > 0 ? (currentPoints / currentCoeffs) : 0.0;

    final double neededGrade = _examCoefficient > 0
        ? (_targetAverage * (currentCoeffs + _examCoefficient) - currentPoints) / _examCoefficient
        : 0.0;

    final isFeasible = neededGrade <= 20.0 && neededGrade >= 0.0;

    return AppScaffold(
      title: 'Simulateur d\'examen',
      subtitle: 'Calculer la note requise pour valider',
      body: subjects.isEmpty
          ? AppEmptyState(
              icon: Icons.calculate_outlined,
              title: 'Aucune matière disponible',
              message: 'Ajoutez d\'abord une matière pour simuler vos objectifs d\'examen.',
              actionLabel: 'Créer une matière',
              onAction: () => showCreateSubjectSheet(context, ref),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppDropdownField<String>(
                    label: 'Matière à simuler',
                    value: activeSubjectId,
                    items: subjects.map((s) => s.id).toList(),
                    itemLabel: (id) => subjects.firstWhere((s) => s.id == id).name,
                    onChanged: (v) => setState(() => _selectedSubjectId = v),
                  ),
                  AppSpacing.gapLg,

                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        Text('Note nécessaire au prochain partiel', style: context.text.titleSmall),
                        AppSpacing.gapMd,
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: isFeasible
                                ? context.colors.primary.withValues(alpha: 0.15)
                                : context.colors.error.withValues(alpha: 0.15),
                            borderRadius: AppRadius.brXl,
                          ),
                          child: Text(
                            neededGrade < 0
                                ? '0.0 / 20'
                                : (neededGrade > 20
                                      ? '> 20 (Infaisable)'
                                      : '${neededGrade.toStringAsFixed(2)} / 20'),
                            style: context.text.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isFeasible ? context.colors.primary : context.colors.error,
                            ),
                          ),
                        ),
                        AppSpacing.gapSm,
                        Text(
                          isFeasible
                              ? 'Pour atteindre votre objectif de ${_targetAverage.toStringAsFixed(1)} / 20'
                              : 'Objectif trop élevé pour le coefficient spécifié',
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapLg,

                  const AppSectionHeader(title: 'Paramètres de la simulation'),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Moyenne cible souhaitée', style: context.text.bodyLarge),
                            Text('${_targetAverage.toStringAsFixed(1)} / 20', style: context.text.titleSmall),
                          ],
                        ),
                        Slider(
                          value: _targetAverage,
                          min: 10.0,
                          max: 20.0,
                          divisions: 20,
                          onChanged: (v) => setState(() => _targetAverage = v),
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Coefficient du futur examen', style: context.text.bodyLarge),
                            Text('Coeff. ${_examCoefficient.toStringAsFixed(1)}', style: context.text.titleSmall),
                          ],
                        ),
                        Slider(
                          value: _examCoefficient,
                          min: 0.5,
                          max: 4.0,
                          divisions: 7,
                          onChanged: (v) => setState(() => _examCoefficient = v),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapLg,

                  AppCard(
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.info),
                        AppSpacing.gapSm,
                        Expanded(
                          child: Text(
                            'Moyenne actuelle dans cette matière : ${currentAvg.toStringAsFixed(2)}/20 ($currentCoeffs coefficients cumulés)',
                            style: context.text.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
