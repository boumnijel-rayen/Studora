import 'package:flutter/material.dart';

/// Logement partagé, rejoint par ses membres via un code d'invitation.
@immutable
class Colocation {
  const Colocation({
    required this.id,
    required this.name,
    required this.code,
    this.address = '',
    this.details = '',
    this.isCreator = false,
  });

  final String id;
  final String name;
  final String code;
  final String address;
  final String details;
  final bool isCreator;

  factory Colocation.fromJson(Map<String, dynamic> json) => Colocation(
    id: (json['documentId'] ?? json['id'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
    code: (json['code'] ?? '').toString(),
    address: (json['address'] ?? '').toString(),
    details: (json['details'] ?? '').toString(),
    isCreator: json['isCreator'] == true,
  );
}

@immutable
class Roommate {
  const Roommate({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.roomNumber,
    this.isPresent = true,
    this.isActive = true,
    this.hasAccount = false,
    this.isMe = false,
    this.isOwner = false,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String roomNumber;
  final bool isPresent;

  /// `false` pour un ancien membre, conservé pour l'historique et les soldes.
  final bool isActive;

  /// `true` si la fiche est reliée à un compte Studora.
  final bool hasAccount;
  final bool isMe;

  /// `true` pour le propriétaire du groupe.
  final bool isOwner;

  /// Seul le titulaire peut modifier une fiche reliée à un compte.
  bool get canEdit => !hasAccount || isMe;

  Roommate copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? roomNumber,
    bool? isPresent,
  }) => Roommate(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    roomNumber: roomNumber ?? this.roomNumber,
    isPresent: isPresent ?? this.isPresent,
    isActive: isActive,
    hasAccount: hasAccount,
    isMe: isMe,
    isOwner: isOwner,
  );

  factory Roommate.fromJson(Map<String, dynamic> json) => Roommate(
    id: (json['documentId'] ?? json['id'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
    phone: (json['phone'] ?? '').toString(),
    email: (json['email'] ?? '').toString(),
    roomNumber: (json['roomNumber'] ?? 'Chambre').toString(),
    isPresent: json['isPresent'] is bool ? json['isPresent'] as bool : true,
    isActive: json['isActive'] != false,
    hasAccount: json['hasAccount'] == true,
    isMe: json['isMe'] == true,
    isOwner: json['isOwner'] == true,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'email': email,
    'roomNumber': roomNumber,
    'isPresent': isPresent,
  };
}

@immutable
class Chore {
  const Chore({
    required this.id,
    required this.title,
    required this.assignedToId,
    required this.assignedToName,
    required this.dueDate,
    this.isCompleted = false,
    this.frequency = 'Hebdomadaire',
  });

  final String id;
  final String title;
  final String assignedToId;
  final String assignedToName;
  final DateTime dueDate;
  final bool isCompleted;
  final String frequency;

  Chore copyWith({
    String? id,
    String? title,
    String? assignedToId,
    String? assignedToName,
    DateTime? dueDate,
    bool? isCompleted,
    String? frequency,
  }) => Chore(
    id: id ?? this.id,
    title: title ?? this.title,
    assignedToId: assignedToId ?? this.assignedToId,
    assignedToName: assignedToName ?? this.assignedToName,
    dueDate: dueDate ?? this.dueDate,
    isCompleted: isCompleted ?? this.isCompleted,
    frequency: frequency ?? this.frequency,
  );

  factory Chore.fromJson(Map<String, dynamic> json) => Chore(
    id: (json['documentId'] ?? json['id'] ?? '').toString(),
    title: (json['title'] ?? '').toString(),
    assignedToId: (json['assignedToId'] ?? '').toString(),
    assignedToName: (json['assignedToName'] ?? '').toString(),
    dueDate: DateTime.tryParse((json['dueDate'] ?? '').toString()) ?? DateTime.now(),
    isCompleted: json['isCompleted'] == true,
    frequency: (json['frequency'] ?? 'Hebdomadaire').toString(),
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'assignedToId': assignedToId,
    'dueDate': dueDate.toUtc().toIso8601String(),
    'isCompleted': isCompleted,
    'frequency': frequency,
  };
}

@immutable
class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.paidById,
    required this.paidByName,
    required this.date,
    required this.category,
    this.participantIds = const [],
    this.isSettlement = false,
    this.reimbursedToId,
    this.reimbursedToName,
  });

  final String id;
  final String title;
  final double amount;
  final String paidById;
  final String paidByName;
  final DateTime date;
  final String category; // Alimentation, Factures, Ménage, Remboursement, Autre

  /// Membres entre lesquels la dépense a été partagée à sa création.
  final List<String> participantIds;
  final bool isSettlement;
  final String? reimbursedToId;
  final String? reimbursedToName;

  factory Expense.fromJson(Map<String, dynamic> json) {
    final rawParticipants = json['participantIds'];
    return Expense(
      id: (json['documentId'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ??
          double.tryParse('${json['amount']}') ??
          0.0,
      paidById: (json['paidById'] ?? '').toString(),
      paidByName: (json['paidByName'] ?? '').toString(),
      date: DateTime.tryParse((json['date'] ?? json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      category: (json['category'] ?? 'Autre').toString(),
      participantIds: rawParticipants is List
          ? rawParticipants.map((e) => e.toString()).toList()
          : const [],
      isSettlement: json['isSettlement'] == true,
      reimbursedToId: json['reimbursedToId']?.toString(),
      reimbursedToName: json['reimbursedToName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'amount': amount,
    'paidById': paidById,
    'date': date.toUtc().toIso8601String(),
    'category': category,
    'participantIds': participantIds,
  };
}

@immutable
class BalanceDue {
  const BalanceDue({
    required this.fromId,
    required this.fromPerson,
    required this.toId,
    required this.toPerson,
    required this.amount,
  });

  final String fromId;
  final String fromPerson;
  final String toId;
  final String toPerson;
  final double amount;
}

/// Calcule les remboursements simplifiés à partir de la répartition figée de chaque dépense.
List<BalanceDue> computeBalances(List<Roommate> members, List<Expense> expenses) {
  // Solde net par membre : positif = on lui doit de l'argent, négatif = il doit de l'argent.
  final net = <String, double>{};
  final names = <String, String>{for (final m in members) m.id: m.name};

  for (final e in expenses) {
    if (e.paidById.isEmpty) continue;
    names.putIfAbsent(e.paidById, () => e.paidByName);

    if (e.isSettlement) {
      final receiver = e.reimbursedToId;
      if (receiver == null || receiver.isEmpty) continue;
      names.putIfAbsent(receiver, () => e.reimbursedToName ?? '');
      net[e.paidById] = (net[e.paidById] ?? 0.0) + e.amount;
      net[receiver] = (net[receiver] ?? 0.0) - e.amount;
    } else {
      if (e.participantIds.isEmpty) continue;
      final share = e.amount / e.participantIds.length;
      for (final p in e.participantIds) {
        net[p] = (net[p] ?? 0.0) - share;
      }
      net[e.paidById] = (net[e.paidById] ?? 0.0) + e.amount;
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
          fromId: debtor.key,
          fromPerson: names[debtor.key] ?? '',
          toId: creditor.key,
          toPerson: names[creditor.key] ?? '',
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
}
