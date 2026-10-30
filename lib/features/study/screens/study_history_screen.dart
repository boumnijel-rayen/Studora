import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/study_models.dart';
import '../providers/study_providers.dart';

class StudyHistoryScreen extends ConsumerWidget {
  const StudyHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(studySessionsAsyncProvider);

    return AppScaffold(
      title: 'Historique & Statistiques',
      subtitle: 'Analyse du temps de travail',
      body: AppAsyncView<List<StudySession>>(
        value: sessionsAsync,
        onRetry: () => ref.invalidate(studySessionsAsyncProvider),
        data: (sessions) {
          final completed = sessions.where((s) => s.isCompleted).toList();
          final totalMin = completed.fold<int>(0, (acc, s) => acc + s.durationMinutes);

          // Calcul des heures par jour de la semaine en cours (Lun = 0 ... Dim = 6)
          final weekStart = DateTime.now().startOfWeek;
          final hoursPerWeekday = List<double>.filled(7, 0.0);
          for (final s in completed) {
            final diff = s.date.dateOnly.difference(weekStart).inDays;
            if (diff >= 0 && diff < 7) {
              hoursPerWeekday[diff] += s.durationMinutes / 60.0;
            }
          }
          final weekTotalHours = hoursPerWeekday.fold<double>(0, (a, b) => a + b);
          final dailyAvgHours = weekTotalHours / 7.0;
          final maxBarY = max(4.0, (hoursPerWeekday.reduce(max) + 1.0).ceilToDouble());

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppStatCard(
                      label: 'Temps total cumulé',
                      value: '${(totalMin / 60).toStringAsFixed(1)} h',
                      icon: Icons.timer_outlined,
                      color: AppColors.moduleStudy,
                    ),
                  ),
                  AppSpacing.gapSm,
                  Expanded(
                    child: AppStatCard(
                      label: 'Moyenne / jour',
                      value: '${dailyAvgHours.toStringAsFixed(1)} h',
                      icon: Icons.trending_up_rounded,
                      color: AppColors.tertiary,
                    ),
                  ),
                ],
              ),
              AppSpacing.gapLg,

              const AppSectionHeader(title: 'Temps de travail de la semaine (heures)'),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxBarY,
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: const FlTitlesData(
                        show: true,
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: _getDayTitle,
                          ),
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(
                        7,
                        (i) => _barGroup(
                          i,
                          hoursPerWeekday[i],
                          i < 5 ? context.colors.primary : context.colors.tertiary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              AppSpacing.gapLg,

              const AppSectionHeader(title: 'Dernières sessions réalisées'),
              if (completed.isEmpty)
                const AppCard(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text('Aucune session terminée pour le moment.'),
                )
              else
                for (final s in completed) ...[
                  AppCard(
                    child: Row(
                      children: [
                        AppIconBox(
                          icon: Icons.check_circle_rounded,
                          color: AppColors.subjectPalette[s.colorIndex % AppColors.subjectPalette.length],
                        ),
                        AppSpacing.gapSm,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.subjectName, style: context.text.titleSmall),
                              Text(
                                '${s.durationMinutes} min • ${Formatters.shortDate(s.date)}',
                                style: context.text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        AppBadge(label: '${s.durationMinutes} min', tone: AppBadgeTone.success),
                      ],
                    ),
                  ),
                  AppSpacing.gapSm,
                ],
            ],
          );
        },
      ),
    );
  }

  static Widget _getDayTitle(double val, TitleMeta meta) {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final i = val.toInt();
    if (i >= 0 && i < days.length) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(days[i], style: const TextStyle(fontSize: 12)),
      );
    }
    return const SizedBox.shrink();
  }

  BarChartGroupData _barGroup(int x, double y, Color color) => BarChartGroupData(
    x: x,
    barRods: [
      BarChartRodData(
        toY: y,
        color: color,
        width: 18,
        borderRadius: AppRadius.brSm,
      ),
    ],
  );
}
