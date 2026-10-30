import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/roommate_models.dart';

/// Colocation de l'utilisateur connecté (`null` s'il n'en a pas encore), connectée à `/colocations`.
class ColocationAsyncNotifier extends AsyncNotifier<Colocation?> {
  @override
  Future<Colocation?> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return null;
    return _fetchColocation();
  }

  Future<Colocation?> _fetchColocation() async {
    final client = ref.read(strapiClientProvider);
    final response = await client.get('/colocations/mine');
    final data = response is Map<String, dynamic> ? response['data'] : null;
    return data is Map<String, dynamic> ? Colocation.fromJson(data) : null;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchColocation);
  }

  Future<Colocation> create({
    required String name,
    required String address,
    String details = '',
  }) async {
    final client = ref.read(strapiClientProvider);
    final response = await client.post(
      '/colocations',
      body: {'name': name, 'address': address, 'details': details},
    );
    final created = Colocation.fromJson(StrapiClient.unwrapMap(response));
    state = AsyncData(created);
    return created;
  }

  Future<Colocation> join({required String code}) async {
    final client = ref.read(strapiClientProvider);
    final response = await client.post(
      '/colocations/join',
      body: {'code': code.trim().toUpperCase()},
    );
    final joined = Colocation.fromJson(StrapiClient.unwrapMap(response));
    state = AsyncData(joined);
    return joined;
  }

  Future<void> leave() async {
    final client = ref.read(strapiClientProvider);
    await client.post('/colocations/leave', body: const {});
    state = const AsyncData(null);
  }
}

final colocationAsyncProvider =
    AsyncNotifierProvider<ColocationAsyncNotifier, Colocation?>(
      ColocationAsyncNotifier.new,
    );

final colocationProvider = Provider<Colocation?>((ref) {
  return ref.watch(colocationAsyncProvider).value;
});

/// Membres de la colocation connectés à `/roommate-members`, anciens membres inclus.
class RoommatesAsyncNotifier extends AsyncNotifier<List<Roommate>> {
  @override
  Future<List<Roommate>> build() async {
    final colocation = await ref.watch(colocationAsyncProvider.future);
    if (colocation == null) return const [];
    return _fetchRoommates();
  }

  Future<List<Roommate>> _fetchRoommates() async {
    final client = ref.read(strapiClientProvider);
    final items = await client.getList('/roommate-members');
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

  Future<Roommate> edit(Roommate r) async {
    final client = ref.read(strapiClientProvider);
    final response = await client.put('/roommate-members/${r.id}', body: r.toJson());
    final updated = Roommate.fromJson(StrapiClient.unwrapMap(response));
    final current = state.value ?? const <Roommate>[];
    state = AsyncData([
      for (final m in current) m.id == updated.id ? updated : m,
    ]);
    // Les tâches et dépenses affichent le nom actuel du membre.
    ref.invalidate(choresAsyncProvider);
    ref.invalidate(expensesAsyncProvider);
    return updated;
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

  /// Retire le membre : sa fiche reste pour l'historique, ses tâches en attente sont réassignées.
  Future<void> delete(String id) async {
    final client = ref.read(strapiClientProvider);
    await client.delete('/roommate-members/$id');
    state = await AsyncValue.guard(_fetchRoommates);
    ref.invalidate(choresAsyncProvider);
  }
}

final roommatesAsyncProvider =
    AsyncNotifierProvider<RoommatesAsyncNotifier, List<Roommate>>(
      RoommatesAsyncNotifier.new,
    );

/// Membres actuels de la colocation.
final roommatesProvider = Provider<List<Roommate>>((ref) {
  final all = ref.watch(roommatesAsyncProvider).value ?? const <Roommate>[];
  return all.where((r) => r.isActive).toList();
});

/// Fiche de l'utilisateur connecté dans sa colocation.
final currentRoommateProvider = Provider<Roommate?>((ref) {
  return ref.watch(roommatesProvider).where((r) => r.isMe).firstOrNull;
});

/// Gestion des tâches ménagères connectée à `/chores`.
class ChoresAsyncNotifier extends AsyncNotifier<List<Chore>> {
  @override
  Future<List<Chore>> build() async {
    final colocation = await ref.watch(colocationAsyncProvider.future);
    if (colocation == null) return const [];
    return _fetchChores();
  }

  Future<List<Chore>> _fetchChores() async {
    final client = ref.read(strapiClientProvider);
    final items = await client.getList('/chores');
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

    // Le serveur crée ou retire l'occurrence suivante des tâches récurrentes.
    state = await AsyncValue.guard(_fetchChores);
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
    final colocation = await ref.watch(colocationAsyncProvider.future);
    if (colocation == null) return const [];
    return _fetchExpenses();
  }

  Future<List<Expense>> _fetchExpenses() async {
    final client = ref.read(strapiClientProvider);
    final items = await client.getList('/expenses');
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
        'fromMemberId': debt.fromId,
        'toMemberId': debt.toId,
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

/// Total des dépenses communes du mois en cours.
final monthlyExpensesTotalProvider = Provider<double>((ref) {
  final now = DateTime.now();
  return ref
      .watch(sharedExpensesProvider)
      .where((e) {
        final date = e.date.toLocal();
        return date.year == now.year && date.month == now.month;
      })
      .fold<double>(0, (total, e) => total + e.amount);
});

/// Part de l'utilisateur connecté dans l'ensemble des dépenses communes.
final myExpensesShareProvider = Provider<double>((ref) {
  final me = ref.watch(currentRoommateProvider);
  if (me == null) return 0.0;
  return ref
      .watch(sharedExpensesProvider)
      .where((e) => e.participantIds.contains(me.id))
      .fold<double>(0, (total, e) => total + e.amount / e.participantIds.length);
});

/// Dettes simplifiées, calculées à partir de tous les membres, anciens compris.
final balancesDueProvider = Provider<List<BalanceDue>>((ref) {
  final members = ref.watch(roommatesAsyncProvider).value ?? const <Roommate>[];
  return computeBalances(members, ref.watch(expensesProvider));
});

/// Solde net de l'utilisateur courant dans la colocation.
final netUserBalanceProvider = Provider<double>((ref) {
  final me = ref.watch(currentRoommateProvider);
  if (me == null) return 0.0;

  var net = 0.0;
  for (final b in ref.watch(balancesDueProvider)) {
    if (b.toId == me.id) {
      net += b.amount;
    } else if (b.fromId == me.id) {
      net -= b.amount;
    }
  }
  return net;
});

/// Messages de la colocation (`/colocation-messages`).
final colocationMessagesProvider = FutureProvider<List<AppChatEntry>>((ref) async {
  final colocation = await ref.watch(colocationAsyncProvider.future);
  if (colocation == null) return const [];

  final client = ref.read(strapiClientProvider);
  final items = await client.getList('/colocation-messages');
  return items.map(AppChatEntry.fromJson).toList();
});

/// Service d'envoi des messages de la colocation.
class ColocationChatService {
  ColocationChatService(this._ref);
  final Ref _ref;

  Future<void> sendMessage(String text) async {
    final client = _ref.read(strapiClientProvider);
    await client.post('/colocation-messages', body: {'text': text});
    _ref.invalidate(colocationMessagesProvider);
  }
}

final colocationChatServiceProvider = Provider<ColocationChatService>(
  ColocationChatService.new,
);
