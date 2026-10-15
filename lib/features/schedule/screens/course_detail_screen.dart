import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../providers/schedule_providers.dart';

class CourseDetailScreen extends ConsumerWidget {
  const CourseDetailScreen({super.key, required this.courseId});
  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allCourses = ref.watch(coursesProvider);
    final course = allCourses.where((c) => c.id == courseId).firstOrNull;

    if (course == null) {
      return const AppScaffold(
        title: 'Cours introuvable',
        body: Center(child: Text('Ce cours n\'existe plus.')),
      );
    }

    final color = AppColors.subjectPalette[course.colorIndex % AppColors.subjectPalette.length];

    return AppScaffold(
      title: course.subjectName,
      actions: [
        IconButton(
          tooltip: 'Supprimer',
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
          onPressed: () async {
            final confirm = await AppConfirmDialog.show(
              context,
              title: 'Supprimer ce cours ?',
              message: 'Cette action retirera le créneau de votre emploi du temps.',
              destructive: true,
            );
            if (confirm && context.mounted) {
              ref.read(coursesProvider.notifier).delete(course.id);
              AppSnackbar.info(context, 'Cours supprimé');
              Navigator.pop(context);
            }
          },
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SubjectChip(label: course.subjectName, color: color),
                AppSpacing.gapMd,
                Text(course.subjectName, style: context.text.headlineSmall),
                AppSpacing.gapSm,
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 20),
                    AppSpacing.gapXs,
                    Text(course.timeSlot, style: context.text.bodyLarge),
                  ],
                ),
                AppSpacing.gapSm,
                Row(
                  children: [
                    const Icon(Icons.room_outlined, size: 20),
                    AppSpacing.gapXs,
                    Text('Salle : ${course.room}', style: context.text.bodyLarge),
                  ],
                ),
                AppSpacing.gapSm,
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 20),
                    AppSpacing.gapXs,
                    Text('Enseignant : ${course.teacher}', style: context.text.bodyLarge),
                  ],
                ),
              ],
            ),
          ),
          AppSpacing.gapLg,

          const AppSectionHeader(title: 'Remarques & Consignes'),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              course.notes.isNotEmpty ? course.notes : 'Aucune note pour ce cours.',
              style: context.text.bodyMedium,
            ),
          ),
          AppSpacing.gapLg,

          AppButton(
            label: 'Planifier une révision pour ce cours',
            icon: Icons.timer_outlined,
            variant: AppButtonVariant.tonal,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
