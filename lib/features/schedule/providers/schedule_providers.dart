import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/schedule_models.dart';

/// Gestionnaire des cours connecté à Strapi (`/api/courses`).
class CoursesAsyncNotifier extends AsyncNotifier<List<Course>> {
  @override
  Future<List<Course>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];

    final client = ref.read(strapiClientProvider);
    final items = await client.getList('/courses');
    return items.map(Course.fromJson).toList();
  }

  Future<Course> add(Course course) async {
    final client = ref.read(strapiClientProvider);
    final response = await client.post('/courses', body: course.toJson());
    final created = Course.fromJson(StrapiClient.unwrapMap(response)).copyWith(
      subjectId: course.subjectId,
    );
    final current = state.asData?.value ?? const <Course>[];
    state = AsyncData([...current, created]);
    return created;
  }

  Future<Course> updateCourse(Course course) async {
    final client = ref.read(strapiClientProvider);
    final response = await client.put('/courses/${course.id}', body: course.toJson());
    final updated = Course.fromJson(StrapiClient.unwrapMap(response)).copyWith(
      subjectId: course.subjectId,
    );
    final current = state.asData?.value ?? const <Course>[];
    state = AsyncData([
      for (final c in current) c.id == course.id ? updated : c,
    ]);
    return updated;
  }

  Future<void> delete(String id) async {
    final client = ref.read(strapiClientProvider);
    await client.delete('/courses/$id');
    final current = state.asData?.value ?? const <Course>[];
    state = AsyncData(current.where((c) => c.id != id).toList());
  }
}

final coursesAsyncProvider =
    AsyncNotifierProvider<CoursesAsyncNotifier, List<Course>>(CoursesAsyncNotifier.new);

final coursesProvider = Provider<List<Course>>(
  (ref) => ref.watch(coursesAsyncProvider).asData?.value ?? const [],
);

/// Gestionnaire des échéances (examens, devoirs, projets) connecté à Strapi (`/api/deadlines`).
class DeadlinesAsyncNotifier extends AsyncNotifier<List<Deadline>> {
  @override
  Future<List<Deadline>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];

    final client = ref.read(strapiClientProvider);
    final items = await client.getList('/deadlines');
    return items.map(Deadline.fromJson).toList();
  }

  Future<Deadline> add(Deadline deadline) async {
    final client = ref.read(strapiClientProvider);
    final response = await client.post('/deadlines', body: deadline.toJson());
    final created = Deadline.fromJson(StrapiClient.unwrapMap(response)).copyWith(
      subjectId: deadline.subjectId,
    );
    final current = state.asData?.value ?? const <Deadline>[];
    state = AsyncData([...current, created]);
    return created;
  }

  Future<void> toggleCompleted(String id) async {
    final current = state.asData?.value ?? const <Deadline>[];
    final target = current.where((d) => d.id == id).firstOrNull;
    if (target == null) return;

    final nextStatus = !target.isCompleted;
    final client = ref.read(strapiClientProvider);
    await client.put('/deadlines/$id', body: {'isCompleted': nextStatus});

    state = AsyncData([
      for (final d in current)
        if (d.id == id) d.copyWith(isCompleted: nextStatus) else d,
    ]);
  }

  Future<Deadline> updateDeadline(Deadline deadline) async {
    final client = ref.read(strapiClientProvider);
    final response = await client.put('/deadlines/${deadline.id}', body: deadline.toJson());
    final updated = Deadline.fromJson(StrapiClient.unwrapMap(response)).copyWith(
      subjectId: deadline.subjectId,
    );
    final current = state.asData?.value ?? const <Deadline>[];
    state = AsyncData([
      for (final d in current) d.id == deadline.id ? updated : d,
    ]);
    return updated;
  }

  Future<void> delete(String id) async {
    final client = ref.read(strapiClientProvider);
    await client.delete('/deadlines/$id');
    final current = state.asData?.value ?? const <Deadline>[];
    state = AsyncData(current.where((d) => d.id != id).toList());
  }
}

final deadlinesAsyncProvider =
    AsyncNotifierProvider<DeadlinesAsyncNotifier, List<Deadline>>(DeadlinesAsyncNotifier.new);

final deadlinesProvider = Provider<List<Deadline>>(
  (ref) => ref.watch(deadlinesAsyncProvider).asData?.value ?? const [],
);

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
