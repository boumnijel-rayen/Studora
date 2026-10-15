import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../tokens/app_dimensions.dart';
import 'app_button.dart';

/// Feuille modale du bas standardisée.
abstract final class AppBottomSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    bool scrollable = true,
  }) => showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SingleChildScrollView(
        physics: scrollable ? null : const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(title, style: ctx.text.titleLarge),
              AppSpacing.gapMd,
            ],
            child,
          ],
        ),
      ),
    ),
  );
}

/// Boîte de dialogue de confirmation. Renvoie `true` si confirmé.
abstract final class AppConfirmDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirmer',
    String cancelLabel = 'Annuler',
    bool destructive = false,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        actions: [
          AppButton(
            label: cancelLabel,
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.sm,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          AppButton(
            label: confirmLabel,
            variant: destructive ? AppButtonVariant.danger : AppButtonVariant.primary,
            size: AppButtonSize.sm,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    return res ?? false;
  }
}

enum _SnackTone { success, error, info }

/// Messages éphémères uniformes.
abstract final class AppSnackbar {
  static void success(BuildContext c, String msg) => _show(c, msg, _SnackTone.success);
  static void error(BuildContext c, String msg) => _show(c, msg, _SnackTone.error);
  static void info(BuildContext c, String msg) => _show(c, msg, _SnackTone.info);

  static void _show(BuildContext context, String msg, _SnackTone tone) {
    final c = context.colors;
    final (IconData icon, Color color) = switch (tone) {
      _SnackTone.success => (Icons.check_circle_rounded, c.success),
      _SnackTone.error => (Icons.error_rounded, c.error),
      _SnackTone.info => (Icons.info_rounded, c.info),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: color, size: 20),
              AppSpacing.gapSm,
              Expanded(child: Text(msg)),
            ],
          ),
        ),
      );
  }
}
