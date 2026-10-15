import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../tokens/app_dimensions.dart';

/// Carte de base (fond surface, coins arrondis, ombre douce).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = AppSpacing.card,
    this.color,
    this.gradient,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.soft(context.brightness),
      ),
      child: Material(
        color: gradient != null ? Colors.transparent : (color ?? c.surface),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brLg,
          side: BorderSide(
            color: borderColor ?? (context.isDark ? c.border : Colors.transparent),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: gradient == null ? null : BoxDecoration(gradient: gradient),
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Carte d'indicateur chiffré (moyenne, heures de révision, solde…).
class AppStatCard extends StatelessWidget {
  const AppStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.caption,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? context.colors.primary;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIconBox(icon: icon, color: accent),
          AppSpacing.gapSm,
          Text(value, style: context.text.headlineSmall),
          AppSpacing.gapXxs,
          Text(label, style: context.text.bodySmall),
          if (caption != null) ...[
            AppSpacing.gapXxs,
            Text(caption!, style: context.text.labelSmall?.copyWith(color: accent)),
          ],
        ],
      ),
    );
  }
}

/// Icône dans un carré teinté.
class AppIconBox extends StatelessWidget {
  const AppIconBox({super.key, required this.icon, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: AppRadius.brMd,
    ),
    child: Icon(icon, color: color, size: size * 0.52),
  );
}

/// Ligne de liste standard.
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: AppRadius.brMd,
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: dense ? AppSpacing.xs : AppSpacing.sm,
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, AppSpacing.gapSm],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: context.text.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[AppSpacing.gapSm, trailing!],
        ],
      ),
    ),
  );
}

/// En-tête de section avec action optionnelle « Voir tout ».
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.sm),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      children: [
        Expanded(child: Text(title, style: context.text.titleMedium)),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              minimumSize: const Size(0, 32),
            ),
            child: Text(actionLabel!),
          ),
      ],
    ),
  );
}
