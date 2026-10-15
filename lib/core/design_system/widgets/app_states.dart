import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_palette.dart';
import '../tokens/app_dimensions.dart';
import 'app_button.dart';

/// Bloc de chargement scintillant (skeleton).
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({super.key, this.width, this.height = 16, this.radius = AppRadius.sm});

  final double? width;
  final double height;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.colors.surfaceVariant;
    final hi = context.isDark ? context.colors.border : Colors.white;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            colors: [base, hi, base],
            stops: const [0.1, 0.5, 0.9],
            begin: Alignment(-1.5 + _ctrl.value * 3, 0),
            end: Alignment(-0.5 + _ctrl.value * 3, 0),
          ),
        ),
      ),
    );
  }
}

/// Liste de cartes skeleton (état de chargement par défaut des listes).
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({super.key, this.count = 5, this.itemHeight = 72});

  final int count;
  final double itemHeight;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(AppSpacing.md),
    physics: const NeverScrollableScrollPhysics(),
    shrinkWrap: true,
    itemCount: count,
    separatorBuilder: (_, _) => AppSpacing.gapSm,
    itemBuilder: (_, _) => Container(
      height: itemHeight,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(color: context.colors.surface, borderRadius: AppRadius.brLg),
      child: const Row(
        children: [
          AppSkeleton(width: 44, height: 44, radius: AppRadius.md),
          AppSpacing.gapSm,
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(width: 160, height: 14),
                AppSpacing.gapXs,
                AppSkeleton(width: 100, height: 12),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Indicateur de chargement centré.
class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(dimension: 32, child: CircularProgressIndicator(strokeWidth: 3)),
        if (message != null) ...[AppSpacing.gapSm, Text(message!, style: context.text.bodySmall)],
      ],
    ),
  );
}

/// État vide illustré.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.color,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final col = color ?? context.colors.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [col.withValues(alpha: 0.22), col.withValues(alpha: 0.04)],
                ),
              ),
              child: Icon(icon, size: 44, color: col),
            ),
            AppSpacing.gapLg,
            Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              AppSpacing.gapXs,
              Text(
                message!,
                style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null) ...[
              AppSpacing.gapLg,
              AppButton(label: actionLabel!, onPressed: onAction, icon: Icons.add_rounded),
            ],
          ],
        ),
      ),
    );
  }
}

/// État d'erreur avec bouton « Réessayer ».
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.title = 'Une erreur est survenue',
    this.message = 'Impossible de charger les données. Vérifiez votre connexion puis réessayez.',
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 56, color: context.colors.error),
          AppSpacing.gapMd,
          Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
          AppSpacing.gapXs,
          Text(
            message,
            style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            AppSpacing.gapLg,
            AppButton(
              label: 'Réessayer',
              icon: Icons.refresh_rounded,
              variant: AppButtonVariant.tonal,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    ),
  );
}

/// Gère uniformément loading / error / empty / data d'un [AsyncValue].
///
/// ```dart
/// AppAsyncView(
///   value: ref.watch(deadlinesProvider),
///   isEmpty: (list) => list.isEmpty,
///   empty: const AppEmptyState(icon: Icons.event_available, title: 'Aucune échéance'),
///   onRetry: () => ref.invalidate(deadlinesProvider),
///   data: (list) => DeadlineList(list),
/// )
/// ```
class AppAsyncView<T> extends StatelessWidget {
  const AppAsyncView({
    super.key,
    required this.value,
    required this.data,
    this.isEmpty,
    this.empty,
    this.loading,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final Widget? loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppDurations.normal,
    child: value.when(
      skipLoadingOnRefresh: true,
      loading: () => KeyedSubtree(key: const ValueKey('loading'), child: loading ?? const AppSkeletonList()),
      error: (_, _) => KeyedSubtree(key: const ValueKey('error'), child: AppErrorState(onRetry: onRetry)),
      data: (d) {
        if (empty != null && (isEmpty?.call(d) ?? false)) {
          return KeyedSubtree(key: const ValueKey('empty'), child: empty!);
        }
        return KeyedSubtree(key: const ValueKey('data'), child: data(d));
      },
    ),
  );
}
