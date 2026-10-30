import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../../grades/providers/grades_providers.dart';
import '../auth_routes.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final subjectsAsync = ref.watch(subjectsAsyncProvider);
    final overallAvg = ref.watch(overallAverageProvider);
    final grades = ref.watch(gradesProvider);

    if (user == null) {
      return AppScaffold(
        title: 'Mon Profil',
        body: AppErrorState(
          title: 'Session expirée',
          message: 'Veuillez vous connecter pour consulter votre profil.',
          onRetry: () => context.go(AuthRoutes.login),
        ),
      );
    }

    final subjectsCount = subjectsAsync.asData?.value.length ?? 0;

    return AppScaffold(
      title: 'Mon Profil',
      actions: [
        IconButton(
          tooltip: 'Modifier',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => context.push(AuthRoutes.editProfile),
        ),
        IconButton(
          tooltip: 'Préférences',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push(AuthRoutes.settings),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // En-tête profil
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                AppAvatar(name: user.fullName, size: AppSizes.avatarXl, showOnline: true),
                AppSpacing.gapMd,
                Text(user.fullName, style: context.text.headlineSmall),
                AppSpacing.gapXxs,
                SubjectChip(
                  label: user.university.isNotEmpty
                      ? '${user.university} • Année ${user.year}'
                      : 'Année ${user.year}',
                  color: context.colors.primary,
                ),
                if (user.bio.isNotEmpty) ...[
                  AppSpacing.gapSm,
                  Text(
                    user.bio,
                    style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          AppSpacing.gapLg,

          // Coordonnées et cursus
          const AppSectionHeader(title: 'Coordonnées & Cursus'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                AppListTile(
                  title: 'E-mail universitaire',
                  subtitle: user.email,
                  leading: const Icon(Icons.email_outlined),
                ),
                const Divider(),
                AppListTile(
                  title: 'Téléphone',
                  subtitle: user.phone.isNotEmpty ? user.phone : 'Non renseigné',
                  leading: const Icon(Icons.phone_outlined),
                ),
                const Divider(),
                AppListTile(
                  title: 'Filière / Spécialité',
                  subtitle: user.program.isNotEmpty ? user.program : 'Non renseignée',
                  leading: const Icon(Icons.school_outlined),
                ),
                const Divider(),
                AppListTile(
                  title: 'Établissement',
                  subtitle: user.university.isNotEmpty ? user.university : 'Non renseigné',
                  leading: const Icon(Icons.account_balance_outlined),
                ),
              ],
            ),
          ),
          AppSpacing.gapLg,

          // Résumé académique alimenté par le backend
          const AppSectionHeader(title: 'Aperçu Académique'),
          Row(
            children: [
              Expanded(
                child: AppStatCard(
                  label: 'Matières suivies',
                  value: '$subjectsCount',
                  icon: Icons.menu_book_rounded,
                  color: AppColors.moduleSchedule,
                  onTap: () => showCreateSubjectSheet(context, ref),
                ),
              ),
              AppSpacing.gapSm,
              Expanded(
                child: AppStatCard(
                  label: 'Moyenne générale',
                  value: grades.isEmpty ? '— / 20' : '${overallAvg.toStringAsFixed(2)} / 20',
                  icon: Icons.insights_rounded,
                  color: AppColors.moduleGrades,
                  onTap: () => context.go('/grades'),
                ),
              ),
            ],
          ),
          AppSpacing.gapLg,

          AppButton(
            label: 'Modifier les informations',
            icon: Icons.edit_note_rounded,
            variant: AppButtonVariant.tonal,
            expand: true,
            onPressed: () => context.push(AuthRoutes.editProfile),
          ),
        ],
      ),
    );
  }
}
