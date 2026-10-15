import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/study_models.dart';

final _initialSessions = [
  StudySession(
    id: 's-1',
    subjectId: 's-math',
    subjectName: 'Mathématiques',
    durationMinutes: 50,
    date: DateTime.now().subtract(const Duration(hours: 3)),
    colorIndex: 0,
    notes: 'Révision des équations différentielles et théorèmes clés.',
    isCompleted: true,
    linkedDeadlineTitle: 'Partiel de Mathématiques',
  ),
  StudySession(
    id: 's-2',
    subjectId: 's-algo',
    subjectName: 'Algorithmique',
    durationMinutes: 45,
    date: DateTime.now().add(const Duration(hours: 4)),
    colorIndex: 3,
    notes: 'Arbres AVL, rotations gauche-droite et algorithme de Dijkstra.',
    isCompleted: false,
    linkedDeadlineTitle: 'Devoir maison Algorithmique',
  ),
  StudySession(
    id: 's-3',
    subjectId: 's-mobile',
    subjectName: 'Développement mobile',
    durationMinutes: 60,
    date: DateTime.now().add(const Duration(days: 1)),
    colorIndex: 2,
    notes: 'Composants Flutter, gestion d\'état Riverpod et GoRouter.',
    isCompleted: false,
    linkedDeadlineTitle: 'Rendu Projet Flutter',
  ),
];

final _initialTasks = [
  const StudyTask(id: 't-1', subjectId: 's-math', title: 'Refaire l\'exercice 2 du TD 3', isCompleted: true),
  const StudyTask(id: 't-2', subjectId: 's-math', title: 'Apprendre la formule de Taylor-Lagrange', isCompleted: false),
  const StudyTask(id: 't-3', subjectId: 's-algo', title: 'Implémenter le parcours en largeur (BFS)', isCompleted: false),
  const StudyTask(id: 't-4', subjectId: 's-algo', title: 'Calculer la complexité asymptotique de QuickSort', isCompleted: true),
  const StudyTask(id: 't-5', subjectId: 's-mobile', title: 'Créer les widgets réutilisables du Design System', isCompleted: true),
  const StudyTask(id: 't-6', subjectId: 's-mobile', title: 'Mettre en place la navigation adaptative', isCompleted: false),
  const StudyTask(id: 't-7', subjectId: 's-bdd', title: 'Schéma relationnel et clés étrangères', isCompleted: false),
];

class StudySessionsNotifier extends Notifier<List<StudySession>> {
  @override
  List<StudySession> build() => _initialSessions;

  void add(StudySession session) => state = [session, ...state];

  void toggleCompleted(String id) {
    state = [
      for (final s in state)
        if (s.id == id) s.copyWith(isCompleted: !s.isCompleted) else s,
    ];
  }

  void delete(String id) => state = state.where((s) => s.id != id).toList();
}

final studySessionsProvider =
    NotifierProvider<StudySessionsNotifier, List<StudySession>>(StudySessionsNotifier.new);

class StudyTasksNotifier extends Notifier<List<StudyTask>> {
  @override
  List<StudyTask> build() => _initialTasks;

  void add(StudyTask task) => state = [...state, task];

  void toggle(String id) {
    state = [
      for (final t in state)
        if (t.id == id) t.copyWith(isCompleted: !t.isCompleted) else t,
    ];
  }

  void delete(String id) => state = state.where((t) => t.id != id).toList();
}

final studyTasksProvider =
    NotifierProvider<StudyTasksNotifier, List<StudyTask>>(StudyTasksNotifier.new);

class PomodoroConfigNotifier extends Notifier<PomodoroConfig> {
  @override
  PomodoroConfig build() => const PomodoroConfig();

  void update(PomodoroConfig config) => state = config;
}

final pomodoroConfigProvider =
    NotifierProvider<PomodoroConfigNotifier, PomodoroConfig>(PomodoroConfigNotifier.new);

/// Statistiques de révision pour le tableau de bord
final todayStudyStatsProvider = Provider<(int minutesToday, int sessionsCompleted)>((ref) {
  final sessions = ref.watch(studySessionsProvider);
  final completed = sessions.where((s) => s.isCompleted).toList();
  final totalMin = completed.fold<int>(0, (acc, s) => acc + s.durationMinutes);
  return (totalMin, completed.length);
});
