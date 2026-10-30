import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../auth_routes.dart';

/// Splash : restaure la session JWT auprès de Strapi, puis redirige vers
/// l'accueil, la connexion ou l'onboarding.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final minDelay = Future<void>.delayed(const Duration(milliseconds: 900));
    try {
      await ref.read(sessionProvider.notifier).restoreSession();
    } catch (_) {
      // Si hors-ligne au démarrage, redirige vers login
    }
    await minDelay;
    if (!mounted) return;
    final seen = ref.read(onboardingSeenProvider);
    final user = ref.read(sessionProvider);
    context.go(user != null ? '/home' : (seen ? AuthRoutes.login : AuthRoutes.onboarding));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      alignment: Alignment.center,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.6, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.elasticOut,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: AppRadius.brXl,
              ),
              child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 48),
            ),
            AppSpacing.gapMd,
            Text('Studora', style: context.text.displayMedium?.copyWith(color: Colors.white)),
            AppSpacing.gapXxs,
            Text(
              'Organise tes études, simplement.',
              style: context.text.bodyLarge?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    ),
  );
}
