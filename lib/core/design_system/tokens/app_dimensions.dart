import 'package:flutter/material.dart';

/// Espacements (grille de 4 px).
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Marge horizontale standard des écrans.
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: md);

  /// Padding standard d'une carte.
  static const EdgeInsets card = EdgeInsets.all(md);

  // Espaceurs prêts à l'emploi.
  static const SizedBox gapXxs = SizedBox(width: xxs, height: xxs);
  static const SizedBox gapXs = SizedBox(width: xs, height: xs);
  static const SizedBox gapSm = SizedBox(width: sm, height: sm);
  static const SizedBox gapMd = SizedBox(width: md, height: md);
  static const SizedBox gapLg = SizedBox(width: lg, height: lg);
  static const SizedBox gapXl = SizedBox(width: xl, height: xl);
}

/// Rayons d'arrondi.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 999;

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brFull = BorderRadius.all(Radius.circular(full));
}

/// Dimensions standardisées.
abstract final class AppSizes {
  static const double buttonMd = 52;
  static const double buttonSm = 40;
  static const double input = 56;
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 28;
  static const double avatarSm = 32;
  static const double avatarMd = 40;
  static const double avatarLg = 64;
  static const double avatarXl = 96;
  static const double minTouchTarget = 48;
  static const double maxContentWidth = 1200;
  static const double maxFormWidth = 480;
}

/// Durées d'animation.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Curve curve = Curves.easeOutCubic;
}

/// Ombres.
abstract final class AppShadows {
  static List<BoxShadow> soft(Brightness b) => [
    BoxShadow(
      color: (b == Brightness.light ? const Color(0xFF1A1B2E) : Colors.black)
          .withValues(alpha: b == Brightness.light ? 0.06 : 0.3),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> medium(Brightness b) => [
    BoxShadow(
      color: (b == Brightness.light ? const Color(0xFF1A1B2E) : Colors.black)
          .withValues(alpha: b == Brightness.light ? 0.10 : 0.4),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.35),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}
