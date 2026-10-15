import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/roommate_models.dart';

final _initialRoommates = [
  const Roommate(
    id: 'rm-1',
    name: 'Rayen Ben Ali',
    phone: '06 12 34 56 78',
    email: 'rayen@univ.fr',
    roomNumber: 'Chambre 1',
    isPresent: true,
  ),
  const Roommate(
    id: 'rm-2',
    name: 'Lucas Martin',
    phone: '06 98 76 54 32',
    email: 'lucas.martin@univ.fr',
    roomNumber: 'Chambre 2',
    isPresent: true,
  ),
  const Roommate(
    id: 'rm-3',
    name: 'Inès Mansour',
    phone: '07 11 22 33 44',
    email: 'ines.mansour@univ.fr',
    roomNumber: 'Chambre 3',
    isPresent: false,
  ),
];

final _initialChores = [
  Chore(
    id: 'ch-1',
    title: 'Sortir les poubelles (Tri & Verre)',
    assignedToName: 'Rayen Ben Ali',
    dueDate: DateTime.now(),
    isCompleted: false,
    frequency: 'Quotidien',
  ),
  Chore(
    id: 'ch-2',
    title: 'Nettoyer la cuisine & plaques de cuisson',
    assignedToName: 'Lucas Martin',
    dueDate: DateTime.now().add(const Duration(days: 1)),
    isCompleted: false,
    frequency: 'Hebdomadaire',
  ),
  Chore(
    id: 'ch-3',
    title: 'Passer la serpillière dans le salon',
    assignedToName: 'Inès Mansour',
    dueDate: DateTime.now().add(const Duration(days: 2)),
    isCompleted: true,
    frequency: 'Hebdomadaire',
  ),
  Chore(
    id: 'ch-4',
    title: 'Acheter produits d\'entretien & éponges',
    assignedToName: 'Rayen Ben Ali',
    dueDate: DateTime.now().add(const Duration(days: 4)),
    isCompleted: false,
    frequency: 'Mensuel',
  ),
];

final _initialExpenses = [
  Expense(
    id: 'exp-1',
    title: 'Courses partagées supermarché',
    amount: 68.40,
    paidByName: 'Rayen Ben Ali',
    date: DateTime.now().subtract(const Duration(days: 2)),
    category: 'Alimentation',
  ),
  Expense(
    id: 'exp-2',
    title: 'Abonnement Box Internet Fibre',
    amount: 32.99,
    paidByName: 'Lucas Martin',
    date: DateTime.now().subtract(const Duration(days: 6)),
    category: 'Factures',
  ),
  Expense(
    id: 'exp-3',
    title: 'Produits ménagers & sacs poubelle',
    amount: 15.60,
    paidByName: 'Inès Mansour',
    date: DateTime.now().subtract(const Duration(days: 10)),
    category: 'Ménage',
  ),
];

class RoommatesNotifier extends Notifier<List<Roommate>> {
  @override
  List<Roommate> build() => _initialRoommates;

  void add(Roommate r) => state = [...state, r];
}

final roommatesProvider = NotifierProvider<RoommatesNotifier, List<Roommate>>(RoommatesNotifier.new);

class ChoresNotifier extends Notifier<List<Chore>> {
  @override
  List<Chore> build() => _initialChores;

  void add(Chore c) => state = [...state, c];

  void toggle(String id) {
    state = [
      for (final c in state)
        if (c.id == id) c.copyWith(isCompleted: !c.isCompleted) else c,
    ];
  }

  void delete(String id) => state = state.where((c) => c.id != id).toList();
}

final choresProvider = NotifierProvider<ChoresNotifier, List<Chore>>(ChoresNotifier.new);

class ExpensesNotifier extends Notifier<List<Expense>> {
  @override
  List<Expense> build() => _initialExpenses;

  void add(Expense e) => state = [e, ...state];
  void delete(String id) => state = state.where((e) => e.id != id).toList();
}

final expensesProvider = NotifierProvider<ExpensesNotifier, List<Expense>>(ExpensesNotifier.new);

/// Dettes mutuelles simulées
final balancesDueProvider = Provider<List<BalanceDue>>((ref) {
  // Calcul simplifié basé sur les dépenses
  return const [
    BalanceDue(fromPerson: 'Lucas Martin', toPerson: 'Rayen Ben Ali', amount: 12.80),
    BalanceDue(fromPerson: 'Inès Mansour', toPerson: 'Rayen Ben Ali', amount: 15.20),
  ];
});
