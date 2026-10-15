import 'package:flutter/material.dart';

/// Hiérarchie typographique Studora (Plus Jakarta Sans embarquée).
abstract final class AppTypography {
  static const String fontFamily = 'PlusJakartaSans';

  static TextTheme textTheme(Color primary, Color secondary) => TextTheme(
    displayLarge: _s(40, FontWeight.w800, primary, -1.0),
    displayMedium: _s(34, FontWeight.w800, primary, -0.8),
    displaySmall: _s(30, FontWeight.w700, primary, -0.5),
    headlineLarge: _s(32, FontWeight.w700, primary, -0.5),
    headlineMedium: _s(28, FontWeight.w700, primary, -0.4),
    headlineSmall: _s(24, FontWeight.w700, primary, -0.3),
    titleLarge: _s(22, FontWeight.w700, primary, -0.2),
    titleMedium: _s(18, FontWeight.w600, primary, -0.1),
    titleSmall: _s(16, FontWeight.w600, primary, 0),
    bodyLarge: _s(16, FontWeight.w500, primary, 0),
    bodyMedium: _s(14, FontWeight.w400, primary, 0),
    bodySmall: _s(12, FontWeight.w400, secondary, 0),
    labelLarge: _s(14, FontWeight.w600, primary, 0.1),
    labelMedium: _s(13, FontWeight.w600, primary, 0.1),
    labelSmall: _s(12, FontWeight.w500, secondary, 0.2),
  );

  static TextStyle _s(double size, FontWeight w, Color c, double ls) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: w,
        color: c,
        letterSpacing: ls,
        height: size >= 24 ? 1.2 : 1.4,
      );
}
