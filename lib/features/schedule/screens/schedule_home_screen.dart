import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../models/schedule_models.dart';
import '../providers/schedule_providers.dart';
import '../schedule_routes.dart';

class ScheduleHomeScreen extends ConsumerStatefulWidget {
  const ScheduleHomeScreen({super.key});

  @override
  ConsumerState<ScheduleHomeScreen> createState() => _ScheduleHomeScreenState();
}

class _ScheduleHomeScreenState extends ConsumerState<ScheduleHomeScreen> {
  /// Date sélectionnée dans le calendrier (sans composante horaire).
  DateTime _selectedDate = DateTime.now().dateOnly;

  /// Calendrier déplié / replié.
  bool _calendarExpanded = true;

  /// Incrémenté pour forcer le calendrier à revenir sur le mois de la date
  /// sélectionnée (ex. bouton « Aujourd'hui »), car `CalendarDatePicker`
  /// ne lit `initialDate` qu'à sa création.
  int _calendarResetToken = 0;

  late final DateTime _firstDate = DateTime(DateTime.now().year - 2);
  late final DateTime _lastDate = DateTime(DateTime.now().year + 3, 12, 31);

  void _selectDate(DateTime date) => setState(() => _selectedDate = date.dateOnly);

  void _goToToday() => setState(() {
    _selectedDate = DateTime.now().dateOnly;
    _calendarResetToken++;
  });

  @override
  Widget build(BuildContext context) {
    final allCourses = ref.watch(coursesProvider);
    // Les cours sont hebdomadaires : on filtre selon le jour de la semaine de la date choisie.
    final dayCourses = allCourses.where((c) => c.dayOfWeek == _selectedDate.weekday).toList()
      ..sort((a, b) => (a.startTime.hour * 60 + a.startTime.minute)
          .compareTo(b.startTime.hour * 60 + b.startTime.minute));

    final dayDeadlines = ref
        .watch(deadlinesProvider)
        .where((d) => d.dueDate.isSameDay(_selectedDate))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final upcomingDeadlines = ref.watch(upcomingDeadlinesProvider);
    final isToday = _selectedDate.isSameDay(DateTime.now());

    return AppScaffold(
      title: 'Planning',
      subtitle: 'Emploi du temps & Échéances',
      actions: [
        IconButton(
          tooltip: 'Échéances & Devoirs',
          icon: const Icon(Icons.alarm_rounded),
          onPressed: () => context.push(ScheduleRoutes.deadlines),
        ),
        IconButton(
          tooltip: 'Ajouter un cours',
          icon: const Icon(Icons.add_rounded),
          onPressed: () => context.push(ScheduleRoutes.newCourse),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Sélecteur de date : calendrier interactif
          AppCard(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    AppIconBox(icon: Icons.event_rounded, color: context.colors.primary),
                    AppSpacing.gapSm,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isToday ? 'Aujourd\'hui' : 'Date sélectionnée',
                            style: context.text.labelSmall?.copyWith(color: context.colors.textSecondary),
                          ),
                          Text(
                            '${Formatters.day(_selectedDate)} ${_selectedDate.year}',
                            style: context.text.titleSmall,
                          ),
                        ],
                      ),
                    ),
                    if (!isToday)
                      TextButton(onPressed: _goToToday, child: const Text('Aujourd\'hui')),
                    IconButton(
                      tooltip: _calendarExpanded ? 'Masquer le calendrier' : 'Afficher le calendrier',
                      onPressed: () => setState(() => _calendarExpanded = !_calendarExpanded),
                      icon: AnimatedRotation(
                        turns: _calendarExpanded ? 0.5 : 0,
                        duration: AppDurations.normal,
                        child: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: AppDurations.normal,
                  curve: AppDurations.curve,
                  alignment: Alignment.topCenter,
                  child: _calendarExpanded
                      ? Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: CalendarDatePicker(
                            key: ValueKey(_calendarResetToken),
                            initialDate: _selectedDate,
                            currentDate: DateTime.now(),
                            firstDate: _firstDate,
                            lastDate: _lastDate,
                            onDateChanged: _selectDate,
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
          AppSpacing.gapLg,

          // En-tête de section cours
          AppSectionHeader(
            title: 'Cours du ${Formatters.shortDate(_selectedDate)}',
            actionLabel: 'Ajouter',
            onAction: () => context.push(ScheduleRoutes.newCourse),
          ),

          if (dayCourses.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_available_rounded, size: 48, color: context.colors.textSecondary),
                    AppSpacing.gapMd,
                    Text('Aucun cours prévu ce jour-là', style: context.text.titleSmall),
                    AppSpacing.gapXxs,
                    Text(
                      'Profites-en pour planifier une session de révisions !',
                      style: context.text.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            for (final c in dayCourses) ...[
              _CourseCard(course: c),
              AppSpacing.gapSm,
            ],

          // Échéances tombant exactement à la date sélectionnée
          if (dayDeadlines.isNotEmpty) ...[
            AppSpacing.gapLg,
            AppSectionHeader(title: 'À rendre ce jour (${dayDeadlines.length})'),
            for (final d in dayDeadlines) ...[
              _DeadlineTile(deadline: d),
              AppSpacing.gapSm,
            ],
          ],

          AppSpacing.gapLg,

          // Raccourci Échéances imminentes
          AppSectionHeader(
            title: 'Échéances proches (${upcomingDeadlines.length})',
            actionLabel: 'Voir tout',
            onAction: () => context.push(ScheduleRoutes.deadlines),
          ),

          if (upcomingDeadlines.isEmpty)
            const AppCard(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('Aucun examen ou devoir en attente ! 🎉'),
            )
          else
            for (final d in upcomingDeadlines.take(2)) ...[
              _DeadlineTile(deadline: d),
              AppSpacing.gapSm,
            ],
        ],
      ),
    );
  }
}

/// Carte compacte d'une échéance (examen, devoir, projet) avec case à cocher.
class _DeadlineTile extends ConsumerWidget {
  const _DeadlineTile({required this.deadline});
  final Deadline deadline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = deadline;
    return AppCard(
      onTap: () => context.push(ScheduleRoutes.deadlines),
      child: Row(
        children: [
          AppBadge(
            label: d.type.label,
            tone: d.priority == Priority.high ? AppBadgeTone.error : AppBadgeTone.warning,
            icon: d.type.icon,
          ),
          AppSpacing.gapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.title, style: context.text.titleSmall),
                Text('${d.subjectName} • ${Formatters.shortDate(d.dueDate)}', style: context.text.bodySmall),
              ],
            ),
          ),
          Checkbox(
            value: d.isCompleted,
            onChanged: (_) => ref.read(deadlinesProvider.notifier).toggleCompleted(d.id),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.subjectPalette[course.colorIndex % AppColors.subjectPalette.length];

    return AppCard(
      onTap: () => context.push('/schedule/courses/${course.id}'),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(color: color, borderRadius: AppRadius.brFull),
            ),
            AppSpacing.gapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SubjectChip(label: course.subjectName, color: color),
                      Text(course.timeSlot, style: context.text.labelMedium?.copyWith(color: context.colors.textSecondary)),
                    ],
                  ),
                  AppSpacing.gapSm,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_outlined, size: 16, color: context.colors.textSecondary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(course.room, style: context.text.bodyMedium, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                      AppSpacing.gapSm,
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_outline_rounded, size: 16, color: context.colors.textSecondary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(course.teacher, style: context.text.bodySmall, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                    ],
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
