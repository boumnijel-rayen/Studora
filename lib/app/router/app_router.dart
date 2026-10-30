import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/core.dart';
import '../../features/auth/auth_routes.dart';
import '../dashboard/dashboard_screen.dart';
import '../modules.dart';
import '../shell/app_shell.dart';
import '../shell/design_system_gallery_screen.dart';
import '../shell/more_screen.dart';

/// Notifier écouté par GoRouter pour réévaluer les redirections dès que
/// l'état d'authentification change (ex. déconnexion ou expiration 401).
class _RouterRefreshNotifier extends ChangeNotifier {
  void trigger() => notifyListeners();
}

/// Configuration centrale du routeur déclaratif GoRouter.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.onDispose(refreshNotifier.dispose);

  ref.listen<AppUser?>(sessionProvider, (_, _) {
    refreshNotifier.trigger();
  });

  // Modules placés dans la barre principale
  final tabModules = appModules
      .where((m) => m.entry.placement == ModulePlacement.tab)
      .toList()
    ..sort((a, b) => a.entry.order.compareTo(b.entry.order));

  // Toutes les routes de plein écran
  final allFullscreenRoutes = <RouteBase>[
    for (final mod in appModules) ...mod.fullscreenRoutes,
    GoRoute(
      path: '/dev/design-system',
      parentNavigatorKey: AppNavigator.rootKey,
      builder: (_, _) => const DesignSystemGalleryScreen(),
    ),
  ];

  return GoRouter(
    navigatorKey: AppNavigator.rootKey,
    initialLocation: AuthRoutes.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final user = ref.read(sessionProvider);
      final location = state.matchedLocation;
      final isPublic = AuthRoutes.isPublic(location);

      // Si l'utilisateur n'est pas authentifié et accède à une route privée
      if (user == null && !isPublic) {
        return AuthRoutes.login;
      }

      // Si déjà authentifié et tente d'aller sur login ou onboarding
      if (user != null && (location == AuthRoutes.login || location == AuthRoutes.onboarding)) {
        return '/home';
      }

      return null;
    },
    routes: [
      ...allFullscreenRoutes,
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          // Branche 0 : Accueil (Dashboard)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, _) => const DashboardScreen(),
              ),
            ],
          ),

          // Branches des modules onglets
          for (final mod in tabModules)
            StatefulShellBranch(
              routes: mod.shellRoutes,
            ),

          // Dernière branche : Onglet « Plus » (qui héberge les routes des modules secondaires)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (_, _) => const MoreScreen(),
              ),
              for (final mod in appModules.where((m) => m.entry.placement == ModulePlacement.more))
                ...mod.shellRoutes,
            ],
          ),
        ],
      ),
    ],
  );
});
