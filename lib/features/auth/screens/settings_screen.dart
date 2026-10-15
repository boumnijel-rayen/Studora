import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final notifier = ref.read(preferencesProvider.notifier);

    return AppScaffold(
      title: 'Préférences',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const AppSectionHeader(title: 'Apparence'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                AppSwitchTile(
                  title: 'Mode sombre',
                  subtitle: 'Adapter l\'interface aux ambiances sombres',
                  icon: prefs.themeMode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  value: prefs.themeMode == ThemeMode.dark,
                  onChanged: (isDark) => notifier.setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light),
                ),
              ],
            ),
          ),
          AppSpacing.gapLg,

          const AppSectionHeader(title: 'Notifications & Alertes'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                AppSwitchTile(
                  title: 'Notifications push simulées',
                  subtitle: 'Recevoir les alertes d\'échéances et de cours',
                  icon: Icons.notifications_active_outlined,
                  value: prefs.notificationsEnabled,
                  onChanged: notifier.setNotifications,
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 22),
                      AppSpacing.gapSm,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Rappel avant le cours', style: context.text.bodyLarge),
                            Text('Délai d\'anticipation de notification', style: context.text.bodySmall),
                          ],
                        ),
                      ),
                      DropdownButton<int>(
                        value: prefs.reminderMinutesBefore,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 15, child: Text('15 min')),
                          DropdownMenuItem(value: 30, child: Text('30 min')),
                          DropdownMenuItem(value: 60, child: Text('1 heure')),
                        ],
                        onChanged: (v) {
                          if (v != null) notifier.setReminderMinutes(v);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapLg,

          const AppSectionHeader(title: 'Région & Unités'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                AppListTile(
                  title: 'Langue de l\'application',
                  subtitle: 'Français (France)',
                  leading: const Icon(Icons.language_rounded),
                  trailing: const Icon(Icons.check_rounded, color: AppColors.primary),
                  onTap: () => AppSnackbar.info(context, 'Langue fixée en Français'),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const Icon(Icons.euro_rounded, size: 22),
                      AppSpacing.gapSm,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Devise de colocation', style: context.text.bodyLarge),
                            Text('Pour les dépenses et comptes partagés', style: context.text.bodySmall),
                          ],
                        ),
                      ),
                      DropdownButton<String>(
                        value: prefs.currency,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: '€', child: Text('Euro (€)')),
                          DropdownMenuItem(value: 'TND', child: Text('Dinar (TND)')),
                          DropdownMenuItem(value: '\$', child: Text('Dollar (\$)')),
                        ],
                        onChanged: (v) {
                          if (v != null) notifier.setCurrency(v);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.gapLg,

          const AppSectionHeader(title: 'À propos'),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const AppIconBox(icon: Icons.info_outline_rounded, color: AppColors.primary),
                AppSpacing.gapSm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Studora v0.1.0', style: context.text.titleSmall),
                      Text('Projet universitaire Frontend Flutter', style: context.text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
