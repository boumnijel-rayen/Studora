/// Chemins des routes du module Emploi du temps & rappels (Membre 2).
abstract final class ScheduleRoutes {
  static const root = '/schedule';
  static const newCourse = '/schedule/courses/new';
  static String course(String id) => '/schedule/courses/$id';
  static const deadlines = '/schedule/deadlines';
  static const newDeadline = '/schedule/deadlines/new';
  static const notifications = '/schedule/notifications';
}
