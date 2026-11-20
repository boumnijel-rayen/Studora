import 'package:flutter/widgets.dart';

/// Point de rupture unique : en dessous de 600 px, l'écran est considéré
/// comme « mobile » (barre de navigation en bas), au-delà comme « large »
/// (rail de navigation latéral).
abstract final class AppBreakpoints {
  static const double medium = 600;
}

extension ResponsiveContext on BuildContext {
  /// `true` sur téléphone (largeur < 600 px).
  bool get isCompact => MediaQuery.sizeOf(this).width < AppBreakpoints.medium;
}
