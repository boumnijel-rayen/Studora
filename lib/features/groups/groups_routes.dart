/// Chemins des routes du module Groupes d'étude (Membre 4).
abstract final class GroupsRoutes {
  static const root = '/groups';
  static const newGroup = '/groups/new';
  static const join = '/groups/join';
  static String detail(String id) => '/groups/$id';
  static String chat(String id) => '/groups/$id/chat';
  static String newActivity(String id) => '/groups/$id/activities/new';
}
