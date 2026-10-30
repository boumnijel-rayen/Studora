import 'package:flutter/material.dart';

@immutable
class Roommate {
  const Roommate({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.roomNumber,
    this.isPresent = true,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String roomNumber;
  final bool isPresent;

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
  );

  factory Roommate.fromJson(Map<String, dynamic> json) => Roommate(
    id: (json['documentId'] ?? json['id'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
    phone: (json['phone'] ?? '').toString(),
    email: (json['email'] ?? '').toString(),
    roomNumber: (json['roomNumber'] ?? 'Chambre').toString(),
    isPresent: json['isPresent'] is bool ? json['isPresent'] as bool : true,
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
    required this.assignedToName,
    required this.dueDate,
    this.isCompleted = false,
    this.frequency = 'Hebdomadaire',
  });

  final String id;
  final String title;
  final String assignedToName;
  final DateTime dueDate;
  final bool isCompleted;
  final String frequency;

  Chore copyWith({
    String? id,
    String? title,
    String? assignedToName,
    DateTime? dueDate,
    bool? isCompleted,
    String? frequency,
  }) => Chore(
    id: id ?? this.id,
    title: title ?? this.title,
    assignedToName: assignedToName ?? this.assignedToName,
    dueDate: dueDate ?? this.dueDate,
    isCompleted: isCompleted ?? this.isCompleted,
    frequency: frequency ?? this.frequency,
  );

  factory Chore.fromJson(Map<String, dynamic> json) => Chore(
    id: (json['documentId'] ?? json['id'] ?? '').toString(),
    title: (json['title'] ?? '').toString(),
    assignedToName: (json['assignedToName'] ?? '').toString(),
    dueDate: DateTime.tryParse((json['dueDate'] ?? '').toString()) ?? DateTime.now(),
    isCompleted: json['isCompleted'] == true,
    frequency: (json['frequency'] ?? 'Hebdomadaire').toString(),
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'assignedToName': assignedToName,
    'dueDate': dueDate.toIso8601String(),
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
    required this.paidByName,
    required this.date,
    required this.category,
    this.isSettlement = false,
    this.reimbursedToName,
  });

  final String id;
  final String title;
  final double amount;
  final String paidByName;
  final DateTime date;
  final String category; // Alimentation, Factures, Ménage, Remboursement, Autre
  final bool isSettlement;
  final String? reimbursedToName;

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: (json['documentId'] ?? json['id'] ?? '').toString(),
    title: (json['title'] ?? '').toString(),
    amount: (json['amount'] as num?)?.toDouble() ??
        double.tryParse('${json['amount']}') ??
        0.0,
    paidByName: (json['paidByName'] ?? '').toString(),
    date: DateTime.tryParse((json['date'] ?? json['createdAt'] ?? '').toString()) ??
        DateTime.now(),
    category: (json['category'] ?? 'Autre').toString(),
    isSettlement: json['isSettlement'] == true,
    reimbursedToName: json['reimbursedToName']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'amount': amount,
    'paidByName': paidByName,
    'date': date.toIso8601String(),
    'category': category,
    'isSettlement': isSettlement,
    if (reimbursedToName != null) 'reimbursedToName': reimbursedToName,
  };
}

@immutable
class BalanceDue {
  const BalanceDue({
    required this.fromPerson,
    required this.toPerson,
    required this.amount,
  });

  final String fromPerson;
  final String toPerson;
  final double amount;
}
