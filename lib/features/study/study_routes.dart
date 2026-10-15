/// Chemins des routes du module Révisions & Pomodoro (Membre 3).
abstract final class StudyRoutes {
  static const root = '/study';
  static const newSession = '/study/sessions/new';
  static String session(String id) => '/study/sessions/$id';
  static const tasks = '/study/tasks';
  static const pomodoro = '/study/pomodoro';
  static const pomodoroSettings = '/study/pomodoro/settings';
  static const history = '/study/history';
}
