import 'package:flutter/material.dart';

import '../design_system/design_system.dart';

/// Écran temporaire d'un module en cours de développement.
///
/// Fourni à l'étape 2 pour que chaque membre démarre sur une base qui compile.
/// ⚠️ À remplacer par les vrais écrans à l'étape 4.
class ModulePlaceholderScreen extends StatelessWidget {
  const ModulePlaceholderScreen({
    super.key,
    required this.title,
    required this.owner,
    required this.icon,
    required this.color,
    required this.plannedScreens,
    this.demoActions = const [],
  });

  final String title;
  final String owner;
  final IconData icon;
  final Color color;
  final List<String> plannedScreens;

  /// Boutons de démonstration de la navigation (libellé, action).
  final List<(String, VoidCallback)> demoActions;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: title,
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        AppCard(
          gradient: LinearGradient(
            colors: [color, Color.lerp(color, Colors.black, 0.25)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: AppRadius.brLg,
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              AppSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.titleLarge?.copyWith(color: Colors.white)),
                    AppSpacing.gapXxs,
                    Text(
                      'Responsable : $owner',
                      style: context.text.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        AppSpacing.gapLg,
        const AppSectionHeader(title: 'Écrans à développer'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              for (final s in plannedScreens)
                AppListTile(
                  dense: true,
                  title: s,
                  leading: Icon(Icons.radio_button_unchecked_rounded, size: 18, color: color),
                ),
            ],
          ),
        ),
        if (demoActions.isNotEmpty) ...[
          AppSpacing.gapLg,
          const AppSectionHeader(title: 'Démo de navigation'),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final (label, action) in demoActions)
                AppButton(
                  label: label,
                  variant: AppButtonVariant.tonal,
                  size: AppButtonSize.sm,
                  trailingIcon: Icons.arrow_forward_rounded,
                  onPressed: action,
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

/// Carte de dashboard temporaire d'un module.
class ModulePreviewCard extends StatelessWidget {
  const ModulePreviewCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    child: Row(
      children: [
        AppIconBox(icon: icon, color: color, size: 44),
        AppSpacing.gapSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.titleSmall),
              const SizedBox(height: 2),
              Text(subtitle, style: context.text.bodySmall),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: context.colors.textSecondary),
      ],
    ),
  );
}
