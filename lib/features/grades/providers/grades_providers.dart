import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/grade_models.dart';

/// Notes connectées à Strapi (`/api/grades`).
class GradesAsyncNotifier extends AsyncNotifier<List<Grade>> {
  @override
  Future<List<Grade>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];

    final client = ref.read(strapiClientProvider);
    final items = await client.getList(
      '/grades',
      queryParameters: {'sort': 'date:desc'},
    );
    return items.map(Grade.fromJson).toList();
  }

  Future<Grade> add(Grade grade) async {
    final client = ref.read(strapiClientProvider);
    final response = await client.post('/grades', body: grade.toJson());
    final created = Grade.fromJson(StrapiClient.unwrapMap(response));
    final current = state.asData?.value ?? const <Grade>[];
    state = AsyncData([created, ...current]);
    return created;
  }

  Future<void> delete(String id) async {
    final client = ref.read(strapiClientProvider);
    await client.delete('/grades/$id');
    final current = state.asData?.value ?? const <Grade>[];
    state = AsyncData(current.where((g) => g.id != id).toList());
  }
}

final gradesAsyncProvider =
    AsyncNotifierProvider<GradesAsyncNotifier, List<Grade>>(GradesAsyncNotifier.new);

final gradesProvider = Provider<List<Grade>>(
  (ref) => ref.watch(gradesAsyncProvider).asData?.value ?? const [],
);

/// Objectifs académiques connectés à Strapi (`/api/academic-goals`).
class AcademicGoalsAsyncNotifier extends AsyncNotifier<List<AcademicGoal>> {
  @override
  Future<List<AcademicGoal>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];

    final client = ref.read(strapiClientProvider);
    final items = await client.getList('/academic-goals');
    return items.map(AcademicGoal.fromJson).toList();
  }

  Future<AcademicGoal> add(AcademicGoal goal) async {
    final client = ref.read(strapiClientProvider);
    final response = await client.post('/academic-goals', body: goal.toJson());
    final created = AcademicGoal.fromJson(StrapiClient.unwrapMap(response));
    final current = state.asData?.value ?? const <AcademicGoal>[];
    state = AsyncData([...current, created]);
    return created;
  }

  Future<void> delete(String id) async {
    final client = ref.read(strapiClientProvider);
    await client.delete('/academic-goals/$id');
    final current = state.asData?.value ?? const <AcademicGoal>[];
    state = AsyncData(current.where((g) => g.id != id).toList());
  }
}

final academicGoalsAsyncProvider =
    AsyncNotifierProvider<AcademicGoalsAsyncNotifier, List<AcademicGoal>>(
      AcademicGoalsAsyncNotifier.new,
    );

final academicGoalsProvider = Provider<List<AcademicGoal>>(
  (ref) => ref.watch(academicGoalsAsyncProvider).asData?.value ?? const [],
);

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
