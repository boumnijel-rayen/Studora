/// Chemins des routes du module Colocation (Membre 6).
abstract final class RoommatesRoutes {
  static const root = '/roommates';
  static const roommatesList = '/roommates/members';
  static const newRoommate = '/roommates/members/new';
  static String editRoommate(String id) => '/roommates/members/$id/edit';
  static const chat = '/roommates/chat';
  static const chores = '/roommates/chores';
  static const newChore = '/roommates/chores/new';
  static const expenses = '/roommates/expenses';
  static const newExpense = '/roommates/expenses/new';
  static const balances = '/roommates/balances';
}
