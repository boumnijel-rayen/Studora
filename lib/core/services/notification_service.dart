import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system/tokens/app_colors.dart';

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

  final String id;
  final String title;
  final String body;
  final DateTime date;
  final NotificationCategory category;
  final bool read;

  /// Route à ouvrir au toucher (optionnelle).
  final String? route;

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

/// Service de notifications **simulé** (en mémoire, aucune notification système).
///
/// Les modules publient : `ref.read(notificationsProvider.notifier).push(...)`.
/// Le module Planning affiche le centre de notifications.
class NotificationsNotifier extends Notifier<List<AppNotification>> {
  int _seq = 100;

  @override
  List<AppNotification> build() {
    final now = DateTime.now();
    return [
      AppNotification(
        id: 'n-1',
        title: 'Partiel de Mathématiques demain',
        body: 'Amphi B — 9h00. Pensez à réviser les intégrales !',
        date: now.subtract(const Duration(minutes: 25)),
        category: NotificationCategory.deadline,
      ),
      AppNotification(
        id: 'n-2',
        title: 'Nouveau message — Team Algo',
        body: 'Inès : « Quelqu\'un a fini l\'exercice 4 ? »',
        date: now.subtract(const Duration(hours: 2)),
        category: NotificationCategory.group,
      ),
      AppNotification(
        id: 'n-3',
        title: 'C\'est ton tour : sortir les poubelles',
        body: 'Tâche de colocation assignée pour aujourd\'hui.',
        date: now.subtract(const Duration(hours: 5)),
        category: NotificationCategory.roommate,
        read: true,
      ),
    ];
  }

  void push({
    required String title,
    required String body,
    required NotificationCategory category,
    String? route,
  }) {
    state = [
      AppNotification(
        id: 'n-${_seq++}',
        title: title,
        body: body,
        date: DateTime.now(),
        category: category,
        route: route,
      ),
      ...state,
    ];
  }

  void markRead(String id) => state = [for (final n in state) n.id == id ? n.copyWith(read: true) : n];
  void markAllRead() => state = [for (final n in state) n.copyWith(read: true)];
  void remove(String id) => state = state.where((n) => n.id != id).toList();
}

final notificationsProvider = NotifierProvider<NotificationsNotifier, List<AppNotification>>(
  NotificationsNotifier.new,
);

final unreadNotificationsCountProvider = Provider<int>(
  (ref) => ref.watch(notificationsProvider).where((n) => !n.read).length,
);
