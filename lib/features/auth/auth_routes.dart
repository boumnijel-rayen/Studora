/// Chemins des routes du module Auth & Profil (Membre 1).
abstract final class AuthRoutes {
  static const splash = '/splash';
  static const onboarding = '/auth/onboarding';
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const forgotPassword = '/auth/forgot-password';

  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const settings = '/profile/settings';

  /// Routes accessibles sans être connecté.
  static bool isPublic(String location) =>
      location == splash || location.startsWith('/auth');
}
