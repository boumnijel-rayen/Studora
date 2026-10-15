/// Chemins des routes du module Notes & objectifs (Membre 5).
abstract final class GradesRoutes {
  static const root = '/grades';
  static const newGrade = '/grades/new';
  static String subject(String id) => '/grades/subjects/$id';
  static const goals = '/grades/goals';
  static const newGoal = '/grades/goals/new';
  static const statistics = '/grades/statistics';
  static const simulator = '/grades/simulator';
}
