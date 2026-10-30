import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/study_models.dart';

/// Sessions de révision connectées à Strapi (`/api/study-sessions`).
class StudySessionsAsyncNotifier extends AsyncNotifier<List<StudySession>> {
  @override
  Future<List<StudySession>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];

    final client = ref.read(strapiClientProvider);
    final items = await client.getList(
      '/study-sessions',
      queryParameters: {'sort': 'date:desc'},
    );
    return items.map(StudySession.fromJson).toList();
  }

  Future<StudySession> add(StudySession session) async {
    final client = ref.read(strapiClientProvider);
    final response = await client.post('/study-sessions', body: session.toJson());
    final created = StudySession.fromJson(StrapiClient.unwrapMap(response));
    final current = state.asData?.value ?? const <StudySession>[];
    state = AsyncData([created, ...current]);
    return created;
  }

  Future<void> toggleCompleted(String id) async {
    final current = state.asData?.value ?? const <StudySession>[];
    final target = current.where((s) => s.id == id).firstOrNull;
    if (target == null) return;

    final next = !target.isCompleted;
    final client = ref.read(strapiClientProvider);
    await client.put('/study-sessions/$id', body: {'isCompleted': next});

    state = AsyncData([
      for (final s in current)
        if (s.id == id) s.copyWith(isCompleted: next) else s,
    ]);
  }

  Future<void> delete(String id) async {
    final client = ref.read(strapiClientProvider);
    await client.delete('/study-sessions/$id');
    final current = state.asData?.value ?? const <StudySession>[];
    state = AsyncData(current.where((s) => s.id != id).toList());
  }
}

final studySessionsAsyncProvider =
    AsyncNotifierProvider<StudySessionsAsyncNotifier, List<StudySession>>(
      StudySessionsAsyncNotifier.new,
    );

final studySessionsProvider = Provider<List<StudySession>>(
  (ref) => ref.watch(studySessionsAsyncProvider).asData?.value ?? const [],
);

/// Tâches par matière connectées à Strapi (`/api/study-tasks`).
class StudyTasksAsyncNotifier extends AsyncNotifier<List<StudyTask>> {
  @override
  Future<List<StudyTask>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];

    final client = ref.read(strapiClientProvider);
    final items = await client.getList('/study-tasks');
    return items.map(StudyTask.fromJson).toList();
  }

  Future<StudyTask> add(StudyTask task) async {
    final client = ref.read(strapiClientProvider);
    final response = await client.post('/study-tasks', body: task.toJson());
    final created = StudyTask.fromJson(StrapiClient.unwrapMap(response));
    final current = state.asData?.value ?? const <StudyTask>[];
    state = AsyncData([...current, created]);
    return created;
  }

  Future<void> toggle(String id) async {
    final current = state.asData?.value ?? const <StudyTask>[];
    final target = current.where((t) => t.id == id).firstOrNull;
    if (target == null) return;

    final next = !target.isCompleted;
    final client = ref.read(strapiClientProvider);
    await client.put('/study-tasks/$id', body: {'isCompleted': next});

    state = AsyncData([
      for (final t in current)
        if (t.id == id) t.copyWith(isCompleted: next) else t,
    ]);
  }

  Future<void> updateTask(StudyTask updated) async {
    final client = ref.read(strapiClientProvider);
    final response = await client.put('/study-tasks/${updated.id}', body: updated.toJson());
    final saved = StudyTask.fromJson(StrapiClient.unwrapMap(response));
    final current = state.asData?.value ?? const <StudyTask>[];
    state = AsyncData([
      for (final t in current)
        if (t.id == updated.id) saved else t,
    ]);
  }

  Future<void> delete(String id) async {
    final client = ref.read(strapiClientProvider);
    await client.delete('/study-tasks/$id');
    final current = state.asData?.value ?? const <StudyTask>[];
    state = AsyncData(current.where((t) => t.id != id).toList());
  }
}

final studyTasksAsyncProvider =
    AsyncNotifierProvider<StudyTasksAsyncNotifier, List<StudyTask>>(StudyTasksAsyncNotifier.new);

final studyTasksProvider = Provider<List<StudyTask>>(
  (ref) => ref.watch(studyTasksAsyncProvider).asData?.value ?? const [],
);

/// Configuration Pomodoro synchronisée avec les préférences utilisateur Strapi.
class PomodoroConfigNotifier extends Notifier<PomodoroConfig> {
  @override
  PomodoroConfig build() {
    final prefs = ref.watch(preferencesProvider);
    return PomodoroConfig(
      workMinutes: prefs.pomodoroWorkMinutes,
      shortBreakMinutes: prefs.pomodoroShortBreakMinutes,
      longBreakMinutes: prefs.pomodoroLongBreakMinutes,
      sessionsBeforeLongBreak: prefs.pomodoroSessionsBeforeLongBreak,
      autoStartBreaks: prefs.pomodoroAutoStartBreaks,
    );
  }

  Future<void> update(PomodoroConfig config) async {
    state = config;
    await ref.read(preferencesProvider.notifier).updatePomodoroPreferences(
      workMinutes: config.workMinutes,
      shortBreakMinutes: config.shortBreakMinutes,
      longBreakMinutes: config.longBreakMinutes,
      sessionsBeforeLongBreak: config.sessionsBeforeLongBreak,
      autoStartBreaks: config.autoStartBreaks,
    );
  }
}

final pomodoroConfigProvider =
    NotifierProvider<PomodoroConfigNotifier, PomodoroConfig>(PomodoroConfigNotifier.new);

/// Statistiques de révision calculées à partir des sessions réelles du backend.
final todayStudyStatsProvider = Provider<(int minutesToday, int sessionsCompleted)>((ref) {
  final sessions = ref.watch(studySessionsProvider);
  final completed = sessions.where((s) => s.isCompleted).toList();
  final totalMin = completed.fold<int>(0, (acc, s) => acc + s.durationMinutes);
  return (totalMin, completed.length);
});
