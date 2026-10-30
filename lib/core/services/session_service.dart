import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../network/api_exception.dart';
import '../network/strapi_client.dart';

/// Paramètres globaux de l'application récupérés depuis `/api/app-setting`
/// (séparés des préférences individuelles de l'utilisateur).
@immutable
class GlobalAppSettings {
  const GlobalAppSettings({
    this.appName = 'Studora',
    this.appVersion = '1.0.0',
    this.supportEmail = 'support@studora.app',
    this.maintenanceMode = false,
    this.defaultCurrency = '€',
    this.defaultReminderMinutes = 30,
    this.supportedCurrencies = const ['€', 'TND', '\$'],
  });

  factory GlobalAppSettings.fromJson(Map<String, dynamic> json) {
    final rawCurrencies = json['supportedCurrencies'];
    final currencies = rawCurrencies is List
        ? rawCurrencies.map((e) => e.toString()).toList()
        : const ['€', 'TND', '\$'];

    return GlobalAppSettings(
      appName: (json['appName'] ?? 'Studora').toString(),
      appVersion: (json['appVersion'] ?? '1.0.0').toString(),
      supportEmail: (json['supportEmail'] ?? 'support@studora.app').toString(),
      maintenanceMode: json['maintenanceMode'] == true,
      defaultCurrency: (json['defaultCurrency'] ?? '€').toString(),
      defaultReminderMinutes: (json['defaultReminderMinutes'] is num)
          ? (json['defaultReminderMinutes'] as num).toInt()
          : 30,
      supportedCurrencies: currencies.isEmpty ? const ['€', 'TND', '\$'] : currencies,
    );
  }

  final String appName;
  final String appVersion;
  final String supportEmail;
  final bool maintenanceMode;
  final String defaultCurrency;
  final int defaultReminderMinutes;
  final List<String> supportedCurrencies;
}

final globalAppSettingsProvider = FutureProvider<GlobalAppSettings>((ref) async {
  final client = ref.watch(strapiClientProvider);
  final map = await client.getMap('/app-setting', authenticated: false);
  return GlobalAppSettings.fromJson(map);
});

/// Session utilisateur connectée au backend Strapi (`/api/auth/local`, `/api/users/me`).
class SessionNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() {
    // Si un appel API signale un 401 (session expirée), on réinitialise la session.
    ref.listen<int>(sessionExpiredProvider, (previous, next) {
      if (next > (previous ?? 0)) {
        state = null;
      }
    });
    return null;
  }

  /// Restaure la session à partir du token JWT stocké localement en appelant `/api/users/me`.
  Future<AppUser?> restoreSession() async {
    final storage = ref.read(tokenStorageProvider);
    final token = await storage.readToken();
    if (token == null || token.isEmpty) {
      state = null;
      return null;
    }

    try {
      final client = ref.read(strapiClientProvider);
      final response = await client.get(
        '/users/me',
        queryParameters: {'populate': 'role'},
      );
      if (response is Map<String, dynamic>) {
        final user = AppUser.fromJson(StrapiClient.normalizeEntity(response));
        state = user;
        await ref.read(preferencesProvider.notifier).fetchFromBackend();
        return user;
      }
      await storage.clearToken();
      state = null;
      return null;
    } on ApiException catch (e) {
      if (e.isUnauthorized || e.isForbidden) {
        await storage.clearToken();
        state = null;
        return null;
      }
      rethrow;
    }
  }

  /// Authentifie l'utilisateur auprès de Strapi (`POST /api/auth/local`).
  Future<AppUser> login({
    required String identifier,
    required String password,
    bool rememberMe = true,
  }) async {
    final client = ref.read(strapiClientProvider);
    final storage = ref.read(tokenStorageProvider);

    final response = await client.post(
      '/auth/local',
      wrapData: false,
      authenticated: false,
      body: {
        'identifier': identifier.trim(),
        'password': password,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'Réponse d\'authentification Strapi invalide.',
      );
    }

    final jwt = (response['jwt'] ?? '').toString();
    final userMap = response['user'] as Map<String, dynamic>?;
    if (jwt.isEmpty || userMap == null) {
      throw const ApiException(
        kind: ApiErrorKind.unauthorized,
        message: 'Jeton d\'authentification manquant dans la réponse Strapi.',
      );
    }

    await storage.saveToken(jwt, rememberMe: rememberMe);
    var user = AppUser.fromJson(StrapiClient.normalizeEntity(userMap));

    // Récupère le profil complet avec rôle depuis /api/users/me
    try {
      final meResponse = await client.get('/users/me', queryParameters: {'populate': 'role'});
      if (meResponse is Map<String, dynamic>) {
        user = AppUser.fromJson(StrapiClient.normalizeEntity(meResponse));
      }
    } catch (_) {
      // Conserve l'objet user retourné par /auth/local si /users/me n'est pas enrichi
    }

    state = user;
    await ref.read(preferencesProvider.notifier).fetchFromBackend();
    return user;
  }

  /// Inscrit un nouvel utilisateur sur Strapi (`POST /api/auth/local/register`).
  Future<AppUser> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String phone = '',
    String university = '',
    String program = '',
    int year = 1,
  }) async {
    final client = ref.read(strapiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final normalizedEmail = email.trim().toLowerCase();

    final response = await client.post(
      '/auth/local/register',
      wrapData: false,
      authenticated: false,
      body: {
        'username': normalizedEmail,
        'email': normalizedEmail,
        'password': password,
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'phone': phone.trim(),
        'university': university.trim(),
        'program': program.trim(),
        'year': year,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw const ApiException(
        kind: ApiErrorKind.unknown,
        message: 'Réponse d\'inscription Strapi invalide.',
      );
    }

    final jwt = (response['jwt'] ?? '').toString();
    final userMap = response['user'] as Map<String, dynamic>?;
    if (jwt.isEmpty || userMap == null) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Impossible de finaliser l\'inscription.',
      );
    }

    await storage.saveToken(jwt, rememberMe: true);
    var user = AppUser.fromJson(StrapiClient.normalizeEntity(userMap)).copyWith(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      phone: phone.trim(),
      university: university.trim(),
      program: program.trim(),
      year: year,
    );

    // Persiste les champs complémentaires de profil si Strapi register les a ignorés
    try {
      user = await updateProfile(user);
    } catch (_) {}

    state = user;
    await ref.read(preferencesProvider.notifier).fetchFromBackend();
    return user;
  }

  /// Demande un lien de réinitialisation de mot de passe (`POST /api/auth/forgot-password`).
  Future<void> requestPasswordReset(String email) async {
    final client = ref.read(strapiClientProvider);
    await client.post(
      '/auth/forgot-password',
      wrapData: false,
      authenticated: false,
      body: {'email': email.trim().toLowerCase()},
    );
  }

  /// Met à jour les informations personnelles sur Strapi (`PUT /api/users/me` ou `/api/users/:id`).
  Future<AppUser> updateProfile(AppUser updated) async {
    final client = ref.read(strapiClientProvider);
    dynamic response;
    try {
      response = await client.put(
        '/users/me',
        wrapData: false,
        body: updated.toJson(),
      );
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.notFound && updated.id.isNotEmpty) {
        response = await client.put(
          '/users/${updated.id}',
          wrapData: false,
          body: updated.toJson(),
        );
      } else {
        rethrow;
      }
    }

    if (response is Map<String, dynamic>) {
      final saved = AppUser.fromJson(StrapiClient.normalizeEntity(response));
      state = saved;
      return saved;
    }

    state = updated;
    return updated;
  }

  void signIn(AppUser user) => state = user;

  void update(AppUser user) => state = user;

  Future<void> signOut() async {
    await ref.read(tokenStorageProvider).clearToken();
    state = null;
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, AppUser?>(SessionNotifier.new);

/// Utilisateur connecté.
final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(sessionProvider));

/// Indique si l'onboarding a déjà été vu.
class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(preferencesProvider).onboardingSeen;

  Future<void> markSeen() async {
    await ref.read(preferencesProvider.notifier).setOnboardingSeen(true);
  }
}

final onboardingSeenProvider = NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);

/// Préférences individuelles de l'utilisateur synchronisées avec Strapi (`/api/user-preferences/me`).
@immutable
class AppPreferences {
  const AppPreferences({
    this.id,
    this.themeMode = ThemeMode.light,
    this.notificationsEnabled = true,
    this.reminderMinutesBefore = 30,
    this.currency = '€',
    this.locale = 'fr_FR',
    this.onboardingSeen = false,
    this.pomodoroWorkMinutes = 25,
    this.pomodoroShortBreakMinutes = 5,
    this.pomodoroLongBreakMinutes = 15,
    this.pomodoroSessionsBeforeLongBreak = 4,
    this.pomodoroAutoStartBreaks = false,
  });

  factory AppPreferences.fromJson(Map<String, dynamic> json) {
    final themeStr = (json['themeMode'] ?? 'light').toString();
    final themeMode = switch (themeStr) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };

    return AppPreferences(
      id: (json['id'] ?? json['documentId'])?.toString(),
      themeMode: themeMode,
      notificationsEnabled: json['notificationsEnabled'] != false,
      reminderMinutesBefore: (json['reminderMinutesBefore'] is num)
          ? (json['reminderMinutesBefore'] as num).toInt()
          : 30,
      currency: (json['currency'] ?? '€').toString(),
      locale: (json['locale'] ?? 'fr_FR').toString(),
      onboardingSeen: json['onboardingSeen'] == true,
      pomodoroWorkMinutes: (json['pomodoroWorkMinutes'] is num)
          ? (json['pomodoroWorkMinutes'] as num).toInt()
          : 25,
      pomodoroShortBreakMinutes: (json['pomodoroShortBreakMinutes'] is num)
          ? (json['pomodoroShortBreakMinutes'] as num).toInt()
          : 5,
      pomodoroLongBreakMinutes: (json['pomodoroLongBreakMinutes'] is num)
          ? (json['pomodoroLongBreakMinutes'] as num).toInt()
          : 15,
      pomodoroSessionsBeforeLongBreak: (json['pomodoroSessionsBeforeLongBreak'] is num)
          ? (json['pomodoroSessionsBeforeLongBreak'] as num).toInt()
          : 4,
      pomodoroAutoStartBreaks: json['pomodoroAutoStartBreaks'] == true,
    );
  }

  final String? id;
  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final int reminderMinutesBefore;
  final String currency;
  final String locale;
  final bool onboardingSeen;
  final int pomodoroWorkMinutes;
  final int pomodoroShortBreakMinutes;
  final int pomodoroLongBreakMinutes;
  final int pomodoroSessionsBeforeLongBreak;
  final bool pomodoroAutoStartBreaks;

  Map<String, dynamic> toJson() => {
    'themeMode': switch (themeMode) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
    },
    'notificationsEnabled': notificationsEnabled,
    'reminderMinutesBefore': reminderMinutesBefore,
    'currency': currency,
    'locale': locale,
    'onboardingSeen': onboardingSeen,
    'pomodoroWorkMinutes': pomodoroWorkMinutes,
    'pomodoroShortBreakMinutes': pomodoroShortBreakMinutes,
    'pomodoroLongBreakMinutes': pomodoroLongBreakMinutes,
    'pomodoroSessionsBeforeLongBreak': pomodoroSessionsBeforeLongBreak,
    'pomodoroAutoStartBreaks': pomodoroAutoStartBreaks,
  };

  AppPreferences copyWith({
    String? id,
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    int? reminderMinutesBefore,
    String? currency,
    String? locale,
    bool? onboardingSeen,
    int? pomodoroWorkMinutes,
    int? pomodoroShortBreakMinutes,
    int? pomodoroLongBreakMinutes,
    int? pomodoroSessionsBeforeLongBreak,
    bool? pomodoroAutoStartBreaks,
  }) => AppPreferences(
    id: id ?? this.id,
    themeMode: themeMode ?? this.themeMode,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
    currency: currency ?? this.currency,
    locale: locale ?? this.locale,
    onboardingSeen: onboardingSeen ?? this.onboardingSeen,
    pomodoroWorkMinutes: pomodoroWorkMinutes ?? this.pomodoroWorkMinutes,
    pomodoroShortBreakMinutes: pomodoroShortBreakMinutes ?? this.pomodoroShortBreakMinutes,
    pomodoroLongBreakMinutes: pomodoroLongBreakMinutes ?? this.pomodoroLongBreakMinutes,
    pomodoroSessionsBeforeLongBreak:
        pomodoroSessionsBeforeLongBreak ?? this.pomodoroSessionsBeforeLongBreak,
    pomodoroAutoStartBreaks: pomodoroAutoStartBreaks ?? this.pomodoroAutoStartBreaks,
  );
}

class PreferencesNotifier extends Notifier<AppPreferences> {
  @override
  AppPreferences build() => const AppPreferences();

  Future<AppPreferences> fetchFromBackend() async {
    final user = ref.read(sessionProvider);
    if (user == null) return state;

    try {
      final client = ref.read(strapiClientProvider);
      final map = await client.getMap('/user-preferences/me');
      final loaded = AppPreferences.fromJson(map);
      state = loaded;
      return loaded;
    } catch (_) {
      return state;
    }
  }

  Future<void> _persistPatch(Map<String, dynamic> patch) async {
    final user = ref.read(sessionProvider);
    if (user == null) return;
    final client = ref.read(strapiClientProvider);
    final response = await client.put('/user-preferences/me', body: patch);
    final updated = AppPreferences.fromJson(StrapiClient.unwrapMap(response));
    state = updated;
  }

  Future<void> setThemeMode(ThemeMode m) async {
    state = state.copyWith(themeMode: m);
    try {
      await _persistPatch({
        'themeMode': switch (m) {
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
          ThemeMode.light => 'light',
        },
      });
    } catch (_) {}
  }

  Future<void> setNotifications(bool v) async {
    state = state.copyWith(notificationsEnabled: v);
    try {
      await _persistPatch({'notificationsEnabled': v});
    } catch (_) {}
  }

  Future<void> setReminderMinutes(int m) async {
    state = state.copyWith(reminderMinutesBefore: m);
    try {
      await _persistPatch({'reminderMinutesBefore': m});
    } catch (_) {}
  }

  Future<void> setCurrency(String c) async {
    state = state.copyWith(currency: c);
    try {
      await _persistPatch({'currency': c});
    } catch (_) {}
  }

  Future<void> setOnboardingSeen(bool seen) async {
    state = state.copyWith(onboardingSeen: seen);
    try {
      await _persistPatch({'onboardingSeen': seen});
    } catch (_) {}
  }

  Future<void> updatePomodoroPreferences({
    required int workMinutes,
    required int shortBreakMinutes,
    required int longBreakMinutes,
    required int sessionsBeforeLongBreak,
    required bool autoStartBreaks,
  }) async {
    state = state.copyWith(
      pomodoroWorkMinutes: workMinutes,
      pomodoroShortBreakMinutes: shortBreakMinutes,
      pomodoroLongBreakMinutes: longBreakMinutes,
      pomodoroSessionsBeforeLongBreak: sessionsBeforeLongBreak,
      pomodoroAutoStartBreaks: autoStartBreaks,
    );
    await _persistPatch({
      'pomodoroWorkMinutes': workMinutes,
      'pomodoroShortBreakMinutes': shortBreakMinutes,
      'pomodoroLongBreakMinutes': longBreakMinutes,
      'pomodoroSessionsBeforeLongBreak': sessionsBeforeLongBreak,
      'pomodoroAutoStartBreaks': autoStartBreaks,
    });
  }
}

final preferencesProvider = NotifierProvider<PreferencesNotifier, AppPreferences>(PreferencesNotifier.new);
