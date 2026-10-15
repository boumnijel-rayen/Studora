import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../auth_routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;

  static const _slides = [
    (
      title: 'Maîtrise ton emploi du temps',
      description:
          'Retrouve tes cours, tes devoirs et tes échéances d\'examens en un clin d\'œil avec des rappels intelligents.',
      icon: Icons.calendar_month_rounded,
      color: AppColors.moduleSchedule,
    ),
    (
      title: 'Booste tes révisions',
      description:
          'Structure tes sessions avec le minuteur Pomodoro intégré et suis ta progression matière par matière.',
      icon: Icons.timer_rounded,
      color: AppColors.moduleStudy,
    ),
    (
      title: 'Collabore & réussis ensemble',
      description:
          'Échange au sein de groupes d\'étude, partage tes notes et gère même ta vie en colocation en toute sérénité.',
      icon: Icons.groups_rounded,
      color: AppColors.moduleGroups,
    ),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _finish() => context.go(AuthRoutes.login);

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _slides.length - 1;
    final slide = _slides[_currentPage];

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Bouton passer
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: isLast
                    ? const SizedBox(height: 48)
                    : TextButton(
                        onPressed: _finish,
                        child: Text('Passer', style: context.text.labelLarge?.copyWith(color: context.colors.textSecondary)),
                      ),
              ),
            ),

            // Carrousel de slides
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _slides.length,
                itemBuilder: (context, i) {
                  final item = _slides[i];
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(item.icon, size: 54, color: item.color),
                          ),
                          AppSpacing.gapLg,
                          Text(
                            item.title,
                            style: context.text.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          AppSpacing.gapSm,
                          Text(
                            item.description,
                            style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Indicateurs et actions
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (idx) => AnimatedContainer(
                        duration: AppDurations.normal,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: idx == _currentPage ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: idx == _currentPage ? slide.color : context.colors.border,
                          borderRadius: AppRadius.brFull,
                        ),
                      ),
                    ),
                  ),
                  AppSpacing.gapXl,
                  AppButton(
                    label: isLast ? 'Commencer' : 'Suivant',
                    trailingIcon: Icons.arrow_forward_rounded,
                    expand: true,
                    onPressed: () {
                      if (isLast) {
                        _finish();
                      } else {
                        _pageCtrl.nextPage(
                          duration: AppDurations.normal,
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
