import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/core.dart';
import 'auth_routes.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/register_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';

/// Module 1 — Utilisateurs & Profil (Membre 1 / Lead).
class AuthModule extends FeatureModule {
  const AuthModule();

  @override
  String get id => 'auth';

  @override
  ModuleEntry get entry => const ModuleEntry(
    label: 'Profil',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
    color: AppColors.moduleProfile,
    rootPath: AuthRoutes.profile,
    placement: ModulePlacement.more,
    order: 90,
    description: 'Informations personnelles et préférences',
  );

  @override
  List<RouteBase> get fullscreenRoutes => [
    GoRoute(path: AuthRoutes.splash, builder: (_, _) => const SplashScreen()),
    GoRoute(path: AuthRoutes.onboarding, builder: (_, _) => const OnboardingScreen()),
    GoRoute(path: AuthRoutes.login, builder: (_, _) => const LoginScreen()),
    GoRoute(path: AuthRoutes.register, builder: (_, _) => const RegisterScreen()),
    GoRoute(path: AuthRoutes.forgotPassword, builder: (_, _) => const ForgotPasswordScreen()),
  ];

  @override
  List<RouteBase> get shellRoutes => [
    GoRoute(
      path: AuthRoutes.profile,
      builder: (_, _) => const ProfileScreen(),
      routes: [
        GoRoute(
          path: 'edit',
          parentNavigatorKey: AppNavigator.rootKey,
          builder: (_, _) => const EditProfileScreen(),
        ),
        GoRoute(
          path: 'settings',
          builder: (_, _) => const SettingsScreen(),
        ),
      ],
    ),
  ];
}
