import '../../core/module/feature_module.dart';
import '../../features/auth/auth_api.dart';
import '../../features/grades/grades_api.dart';
import '../../features/groups/groups_api.dart';
import '../../features/roommates/roommates_api.dart';
import '../../features/schedule/schedule_api.dart';
import '../../features/study/study_api.dart';

/// Registre centralisé des 6 modules de Studora.
///
/// L'arborescence de navigation, les onglets et les cartes du tableau
/// de bord sont découverts dynamiquement à partir de cette liste immuable.
const List<FeatureModule> appModules = [
  AuthModule(),
  ScheduleModule(),
  StudyModule(),
  GroupsModule(),
  GradesModule(),
  RoommatesModule(),
];
