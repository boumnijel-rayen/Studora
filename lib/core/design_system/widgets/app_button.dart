import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../tokens/app_dimensions.dart';

enum AppButtonVariant { primary, secondary, tonal, ghost, danger }

enum AppButtonSize { md, sm }

/// Bouton standard de Studora.
///
/// ```dart
/// AppButton(label: 'Se connecter', onPressed: _submit, isLoading: busy)
/// AppButton(label: 'Annuler', variant: AppButtonVariant.ghost, onPressed: …)
/// ```
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isLoading;

  /// Occupe toute la largeur disponible.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null && !isLoading;
    final height = size == AppButtonSize.md ? AppSizes.buttonMd : AppSizes.buttonSm;

    final (Color bg, Color fg, BorderSide? side) = switch (variant) {
      AppButtonVariant.primary => (c.primary, Colors.white, null),
      AppButtonVariant.secondary => (
        Colors.transparent,
        c.textPrimary,
        BorderSide(color: c.border, width: 1.2),
      ),
      AppButtonVariant.tonal => (c.primary.withValues(alpha: 0.12), c.primary, null),
      AppButtonVariant.ghost => (Colors.transparent, c.primary, null),
      AppButtonVariant.danger => (c.error, Colors.white, null),
    };

    final hasShadow = enabled &&
        (variant == AppButtonVariant.primary || variant == AppButtonVariant.danger);

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
          )
        else if (icon != null)
          Icon(icon, size: AppSizes.iconSm, color: fg),
        if (isLoading || icon != null) AppSpacing.gapXs,
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: (size == AppButtonSize.md
                    ? context.text.labelLarge
                    : context.text.labelMedium)
                ?.copyWith(color: fg),
          ),
        ),
        if (trailingIcon != null && !isLoading) ...[
          AppSpacing.gapXs,
          Icon(trailingIcon, size: AppSizes.iconSm, color: fg),
        ],
      ],
    );

    return _Pressable(
      enabled: enabled,
      child: AnimatedOpacity(
        duration: AppDurations.fast,
        opacity: onPressed == null ? 0.38 : 1,
        child: AnimatedContainer(
          duration: AppDurations.normal,
          height: height,
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            boxShadow: hasShadow ? AppShadows.glow(bg) : null,
          ),
          child: Material(
            color: bg,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.brMd,
              side: side ?? BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: size == AppButtonSize.md ? AppSpacing.lg : AppSpacing.md,
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton icône carré arrondi (actions d'AppBar, cartes…).
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.filled = false,
    this.color,
    this.badgeCount,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool filled;
  final Color? color;

  /// Pastille de compteur (notifications, messages non lus).
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = color ?? (filled ? c.primary : c.textPrimary);
    final button = _Pressable(
      enabled: onPressed != null,
      child: Material(
        color: filled ? fg.withValues(alpha: 0.12) : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brMd,
          side: filled ? BorderSide.none : BorderSide(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 44,
            child: Icon(icon, size: AppSizes.iconMd, color: fg),
          ),
        ),
      ),
    );

    final withBadge = (badgeCount ?? 0) > 0
        ? Badge(
            label: Text(badgeCount! > 9 ? '9+' : '$badgeCount'),
            backgroundColor: c.secondary,
            offset: const Offset(-2, 2),
            child: button,
          )
        : button;

    return tooltip == null ? withBadge : Tooltip(message: tooltip, child: withBadge);
  }
}

/// Micro-animation d'enfoncement au toucher.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.enabled});

  final Widget child;
  final bool enabled;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.enabled && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _down ? 0.97 : 1,
      duration: AppDurations.fast,
      curve: AppDurations.curve,
      child: widget.child,
    ),
  );
}
