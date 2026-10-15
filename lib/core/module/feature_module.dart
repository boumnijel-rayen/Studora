import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Clé du navigateur racine.
///
/// Pour afficher un écran **plein écran au-dessus du shell** (chat, Pomodoro,
/// formulaires) depuis une route de module :
/// ```dart
/// GoRoute(
///   path: 'pomodoro',
///   parentNavigatorKey: AppNavigator.rootKey,
///   builder: (_, _) => const PomodoroTimerScreen(),
/// )
/// ```
abstract final class AppNavigator {
  static final GlobalKey<NavigatorState> rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
}

/// Emplacement d'un module dans la navigation globale.
enum ModulePlacement {
  /// Onglet de la barre de navigation principale.
  tab,

  /// Tuile dans l'onglet « Plus ».
  more,

  /// Pas d'entrée de navigation (ex. écrans d'authentification).
  hidden,
}

/// Métadonnées de navigation d'un module.
@immutable
class ModuleEntry {
  const ModuleEntry({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.color,
    required this.rootPath,
    required this.placement,
    this.order = 100,
    this.description = '',
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Couleur d'identité (cf. `AppColors.moduleXxx`).
  final Color color;

  /// Chemin racine (doit correspondre à une route de [FeatureModule.shellRoutes]).
  final String rootPath;
  final ModulePlacement placement;

  /// Ordre d'affichage (croissant).
  final int order;

  /// Sous-titre affiché dans l'onglet « Plus ».
  final String description;
}

/// Contrat que **chaque module** doit implémenter.
///
/// Le routeur, la barre de navigation, l'onglet « Plus » et le dashboard
/// sont construits automatiquement à partir de la liste `appModules`
/// (cf. `lib/app/modules.dart`). Aucun membre n'a besoin de modifier
/// le routeur global.
abstract class FeatureModule {
  const FeatureModule();

  /// Identifiant unique : 'auth', 'schedule', 'study', 'groups', 'grades', 'roommates'.
  String get id;

  /// Entrée de navigation du module.
  ModuleEntry get entry;

  /// Routes affichées DANS le shell (barre de navigation visible).
  /// Les chemins de premier niveau doivent commencer par le préfixe du module.
  List<RouteBase> get shellRoutes;

  /// Routes affichées HORS du shell, avant/sans authentification
  /// (ex. `/auth/login`). Rarement nécessaire hors du module Auth.
  List<RouteBase> get fullscreenRoutes => const [];

  /// Carte résumé affichée sur le dashboard (facultative).
  Widget? buildDashboardCard(BuildContext context) => null;

  /// Ordre d'affichage de la carte sur le dashboard.
  int get dashboardOrder => entry.order;
}
