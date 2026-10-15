import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/grade_models.dart';

final _initialGrades = [
  Grade(
    id: 'gr-1',
    subjectId: 's-math',
    subjectName: 'Mathématiques',
    title: 'Contrôle continu 1',
    value: 13.5,
    coefficient: 1.0,
    date: DateTime.now().subtract(const Duration(days: 20)),
  ),
  Grade(
    id: 'gr-2',
    subjectId: 's-math',
    subjectName: 'Mathématiques',
    title: 'Devoir surveillé',
    value: 15.0,
    coefficient: 2.0,
    date: DateTime.now().subtract(const Duration(days: 5)),
  ),
  Grade(
    id: 'gr-3',
    subjectId: 's-algo',
    subjectName: 'Algorithmique',
    title: 'TP Noté Arbres & Graphes',
    value: 16.5,
    coefficient: 1.5,
    date: DateTime.now().subtract(const Duration(days: 12)),
  ),
  Grade(
    id: 'gr-4',
    subjectId: 's-mobile',
    subjectName: 'Développement mobile',
    title: 'Projet Flutter Sprint 1',
    value: 17.0,
    coefficient: 2.0,
    date: DateTime.now().subtract(const Duration(days: 8)),
  ),
  Grade(
    id: 'gr-5',
    subjectId: 's-bdd',
    subjectName: 'Bases de données',
    title: 'Interrogation SQL',
    value: 12.0,
    coefficient: 1.0,
    date: DateTime.now().subtract(const Duration(days: 15)),
  ),
  Grade(
    id: 'gr-6',
    subjectId: 's-anglais',
    subjectName: 'Anglais',
    title: 'Présentation orale',
    value: 14.0,
    coefficient: 1.0,
    date: DateTime.now().subtract(const Duration(days: 18)),
  ),
];

final _initialGoals = [
  const AcademicGoal(
    id: 'goal-1',
    title: 'Mention Bien au semestre',
    targetAverage: 14.0,
    subjectName: 'Moyenne Générale',
  ),
  const AcademicGoal(
    id: 'goal-2',
    title: 'Valider les Maths au-dessus de 14',
    targetAverage: 14.5,
    subjectName: 'Mathématiques',
    subjectId: 's-math',
  ),
  const AcademicGoal(
    id: 'goal-3',
    title: 'Excellence en Dév Mobile',
    targetAverage: 16.0,
    subjectName: 'Développement mobile',
    subjectId: 's-mobile',
  ),
];

class GradesNotifier extends Notifier<List<Grade>> {
  @override
  List<Grade> build() => _initialGrades;

  void add(Grade grade) => state = [grade, ...state];

  void delete(String id) => state = state.where((g) => g.id != id).toList();
}

final gradesProvider = NotifierProvider<GradesNotifier, List<Grade>>(GradesNotifier.new);

class AcademicGoalsNotifier extends Notifier<List<AcademicGoal>> {
  @override
  List<AcademicGoal> build() => _initialGoals;

  void add(AcademicGoal goal) => state = [...state, goal];
  void delete(String id) => state = state.where((g) => g.id != id).toList();
}

final academicGoalsProvider =
    NotifierProvider<AcademicGoalsNotifier, List<AcademicGoal>>(AcademicGoalsNotifier.new);

/// Calcul automatique de la moyenne générale pondérée
final overallAverageProvider = Provider<double>((ref) {
  final grades = ref.watch(gradesProvider);
  if (grades.isEmpty) return 0.0;

  double totalPoints = 0;
  double totalCoeffs = 0;

  for (final g in grades) {
    totalPoints += g.value * g.coefficient;
    totalCoeffs += g.coefficient;
  }

  return totalCoeffs > 0 ? (totalPoints / totalCoeffs) : 0.0;
});

/// Calcul des moyennes par matière
final subjectAveragesProvider = Provider<Map<String, double>>((ref) {
  final grades = ref.watch(gradesProvider);
  final map = <String, (double points, double coeffs)>{};

  for (final g in grades) {
    final cur = map[g.subjectId] ?? (0.0, 0.0);
    map[g.subjectId] = (cur.$1 + g.value * g.coefficient, cur.$2 + g.coefficient);
  }

  return map.map((key, val) => MapEntry(key, val.$2 > 0 ? val.$1 / val.$2 : 0.0));
});
