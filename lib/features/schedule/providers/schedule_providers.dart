import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/schedule_models.dart';

/// Données fictives réalistes pour l'emploi du temps.
final _initialCourses = [
  const Course(
    id: 'c-1',
    subjectId: 's-math',
    subjectName: 'Mathématiques',
    room: 'Amphi B',
    teacher: 'Mme Laurent',
    dayOfWeek: 1, // Lundi
    startTime: TimeOfDay(hour: 8, minute: 30),
    endTime: TimeOfDay(hour: 10, minute: 30),
    colorIndex: 0,
    notes: 'Chapitre sur les séries entières et transformées de Fourier.',
  ),
  const Course(
    id: 'c-2',
    subjectId: 's-algo',
    subjectName: 'Algorithmique',
    room: 'Salle TP 204',
    teacher: 'M. Garcia',
    dayOfWeek: 1,
    startTime: TimeOfDay(hour: 10, minute: 45),
    endTime: TimeOfDay(hour: 12, minute: 45),
    colorIndex: 3,
    notes: 'Complexité des algorithmes de tri et arbres binaires.',
  ),
  const Course(
    id: 'c-3',
    subjectId: 's-mobile',
    subjectName: 'Développement mobile',
    room: 'Lab Informatique 3',
    teacher: 'M. Nguyen',
    dayOfWeek: 2, // Mardi
    startTime: TimeOfDay(hour: 14, minute: 0),
    endTime: TimeOfDay(hour: 17, minute: 0),
    colorIndex: 2,
    notes: 'Projet Flutter : mise en place de Riverpod et de la navigation.',
  ),
  const Course(
    id: 'c-4',
    subjectId: 's-bdd',
    subjectName: 'Bases de données',
    room: 'Amphi A',
    teacher: 'Mme Dubois',
    dayOfWeek: 3, // Mercredi
    startTime: TimeOfDay(hour: 9, minute: 0),
    endTime: TimeOfDay(hour: 11, minute: 0),
    colorIndex: 5,
    notes: 'Normalisation 3NF et requêtes SQL complexes.',
  ),
  const Course(
    id: 'c-5',
    subjectId: 's-anglais',
    subjectName: 'Anglais',
    room: 'Salle 102',
    teacher: 'Mrs Smith',
    dayOfWeek: 4, // Jeudi
    startTime: TimeOfDay(hour: 11, minute: 0),
    endTime: TimeOfDay(hour: 12, minute: 30),
    colorIndex: 4,
    notes: 'Oral presentation preparation on tech trends.',
  ),
  const Course(
    id: 'c-6',
    subjectId: 's-reseau',
    subjectName: 'Réseaux',
    room: 'Salle TP 108',
    teacher: 'M. Martin',
    dayOfWeek: 5, // Vendredi
    startTime: TimeOfDay(hour: 8, minute: 30),
    endTime: TimeOfDay(hour: 10, minute: 30),
    colorIndex: 6,
    notes: 'Modèle OSI, protocoles TCP/UDP et routage IP.',
  ),
];

final _initialDeadlines = [
  Deadline(
    id: 'd-1',
    title: 'Partiel de Mathématiques',
    subjectId: 's-math',
    subjectName: 'Mathématiques',
    dueDate: DateTime.now().add(const Duration(days: 1, hours: 2)),
    type: DeadlineType.exam,
    priority: Priority.high,
    description: 'Calculatrice interdite. Réviser chapitres 1 à 4.',
  ),
  Deadline(
    id: 'd-2',
    title: 'Rendu Projet Flutter (Frontend)',
    subjectId: 's-mobile',
    subjectName: 'Développement mobile',
    dueDate: DateTime.now().add(const Duration(days: 3, hours: 6)),
    type: DeadlineType.project,
    priority: Priority.high,
    description: 'Dépôt GitHub du code source et maquettes Figma.',
  ),
  Deadline(
    id: 'd-3',
    title: 'Devoir maison Algorithmique',
    subjectId: 's-algo',
    subjectName: 'Algorithmique',
    dueDate: DateTime.now().add(const Duration(days: 5)),
    type: DeadlineType.homework,
    priority: Priority.medium,
    description: 'Exercices 3, 4 et 5 de la feuille de TD n°2.',
  ),
  Deadline(
    id: 'd-4',
    title: 'TP Noté Bases de données',
    subjectId: 's-bdd',
    subjectName: 'Bases de données',
    dueDate: DateTime.now().add(const Duration(days: 8)),
    type: DeadlineType.exam,
    priority: Priority.medium,
    description: 'Écriture de scripts PostgreSQL sous pgAdmin.',
  ),
];

class CoursesNotifier extends Notifier<List<Course>> {
  @override
  List<Course> build() => _initialCourses;

  void add(Course course) => state = [...state, course];
  void updateCourse(Course course) =>
      state = [for (final c in state) c.id == course.id ? course : c];
  void delete(String id) => state = state.where((c) => c.id != id).toList();
}

final coursesProvider = NotifierProvider<CoursesNotifier, List<Course>>(CoursesNotifier.new);

class DeadlinesNotifier extends Notifier<List<Deadline>> {
  @override
  List<Deadline> build() => _initialDeadlines;

  void add(Deadline deadline) => state = [...state, deadline];

  void toggleCompleted(String id) {
    state = [
      for (final d in state)
        if (d.id == id) d.copyWith(isCompleted: !d.isCompleted) else d,
    ];
  }

  void updateDeadline(Deadline deadline) =>
      state = [for (final d in state) d.id == deadline.id ? deadline : d];

  void delete(String id) => state = state.where((d) => d.id != id).toList();
}

final deadlinesProvider = NotifierProvider<DeadlinesNotifier, List<Deadline>>(DeadlinesNotifier.new);

/// Cours du jour d'aujourd'hui
final todayCoursesProvider = Provider<List<Course>>((ref) {
  final todayWeekday = DateTime.now().weekday;
  final all = ref.watch(coursesProvider);
  return all.where((c) => c.dayOfWeek == todayWeekday).toList();
});

/// Échéances à venir non complétées triées par date
final upcomingDeadlinesProvider = Provider<List<Deadline>>((ref) {
  final all = ref.watch(deadlinesProvider);
  final uncompleted = all.where((d) => !d.isCompleted).toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  return uncompleted;
});
