import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/roommate_models.dart';

/// Gestion des colocataires connectée à `/roommate-members`.
class RoommatesAsyncNotifier extends AsyncNotifier<List<Roommate>> {
  @override
  Future<List<Roommate>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];
    return _fetchRoommates();
  }

  Future<List<Roommate>> _fetchRoommates() async {
    final client = ref.read(strapiClientProvider);
    final items = await client.getList(
      '/roommate-members',
      queryParameters: {
        'sort[0]': 'name:asc',
        'pagination[pageSize]': '100',
      },
    );
    return items.map(Roommate.fromJson).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchRoommates);
  }

  Future<Roommate> add(Roommate r) async {
    final client = ref.read(strapiClientProvider);
    final response = await client.post('/roommate-members', body: r.toJson());
    final created = Roommate.fromJson(StrapiClient.unwrapMap(response));
    final current = state.value ?? const <Roommate>[];
    state = AsyncData([...current, created]);
    return created;
  }

  Future<void> togglePresence(String id) async {
    final current = state.value ?? const <Roommate>[];
    final target = current.where((r) => r.id == id).firstOrNull;
    if (target == null) return;
    final nextVal = !target.isPresent;

    state = AsyncData([
      for (final r in current)
        if (r.id == id) r.copyWith(isPresent: nextVal) else r,
    ]);

    try {
      final client = ref.read(strapiClientProvider);
      await client.put('/roommate-members/$id', body: {'isPresent': nextVal});
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    final client = ref.read(strapiClientProvider);
    await client.delete('/roommate-members/$id');
    final current = state.value ?? const <Roommate>[];
    state = AsyncData(current.where((r) => r.id != id).toList());
  }
}

final roommatesAsyncProvider =
    AsyncNotifierProvider<RoommatesAsyncNotifier, List<Roommate>>(
      RoommatesAsyncNotifier.new,
    );

final roommatesProvider = Provider<List<Roommate>>((ref) {
  return ref.watch(roommatesAsyncProvider).value ?? const [];
});

/// Gestion des tâches ménagères connectée à `/chores`.
class ChoresAsyncNotifier extends AsyncNotifier<List<Chore>> {
  @override
  Future<List<Chore>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];
    return _fetchChores();
  }

  Future<List<Chore>> _fetchChores() async {
    final client = ref.read(strapiClientProvider);
    final items = await client.getList(
      '/chores',
      queryParameters: {
        'sort[0]': 'dueDate:asc',
        'pagination[pageSize]': '100',
      },
    );
    return items.map(Chore.fromJson).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchChores);
  }

  Future<Chore> add(Chore c) async {
    final client = ref.read(strapiClientProvider);
    final response = await client.post('/chores', body: c.toJson());
    final created = Chore.fromJson(StrapiClient.unwrapMap(response));
    final current = state.value ?? const <Chore>[];
    state = AsyncData([...current, created]);
    return created;
  }

  Future<void> toggle(String id) async {
    final current = state.value ?? const <Chore>[];
    final target = current.where((c) => c.id == id).firstOrNull;
    if (target == null) return;
    final nextVal = !target.isCompleted;

    state = AsyncData([
      for (final c in current)
        if (c.id == id) c.copyWith(isCompleted: nextVal) else c,
    ]);

    try {
      final client = ref.read(strapiClientProvider);
      await client.put('/chores/$id', body: {'isCompleted': nextVal});
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    final client = ref.read(strapiClientProvider);
    await client.delete('/chores/$id');
    final current = state.value ?? const <Chore>[];
    state = AsyncData(current.where((c) => c.id != id).toList());
  }
}

final choresAsyncProvider =
    AsyncNotifierProvider<ChoresAsyncNotifier, List<Chore>>(
      ChoresAsyncNotifier.new,
    );

final choresProvider = Provider<List<Chore>>((ref) {
  return ref.watch(choresAsyncProvider).value ?? const [];
});

/// Gestion des dépenses partagées et remboursements connectée à `/expenses`.
class ExpensesAsyncNotifier extends AsyncNotifier<List<Expense>> {
  @override
  Future<List<Expense>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];
    return _fetchExpenses();
  }

  Future<List<Expense>> _fetchExpenses() async {
    final client = ref.read(strapiClientProvider);
    final items = await client.getList(
      '/expenses',
      queryParameters: {
        'sort[0]': 'date:desc',
        'pagination[pageSize]': '100',
      },
    );
    return items.map(Expense.fromJson).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchExpenses);
  }

  Future<Expense> add(Expense e) async {
    final client = ref.read(strapiClientProvider);
    final response = await client.post('/expenses', body: e.toJson());
    final created = Expense.fromJson(StrapiClient.unwrapMap(response));
    final current = state.value ?? const <Expense>[];
    state = AsyncData([created, ...current]);
    return created;
  }

  /// Enregistre un remboursement via l'endpoint personnalisé `POST /expenses/settle`.
  Future<Expense> settle(BalanceDue debt) async {
    final client = ref.read(strapiClientProvider);
    final response = await client.post(
      '/expenses/settle',
      body: {
        'fromPerson': debt.fromPerson,
        'toPerson': debt.toPerson,
        'amount': debt.amount,
      },
      wrapData: false,
    );
    final created = Expense.fromJson(StrapiClient.unwrapMap(response));
    final current = state.value ?? const <Expense>[];
    state = AsyncData([created, ...current]);
    return created;
  }

  Future<void> delete(String id) async {
    final client = ref.read(strapiClientProvider);
    await client.delete('/expenses/$id');
    final current = state.value ?? const <Expense>[];
    state = AsyncData(current.where((e) => e.id != id).toList());
  }
}

final expensesAsyncProvider =
    AsyncNotifierProvider<ExpensesAsyncNotifier, List<Expense>>(
      ExpensesAsyncNotifier.new,
    );

final expensesProvider = Provider<List<Expense>>((ref) {
  return ref.watch(expensesAsyncProvider).value ?? const [];
});

/// Dépenses communes hors remboursements directs.
final sharedExpensesProvider = Provider<List<Expense>>((ref) {
  return ref.watch(expensesProvider).where((e) => !e.isSettlement).toList();
});

/// Calcul réel des dettes simplifiées à partir des colocataires, dépenses partagées et remboursements.
final balancesDueProvider = Provider<List<BalanceDue>>((ref) {
  final roommates = ref.watch(roommatesProvider);
  final expenses = ref.watch(expensesProvider);
  if (expenses.isEmpty) return const [];

  final participants = <String>{
    for (final r in roommates)
      if (r.name.trim().isNotEmpty) r.name.trim(),
    for (final e in expenses)
      if (e.paidByName.trim().isNotEmpty) e.paidByName.trim(),
    for (final e in expenses)
      if (e.reimbursedToName != null && e.reimbursedToName!.trim().isNotEmpty)
        e.reimbursedToName!.trim(),
  }.toList();

  if (participants.length < 2) return const [];

  // Solde net par participant : positif = on lui doit de l'argent, négatif = il doit de l'argent.
  final net = <String, double>{for (final p in participants) p: 0.0};
  final count = participants.length;

  for (final e in expenses) {
    final payer = e.paidByName.trim();
    if (payer.isEmpty) continue;

    if (e.isSettlement && e.reimbursedToName != null && e.reimbursedToName!.trim().isNotEmpty) {
      final receiver = e.reimbursedToName!.trim();
      net[payer] = (net[payer] ?? 0.0) + e.amount;
      net[receiver] = (net[receiver] ?? 0.0) - e.amount;
    } else {
      final share = e.amount / count;
      for (final p in participants) {
        net[p] = (net[p] ?? 0.0) - share;
      }
      net[payer] = (net[payer] ?? 0.0) + e.amount;
    }
  }

  final debtors = <MapEntry<String, double>>[];
  final creditors = <MapEntry<String, double>>[];

  for (final entry in net.entries) {
    if (entry.value < -0.01) {
      debtors.add(MapEntry(entry.key, -entry.value));
    } else if (entry.value > 0.01) {
      creditors.add(MapEntry(entry.key, entry.value));
    }
  }

  debtors.sort((a, b) => b.value.compareTo(a.value));
  creditors.sort((a, b) => b.value.compareTo(a.value));

  final results = <BalanceDue>[];
  var i = 0;
  var j = 0;

  while (i < debtors.length && j < creditors.length) {
    final debtor = debtors[i];
    final creditor = creditors[j];
    final settled = debtor.value < creditor.value ? debtor.value : creditor.value;

    if (settled > 0.01) {
      results.add(
        BalanceDue(
          fromPerson: debtor.key,
          toPerson: creditor.key,
          amount: double.parse(settled.toStringAsFixed(2)),
        ),
      );
    }

    final remainingDebt = debtor.value - settled;
    final remainingCredit = creditor.value - settled;

    if (remainingDebt <= 0.01) {
      i++;
    } else {
      debtors[i] = MapEntry(debtor.key, remainingDebt);
    }

    if (remainingCredit <= 0.01) {
      j++;
    } else {
      creditors[j] = MapEntry(creditor.key, remainingCredit);
    }
  }

  return results;
});

/// Solde net de l'utilisateur courant dans la colocation.
final netUserBalanceProvider = Provider<double>((ref) {
  final user = ref.watch(currentUserProvider);
  final balances = ref.watch(balancesDueProvider);
  if (balances.isEmpty) return 0.0;

  final userName = user?.fullName.trim().toLowerCase() ?? '';
  if (userName.isEmpty) {
    return balances.fold<double>(0.0, (acc, b) => acc + b.amount);
  }

  var net = 0.0;
  var matchedUser = false;
  for (final b in balances) {
    if (b.toPerson.trim().toLowerCase() == userName) {
      net += b.amount;
      matchedUser = true;
    } else if (b.fromPerson.trim().toLowerCase() == userName) {
      net -= b.amount;
      matchedUser = true;
    }
  }

  if (!matchedUser) {
    return balances.fold<double>(0.0, (acc, b) => acc + b.amount);
  }
  return net;
});
