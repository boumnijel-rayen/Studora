import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';

/// Session utilisateur simulée.
///
/// - Écrite par le module **Auth** (connexion, inscription, déconnexion, édition du profil).
/// - Lue par tous les modules via [currentUserProvider].
class SessionNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() => null;

  void signIn(AppUser user) => state = user;
  void signOut() => state = null;
  void update(AppUser user) => state = user;
}

final sessionProvider = NotifierProvider<SessionNotifier, AppUser?>(SessionNotifier.new);

/// Utilisateur connecté (non nul une fois dans le shell).
final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(sessionProvider));

/// Indique si l'onboarding a déjà été vu (simulé en mémoire).
class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void markSeen() => state = true;
}

final onboardingSeenProvider = NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);

/// Préférences globales de l'application (modifiées depuis le Profil).
@immutable
class AppPreferences {
  const AppPreferences({
    this.themeMode = ThemeMode.light,
    this.notificationsEnabled = true,
    this.reminderMinutesBefore = 30,
    this.currency = '€',
  });

  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final int reminderMinutesBefore;
  final String currency;

  AppPreferences copyWith({
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    int? reminderMinutesBefore,
    String? currency,
  }) => AppPreferences(
    themeMode: themeMode ?? this.themeMode,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
    currency: currency ?? this.currency,
  );
}

class PreferencesNotifier extends Notifier<AppPreferences> {
  @override
  AppPreferences build() => const AppPreferences();

  void setThemeMode(ThemeMode m) => state = state.copyWith(themeMode: m);
  void setNotifications(bool v) => state = state.copyWith(notificationsEnabled: v);
  void setReminderMinutes(int m) => state = state.copyWith(reminderMinutesBefore: m);
  void setCurrency(String c) => state = state.copyWith(currency: c);
}

final preferencesProvider = NotifierProvider<PreferencesNotifier, AppPreferences>(PreferencesNotifier.new);
