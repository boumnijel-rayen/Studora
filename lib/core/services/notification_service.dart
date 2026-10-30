import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system/tokens/app_colors.dart';
import '../network/strapi_client.dart';
import 'session_service.dart';

/// Catégorie de notification (détermine icône et couleur).
enum NotificationCategory {
  course(Icons.class_rounded, AppColors.moduleSchedule),
  deadline(Icons.alarm_rounded, AppColors.error),
  study(Icons.timer_rounded, AppColors.moduleStudy),
  group(Icons.forum_rounded, AppColors.moduleGroups),
  grade(Icons.insights_rounded, AppColors.moduleGrades),
  roommate(Icons.home_rounded, AppColors.moduleRoommates),
  system(Icons.notifications_rounded, AppColors.primary);

  const NotificationCategory(this.icon, this.color);
  final IconData icon;
  final Color color;

  static NotificationCategory fromString(String value) => switch (value) {
    'course' => NotificationCategory.course,
    'deadline' => NotificationCategory.deadline,
    'study' => NotificationCategory.study,
    'group' => NotificationCategory.group,
    'grade' => NotificationCategory.grade,
    'roommate' => NotificationCategory.roommate,
    _ => NotificationCategory.system,
  };
}

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    required this.category,
    this.read = false,
    this.route,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: (json['id'] ?? json['documentId'] ?? '').toString(),
    title: (json['title'] ?? '').toString(),
    body: (json['body'] ?? '').toString(),
    date: DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now(),
    category: NotificationCategory.fromString((json['category'] ?? 'system').toString()),
    read: json['read'] == true,
    route: json['route']?.toString(),
  );

  final String id;
  final String title;
  final String body;
  final DateTime date;
  final NotificationCategory category;
  final bool read;

  /// Route à ouvrir au toucher (optionnelle).
  final String? route;

  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'date': date.toUtc().toIso8601String(),
    'category': category.name,
    'read': read,
    if (route != null) 'route': route,
  };

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    title: title,
    body: body,
    date: date,
    category: category,
    read: read ?? this.read,
    route: route,
  );
}

/// Gestionnaire des notifications connecté à Strapi (`/api/app-notifications`).
class NotificationsAsyncNotifier extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];

    final client = ref.read(strapiClientProvider);
    final list = await client.getList(
      '/app-notifications',
      queryParameters: {'sort': 'date:desc'},
    );
    return list.map(AppNotification.fromJson).toList();
  }

  Future<AppNotification> push({
    required String title,
    required String body,
    required NotificationCategory category,
    String? route,
  }) async {
    final client = ref.read(strapiClientProvider);
    final response = await client.post(
      '/app-notifications',
      body: {
        'title': title,
        'body': body,
        'date': DateTime.now().toUtc().toIso8601String(),
        'category': category.name,
        'read': false,
        if (route != null) 'route': route,
      },
    );
    final created = AppNotification.fromJson(StrapiClient.unwrapMap(response));
    final current = state.asData?.value ?? const <AppNotification>[];
    state = AsyncData([created, ...current]);
    return created;
  }

  Future<void> markRead(String id) async {
    final client = ref.read(strapiClientProvider);
    await client.put('/app-notifications/$id', body: {'read': true});
    final current = state.asData?.value ?? const <AppNotification>[];
    state = AsyncData([
      for (final n in current) n.id == id ? n.copyWith(read: true) : n,
    ]);
  }

  Future<void> markAllRead() async {
    final client = ref.read(strapiClientProvider);
    await client.post('/app-notifications/mark-all-read', body: const {});
    final current = state.asData?.value ?? const <AppNotification>[];
    state = AsyncData([
      for (final n in current) n.copyWith(read: true),
    ]);
  }

  Future<void> remove(String id) async {
    final client = ref.read(strapiClientProvider);
    await client.delete('/app-notifications/$id');
    final current = state.asData?.value ?? const <AppNotification>[];
    state = AsyncData(current.where((n) => n.id != id).toList());
  }
}

final notificationsAsyncProvider =
    AsyncNotifierProvider<NotificationsAsyncNotifier, List<AppNotification>>(
      NotificationsAsyncNotifier.new,
    );

final notificationsProvider = Provider<List<AppNotification>>(
  (ref) => ref.watch(notificationsAsyncProvider).asData?.value ?? const [],
);

final unreadNotificationsCountProvider = Provider<int>(
  (ref) => ref.watch(notificationsProvider).where((n) => !n.read).length,
);
