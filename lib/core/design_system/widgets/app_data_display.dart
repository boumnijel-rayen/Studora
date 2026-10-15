import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../tokens/app_dimensions.dart';

/// Barre de progression arrondie et animée.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({super.key, required this.value, this.color, this.height = 8});

  /// Entre 0 et 1.
  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: AppRadius.brFull,
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: AppDurations.slow,
      curve: AppDurations.curve,
      builder: (_, v, _) => LinearProgressIndicator(
        value: v,
        minHeight: height,
        color: color ?? context.colors.primary,
        backgroundColor: context.colors.surfaceVariant,
      ),
    ),
  );
}

/// Anneau de progression (moyenne, Pomodoro, objectifs).
class AppProgressRing extends StatelessWidget {
  const AppProgressRing({
    super.key,
    required this.value,
    this.size = 96,
    this.strokeWidth = 10,
    this.color,
    this.gradient,
    this.child,
  });

  /// Entre 0 et 1.
  final double value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Gradient? gradient;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: AppDurations.slow,
      curve: AppDurations.curve,
      builder: (_, v, child) => CustomPaint(
        painter: _RingPainter(
          value: v,
          stroke: strokeWidth,
          track: context.colors.surfaceVariant,
          color: color ?? context.colors.primary,
          gradient: gradient,
        ),
        child: Center(child: child),
      ),
      child: child,
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.stroke,
    required this.track,
    required this.color,
    this.gradient,
  });

  final double value;
  final double stroke;
  final Color track;
  final Color color;
  final Gradient? gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, base..color = track);
    if (value <= 0) return;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (gradient != null) {
      fg.shader = gradient!.createShader(rect);
    } else {
      fg.color = color;
    }
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * value, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

enum AppBadgeTone { primary, success, warning, error, info, neutral }

/// Petite étiquette colorée (statut, date, priorité).
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = AppBadgeTone.primary,
    this.color,
    this.icon,
  });

  final String label;
  final AppBadgeTone tone;

  /// Prioritaire sur [tone].
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final col = color ??
        switch (tone) {
          AppBadgeTone.primary => c.primary,
          AppBadgeTone.success => c.success,
          AppBadgeTone.warning => c.warning,
          AppBadgeTone.error => c.error,
          AppBadgeTone.info => c.info,
          AppBadgeTone.neutral => c.textSecondary,
        };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 3),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.14),
        borderRadius: AppRadius.brFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: col), const SizedBox(width: 4)],
          Text(label, style: context.text.labelSmall?.copyWith(color: col, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Puce de matière avec pastille de couleur.
class SubjectChip extends StatelessWidget {
  const SubjectChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: AppRadius.brFull,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: context.text.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

/// Rangée de filtres à choix unique, défilante horizontalement.
class AppFilterChips<T> extends StatelessWidget {
  const AppFilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.padding = AppSpacing.screen,
  });

  /// valeur → libellé
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final e in options.entries) ...[
            ChoiceChip(
              label: Text(e.value),
              selected: e.key == selected,
              onSelected: (_) => onSelected(e.key),
              labelStyle: context.text.labelMedium?.copyWith(
                color: e.key == selected ? c.primary : c.textSecondary,
              ),
            ),
            AppSpacing.gapXs,
          ],
        ],
      ),
    );
  }
}

/// Avatar à initiales (couleur déduite du nom).
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.name, this.size = AppSizes.avatarMd, this.color, this.showOnline = false});

  final String name;
  final double size;
  final Color? color;
  final bool showOnline;

  static const _palette = [
    Color(0xFF5B4BDB), Color(0xFFFF7A59), Color(0xFF14B8A6), Color(0xFF3B82F6),
    Color(0xFFEC4899), Color(0xFFF59E0B), Color(0xFF8B5CF6), Color(0xFF06B6D4),
  ];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final col = color ?? _palette[name.hashCode.abs() % _palette.length];
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [col, Color.lerp(col, Colors.white, 0.25)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Text(
              _initials,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.38,
              ),
            ),
          ),
          if (showOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: context.colors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pile d'avatars superposés (+N).
class AppAvatarStack extends StatelessWidget {
  const AppAvatarStack({super.key, required this.names, this.size = AppSizes.avatarSm, this.max = 4});

  final List<String> names;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final shown = names.take(max).toList();
    final extra = names.length - shown.length;
    final count = shown.length + (extra > 0 ? 1 : 0);
    final overlap = size * 0.65;
    return SizedBox(
      height: size,
      width: count == 0 ? 0 : size + overlap * (count - 1),
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * overlap,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.surface, width: 2),
                ),
                child: AppAvatar(name: shown[i], size: size - 4),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * overlap,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colors.surfaceVariant,
                  border: Border.all(color: context.colors.surface, width: 2),
                ),
                child: Text('+$extra', style: context.text.labelSmall),
              ),
            ),
        ],
      ),
    );
  }
}
