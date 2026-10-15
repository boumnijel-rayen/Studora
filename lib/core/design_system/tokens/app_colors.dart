import 'package:flutter/material.dart';

/// Palette Studora.
///
/// ⚠️ Ne jamais utiliser de couleur en dur dans les modules :
/// passer par `context.colors` (thème courant) ou par ces constantes
/// pour les couleurs indépendantes du mode clair/sombre.
abstract final class AppColors {
  // ── Marque ────────────────────────────────────────────────
  static const Color primary = Color(0xFF5B4BDB);
  static const Color primaryDark = Color(0xFF8B7FF0);
  static const Color secondary = Color(0xFFFF7A59);
  static const Color secondaryDark = Color(0xFFFF9A80);
  static const Color tertiary = Color(0xFF14B8A6);
  static const Color tertiaryDark = Color(0xFF2DD4BF);

  // ── Neutres clairs ───────────────────────────────────────
  static const Color lightBackground = Color(0xFFF6F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFEEF0F7);
  static const Color lightTextPrimary = Color(0xFF1A1B2E);
  static const Color lightTextSecondary = Color(0xFF6B6F86);
  static const Color lightBorder = Color(0xFFE3E5EF);

  // ── Neutres sombres ──────────────────────────────────────
  static const Color darkBackground = Color(0xFF0F1020);
  static const Color darkSurface = Color(0xFF1A1B2E);
  static const Color darkSurfaceVariant = Color(0xFF25263D);
  static const Color darkTextPrimary = Color(0xFFF3F4FA);
  static const Color darkTextSecondary = Color(0xFFA3A6BF);
  static const Color darkBorder = Color(0xFF2F3150);

  // ── Sémantiques ──────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Identité des modules ─────────────────────────────────
  static const Color moduleProfile = primary;
  static const Color moduleSchedule = Color(0xFF3B82F6);
  static const Color moduleStudy = secondary;
  static const Color moduleGroups = Color(0xFF8B5CF6);
  static const Color moduleGrades = tertiary;
  static const Color moduleRoommates = Color(0xFFF59E0B);

  // ── Matières (même couleur dans tous les modules) ───────
  static const List<Color> subjectPalette = [
    Color(0xFF5B4BDB),
    Color(0xFFFF7A59),
    Color(0xFF14B8A6),
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFF22C55E),
    Color(0xFF06B6D4),
    Color(0xFFEF4444),
  ];

  // ── Dégradés ─────────────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF5B4BDB), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient focusGradient = LinearGradient(
    colors: [Color(0xFF5B4BDB), Color(0xFFFF7A59)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
