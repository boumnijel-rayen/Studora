import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/core.dart';
import '../modules.dart';

/// Tableau de bord central : agrège l'identité étudiant, les indicateurs et les cartes modules.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider) ?? MockSharedData.demoUser;

    // Cartes fournies par les modules
    final activeModules = appModules
        .where((m) => m.buildDashboardCard(context) != null)
        .toList()
      ..sort((a, b) => a.dashboardOrder.compareTo(b.dashboardOrder));

    return AppScaffold(
      // Pas d'AppBar sur cet écran : la SafeArea d'AppScaffold n'applique pas de
      // marge haute (top: false), on protège donc ici le contenu de la barre d'état.
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête : date + message de bienvenue à gauche, avatar (profil) à droite
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Formatters.day(DateTime.now()),
                                style: context.text.labelMedium?.copyWith(color: context.colors.textSecondary),
                              ),
                              AppSpacing.gapXxs,
                              Text(
                                'Bonjour ${user.firstName} 👋',
                                style: context.text.titleLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                user.program.isNotEmpty ? user.program : 'Bonne journée d\'études !',
                                style: context.text.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapSm,
                        Tooltip(
                          message: 'Mon profil',
                          child: GestureDetector(
                            onTap: () => context.push('/profile'),
                            child: AppAvatar(name: user.fullName, size: 52, showOnline: true),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapLg,

                  // Indicateurs clés d'avancement
                  Row(
                    children: [
                      Expanded(
                        child: AppStatCard(
                          label: 'Moyenne générale',
                          value: '14.2 / 20',
                          icon: Icons.trending_up_rounded,
                          color: AppColors.moduleGrades,
                          caption: '+0.4 ce semestre',
                          onTap: () => context.go('/grades'),
                        ),
                      ),
                      AppSpacing.gapSm,
                      Expanded(
                        child: AppStatCard(
                          label: 'Focus Révisions',
                          value: '3h 45',
                          icon: Icons.timer_rounded,
                          color: AppColors.moduleStudy,
                          caption: '4 sessions bouclées',
                          onTap: () => context.go('/study'),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapLg,

                  const AppSectionHeader(title: 'Activités & Modules'),
                  for (final mod in activeModules) ...[
                    mod.buildDashboardCard(context)!,
                    AppSpacing.gapSm,
                  ],
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
