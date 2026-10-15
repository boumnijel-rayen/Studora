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

  Chore copyWith({bool? isCompleted}) => Chore(
    id: id,
    title: title,
    assignedToName: assignedToName,
    dueDate: dueDate,
    isCompleted: isCompleted ?? this.isCompleted,
    frequency: frequency,
  );
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
  });

  final String id;
  final String title;
  final double amount;
  final String paidByName;
  final DateTime date;
  final String category; // Courses, Internet, Électricité, Ménage
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
