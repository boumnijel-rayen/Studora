import 'package:flutter/widgets.dart';

/// Points de rupture pour l'adaptation aux tailles d'écran.
enum ScreenSize { compact, medium, expanded }

abstract final class AppBreakpoints {
  static const double medium = 600;
  static const double expanded = 1024;

  static ScreenSize of(double width) {
    if (width >= expanded) return ScreenSize.expanded;
    if (width >= medium) return ScreenSize.medium;
    return ScreenSize.compact;
  }
}

extension ResponsiveContext on BuildContext {
  ScreenSize get screenSize =>
      AppBreakpoints.of(MediaQuery.sizeOf(this).width);
  bool get isCompact => screenSize == ScreenSize.compact;
  bool get isMedium => screenSize == ScreenSize.medium;
  bool get isExpanded => screenSize == ScreenSize.expanded;

  /// Nombre de colonnes conseillé pour une grille de cartes.
  int get gridColumns => switch (screenSize) {
    ScreenSize.compact => 1,
    ScreenSize.medium => 2,
    ScreenSize.expanded => 3,
  };
}
