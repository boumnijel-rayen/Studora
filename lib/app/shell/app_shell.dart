import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/core.dart';
import '../modules.dart';

/// Shell principal adaptatif :
/// - Mobile : Barre de navigation inférieure (`NavigationBar`)
/// - Tablette / Bureau : Rail de navigation latéral (`NavigationRail`)
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  Widget _tabIcon(IconData icon, {required bool locked}) {
    if (!locked) return Icon(icon);
    return Badge(
      label: const Icon(Icons.lock_rounded, size: 10, color: Colors.white),
      backgroundColor: AppColors.warning,
      child: Icon(icon),
    );
  }

  void _onSelectIndex(
    BuildContext context,
    WidgetRef ref,
    int index,
    List<FeatureModule> tabModules,
  ) {
    // Les indices 1..tabModules.length correspondent aux modules en onglet
    if (index >= 1 && index <= tabModules.length) {
      final mod = tabModules[index - 1];
      final requiredFeature = mod.requiredFeature;
      if (requiredFeature != null && !ref.read(hasFeatureProvider(requiredFeature))) {
        context.push(lockedFeatureRoute(requiredFeature));
        return;
      }
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subscriptionProvider);

    // Onglets : Accueil + modules « tab » (Planning, Révisions, Groupes) + Plus
    final tabModules = appModules
        .where((m) => m.entry.placement == ModulePlacement.tab)
        .toList()
      ..sort((a, b) => a.entry.order.compareTo(b.entry.order));

    // Une seule description des onglets, réutilisée par la barre (mobile) et le rail (tablette).
    final tabs = <({IconData icon, IconData selectedIcon, String label, bool locked})>[
      (icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Accueil', locked: false),
      for (final mod in tabModules)
        (
          icon: mod.entry.icon,
          selectedIcon: mod.entry.selectedIcon,
          label: mod.entry.label,
          locked: mod.requiredFeature != null && !sub.hasFeature(mod.requiredFeature!),
        ),
      (icon: Icons.grid_view_outlined, selectedIcon: Icons.grid_view_rounded, label: 'Plus', locked: false),
    ];

    void onSelect(int index) => _onSelectIndex(context, ref, index, tabModules);

    if (context.isCompact) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: onSelect,
          destinations: [
            for (final t in tabs)
              NavigationDestination(
                icon: _tabIcon(t.icon, locked: t.locked),
                selectedIcon: _tabIcon(t.selectedIcon, locked: t.locked),
                label: t.label,
              ),
          ],
        ),
      );
    }

    // Vue tablette et bureau avec NavigationRail
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: onSelect,
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
            destinations: [
              for (final t in tabs)
                NavigationRailDestination(
                  icon: _tabIcon(t.icon, locked: t.locked),
                  selectedIcon: _tabIcon(t.selectedIcon, locked: t.locked),
                  label: Text(t.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
