import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/core.dart';
import '../modules.dart';

/// Shell principal adaptatif :
/// - Mobile : Barre de navigation inférieure (`NavigationBar`)
/// - Tablette / Bureau : Rail de navigation latéral (`NavigationRail`)
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    // 5 onglets fixes : Accueil, Planning, Révisions, Groupes, Plus
    final tabModules = appModules
        .where((m) => m.entry.placement == ModulePlacement.tab)
        .toList()
      ..sort((a, b) => a.entry.order.compareTo(b.entry.order));

    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Accueil',
      ),
      for (final mod in tabModules)
        NavigationDestination(
          icon: Icon(mod.entry.icon),
          selectedIcon: Icon(mod.entry.selectedIcon),
          label: mod.entry.label,
        ),
      const NavigationDestination(
        icon: Icon(Icons.grid_view_outlined),
        selectedIcon: Icon(Icons.grid_view_rounded),
        label: 'Plus',
      ),
    ];

    final railDestinations = [
      const NavigationRailDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: Text('Accueil'),
      ),
      for (final mod in tabModules)
        NavigationRailDestination(
          icon: Icon(mod.entry.icon),
          selectedIcon: Icon(mod.entry.selectedIcon),
          label: Text(mod.entry.label),
        ),
      const NavigationRailDestination(
        icon: Icon(Icons.grid_view_outlined),
        selectedIcon: Icon(Icons.grid_view_rounded),
        label: Text('Plus'),
      ),
    ];

    final isCompact = context.isCompact;

    if (isCompact) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          destinations: destinations,
        ),
      );
    }

    // Vue tablette et bureau avec NavigationRail
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) {
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  gradient: AppColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
              ),
            ),
            destinations: railDestinations,
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
