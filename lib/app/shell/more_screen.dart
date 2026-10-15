import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/core.dart';
import '../modules.dart';

/// Onglet « Plus » regroupant les modules secondaires et les outils système.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final prefs = ref.watch(preferencesProvider);

    // Modules ayant leur entrée dans « Plus »
    final moreModules = appModules
        .where((m) => m.entry.placement == ModulePlacement.more)
        .toList()
      ..sort((a, b) => a.entry.order.compareTo(b.entry.order));

    return AppScaffold(
      title: 'Plus d\'options',
      subtitle: 'Modules complémentaires & réglages',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Carte utilisateur rapide
          AppCard(
            onTap: () => context.push('/profile'),
            child: Row(
              children: [
                AppAvatar(name: user?.fullName ?? 'Étudiant', size: AppSizes.avatarLg),
                AppSpacing.gapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.fullName ?? 'Invité', style: context.text.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        user?.program.isNotEmpty == true
                            ? user!.program
                            : 'Étudiant Studora',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.colors.textSecondary),
              ],
            ),
          ),
          AppSpacing.gapLg,

          const AppSectionHeader(title: 'Espaces & Outils'),
          for (final mod in moreModules) ...[
            AppCard(
              onTap: () => context.go(mod.entry.rootPath),
              child: Row(
                children: [
                  AppIconBox(icon: mod.entry.selectedIcon, color: mod.entry.color),
                  AppSpacing.gapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mod.entry.label, style: context.text.titleSmall),
                        if (mod.entry.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(mod.entry.description, style: context.text.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: context.colors.textSecondary),
                ],
              ),
            ),
            AppSpacing.gapSm,
          ],

          AppSpacing.gapMd,
          const AppSectionHeader(title: 'Laboratoire & Développement'),
          AppCard(
            onTap: () => context.push('/dev/design-system'),
            child: Row(
              children: [
                const AppIconBox(icon: Icons.palette_rounded, color: AppColors.secondary),
                AppSpacing.gapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Galerie du Design System', style: context.text.titleSmall),
                      const SizedBox(height: 2),
                      Text('Vitrine des composants, tokens et variantes', style: context.text.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.colors.textSecondary),
              ],
            ),
          ),

          AppSpacing.gapLg,
          const AppSectionHeader(title: 'Apparence & Session'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                AppSwitchTile(
                  title: 'Mode sombre',
                  icon: prefs.themeMode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  value: prefs.themeMode == ThemeMode.dark,
                  onChanged: (isDark) {
                    ref.read(preferencesProvider.notifier).setThemeMode(
                      isDark ? ThemeMode.dark : ThemeMode.light,
                    );
                  },
                ),
                const Divider(),
                AppListTile(
                  title: 'Déconnexion',
                  leading: Icon(Icons.logout_rounded, color: context.colors.error),
                  onTap: () async {
                    final confirm = await AppConfirmDialog.show(
                      context,
                      title: 'Se déconnecter ?',
                      message: 'Vous devrez vous reconnecter pour accéder à votre espace.',
                      confirmLabel: 'Déconnexion',
                      destructive: true,
                    );
                    if (confirm && context.mounted) {
                      ref.read(sessionProvider.notifier).signOut();
                      context.go('/auth/login');
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
