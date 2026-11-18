import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/core.dart';
import '../../features/auth/auth_routes.dart';
import '../dashboard/dashboard_screen.dart';
import '../modules.dart';
import '../shell/app_shell.dart';
import '../shell/more_screen.dart';

/// Notifier écouté par GoRouter pour réévaluer les redirections dès que
/// l'état d'authentification ou d'abonnement change.
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

  ref.listen<UserSubscription>(subscriptionProvider, (_, _) {
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
      path: '/subscription/locked',
      parentNavigatorKey: AppNavigator.rootKey,
      builder: (context, state) {
        final featureKey = state.uri.queryParameters['feature'];
        final feature = AppFeature.fromKey(featureKey) ?? AppFeature.studyGroups;
        return Consumer(
          builder: (context, ref, _) {
            final sub = ref.watch(subscriptionProvider);
            return LockedFeatureScreen(
              feature: feature,
              currentPlan: sub.plan,
            );
          },
        );
      },
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

      // Si l'utilisateur est sur l'écran d'inscription, ne jamais interrompre le parcours
      // (notamment pendant l'ouverture de la PaymentSheet Stripe à l'étape 3).
      if (location == AuthRoutes.register || state.uri.path == AuthRoutes.register) {
        return null;
      }

      // Si déjà authentifié et tente d'aller sur login ou onboarding
      if (user != null && (location == AuthRoutes.login || location == AuthRoutes.onboarding)) {
        return '/home';
      }

      if (user != null) {
        final sub = ref.read(subscriptionProvider);

        // Si l'utilisateur est sur l'écran de verrouillage mais vient de débloquer la fonctionnalité
        if (location == '/subscription/locked') {
          final feature = AppFeature.fromKey(state.uri.queryParameters['feature']);
          if (feature != null && sub.hasFeature(feature)) {
            final unlockedMod = appModules
                .where((m) => m.requiredFeature == feature)
                .firstOrNull;
            return unlockedMod?.entry.rootPath ?? '/home';
          }
          return null;
        }

        // Contrôle d'accès centralisé par module selon l'abonnement actif
        for (final mod in appModules) {
          final requiredFeature = mod.requiredFeature;
          if (requiredFeature == null) continue;
          final root = mod.entry.rootPath;
          if (location == root || location.startsWith('$root/')) {
            if (!sub.hasFeature(requiredFeature)) {
              return lockedFeatureRoute(requiredFeature);
            }
          }
        }
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
