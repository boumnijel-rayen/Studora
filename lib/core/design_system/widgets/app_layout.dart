import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../tokens/app_breakpoints.dart';
import '../tokens/app_dimensions.dart';

/// Scaffold standard : AppBar Studora + contenu centré et limité en largeur.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
    this.bottom,
    this.showBack,
    this.maxWidth = AppSizes.maxContentWidth,
    this.bottomBar,
    this.backgroundColor,
  });

  final Widget body;
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;

  /// `null` = automatique (affiché si l'on peut revenir en arrière).
  final bool? showBack;
  final double maxWidth;
  final Widget? bottomBar;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final canPop = showBack ?? Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: title == null && actions == null && bottom == null
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              leading: canPop
                  ? IconButton(
                      tooltip: 'Retour',
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      onPressed: () => Navigator.of(context).maybePop(),
                    )
                  : null,
              titleSpacing: canPop ? 0 : AppSpacing.md,
              title: title == null
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title!, style: context.text.titleLarge),
                        if (subtitle != null) Text(subtitle!, style: context.text.bodySmall),
                      ],
                    ),
              actions: [
                ...?actions?.map(
                  (a) => Padding(padding: const EdgeInsets.only(left: AppSpacing.xs), child: a),
                ),
                AppSpacing.gapMd,
              ],
              bottom: bottom,
            ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomBar,
      body: SafeArea(top: false, bottom: false, child: AppMaxWidth(maxWidth: maxWidth, child: body)),
    );
  }
}

/// Centre et limite la largeur du contenu (tablette / desktop).
class AppMaxWidth extends StatelessWidget {
  const AppMaxWidth({super.key, required this.child, this.maxWidth = AppSizes.maxContentWidth});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
  );
}

/// Choisit un widget selon la taille d'écran.
class AppResponsiveLayout extends StatelessWidget {
  const AppResponsiveLayout({super.key, required this.compact, this.medium, this.expanded});

  final Widget compact;
  final Widget? medium;
  final Widget? expanded;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, cons) => switch (AppBreakpoints.of(cons.maxWidth)) {
      ScreenSize.expanded => expanded ?? medium ?? compact,
      ScreenSize.medium => medium ?? compact,
      ScreenSize.compact => compact,
    },
  );
}

/// Grille adaptative : 1 colonne (mobile), 2 (tablette), 3 (desktop).
class AppAdaptiveGrid extends StatelessWidget {
  const AppAdaptiveGrid({
    super.key,
    required this.children,
    this.spacing = AppSpacing.md,
    this.minItemWidth = 300,
  });

  final List<Widget> children;
  final double spacing;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, cons) {
      final cols = (cons.maxWidth / minItemWidth).floor().clamp(1, 4);
      final w = (cons.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final c in children) SizedBox(width: w, child: c)],
      );
    },
  );
}

/// Onglets internes à un écran (style pilule).
class AppTabBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTabBar({super.key, required this.tabs, this.controller, this.isScrollable = false});

  final List<String> tabs;
  final TabController? controller;
  final bool isScrollable;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(AppSpacing.xxs),
        decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: AppRadius.brMd),
        child: TabBar(
          controller: controller,
          isScrollable: isScrollable,
          tabAlignment: isScrollable ? TabAlignment.start : TabAlignment.fill,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: c.primary,
          unselectedLabelColor: c.textSecondary,
          labelStyle: context.text.labelMedium,
          indicator: BoxDecoration(
            color: c.surface,
            borderRadius: AppRadius.brSm,
            boxShadow: AppShadows.soft(context.brightness),
          ),
          tabs: [for (final t in tabs) Tab(text: t)],
        ),
      ),
    );
  }
}
