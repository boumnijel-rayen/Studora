/// Chemins des routes du module Notes & objectifs (Membre 5).
abstract final class GradesRoutes {
  static const root = '/grades';
  static const newGrade = '/grades/new';
  static const importGrades = '/grades/import';
  static String subject(String id) => '/grades/subjects/$id';
  static const goals = '/grades/goals';
  static const simulator = '/grades/simulator';
}
